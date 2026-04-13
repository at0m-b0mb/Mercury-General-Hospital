# =============================================================================
#  Mercury General Hospital — CTF Machine Setup Script
#  Run as Administrator on Windows Server 2019 / Windows 10+
# =============================================================================
#Requires -RunAsAdministrator

param(
    [string]$XamppPath = "C:\xampp"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Mercury General Hospital CTF Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Install XAMPP (Apache + PHP + MariaDB) if not present
# ---------------------------------------------------------------------------
Write-Host "[1/6] Checking for XAMPP..." -ForegroundColor Yellow

$xamppInstaller = "$env:TEMP\xampp-installer.exe"

# Use the direct Apache Friends mirror URL (avoids SourceForge redirect pages
# which Invoke-WebRequest follows into an HTML landing page, producing a
# corrupt non-executable file that causes the "file or directory is corrupted"
# error from Start-Process).
$xamppUrl = "https://www.apachefriends.org/xampp-files/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe"

if (-not (Test-Path "$XamppPath\xampp-control.exe")) {
    Write-Host "  Downloading XAMPP installer..." -ForegroundColor Gray

    # Use a WebClient with a browser-like User-Agent so CDNs serve the binary.
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    try {
        $wc.DownloadFile($xamppUrl, $xamppInstaller)
    } finally {
        $wc.Dispose()
    }

    # Sanity-check: a real installer is several hundred MB; an HTML error page
    # is tiny. Abort early with a clear message instead of a cryptic COM error.
    $installerSize = (Get-Item $xamppInstaller).Length
    if ($installerSize -lt 10MB) {
        Remove-Item $xamppInstaller -Force
        throw "XAMPP download appears corrupt or incomplete (only $([math]::Round($installerSize/1KB)) KB). " +
              "Please download manually from https://www.apachefriends.org/download.html " +
              "and place the installer at: $xamppInstaller"
    }

    Write-Host "  Running XAMPP silent install..." -ForegroundColor Gray
    $proc = Start-Process -FilePath $xamppInstaller `
        -ArgumentList "--mode unattended --prefix `"$XamppPath`"" `
        -Wait -PassThru -NoNewWindow

    Remove-Item $xamppInstaller -Force

    if ($proc.ExitCode -ne 0) {
        throw "XAMPP installer exited with code $($proc.ExitCode). Check the installer log for details."
    }

    Write-Host "  XAMPP installed at $XamppPath" -ForegroundColor Green
} else {
    Write-Host "  XAMPP already installed at $XamppPath" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Deploy the patient-portal web application
# ---------------------------------------------------------------------------
Write-Host "`n[2/6] Deploying patient portal web app..." -ForegroundColor Yellow

$htdocs = "$XamppPath\htdocs"

# Remove default XAMPP welcome page if present
if (Test-Path "$htdocs\index.php") {
    Rename-Item "$htdocs\index.php" "$htdocs\index.php.bak" -Force -ErrorAction SilentlyContinue
}

# Copy all portal files directly to the htdocs root so that root-relative
# links (/login.php, /records.php, etc.) resolve correctly.
Copy-Item -Path "$RepoRoot\web\patient-portal\*" -Destination $htdocs -Recurse -Force

Write-Host "  Portal deployed to $htdocs" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Create the hospital file structure on disk
# ---------------------------------------------------------------------------
Write-Host "`n[3/6] Creating hospital file system structure..." -ForegroundColor Yellow

# Hospital files live inside htdocs/hospital-files/.
# Direct HTTP access is blocked by the .htaccess in that directory;
# PHP can still read the files via path traversal (the intentional vulnerability).
$hospitalDir = "$htdocs\hospital-files"

$dirs = @(
    "$hospitalDir\dental-records",
    "$hospitalDir\security-footage",
    "$hospitalDir\prescriptions\archive",
    "$hospitalDir\prescriptions\hidden"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

# Copy hospital files from repo
Copy-Item -Path "$RepoRoot\hospital-files\*" `
          -Destination $hospitalDir `
          -Recurse -Force

# Restrict the 'hidden' prescriptions folder so low-privilege OS users
# (reception, drpatel) cannot read the files directly via RDP/SSH.
# Apache/PHP runs as SYSTEM, so the path-traversal exploit still works.
$hiddenPath = "$hospitalDir\prescriptions\hidden"
$acl = Get-Acl $hiddenPath
$acl.SetAccessRuleProtection($true, $false)       # disable inheritance
# Add Administrators full control
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($adminRule)
# Add SYSTEM full control
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($systemRule)
Set-Acl -Path $hiddenPath -AclObject $acl

Write-Host "  Hospital file structure created at $hospitalDir" -ForegroundColor Green
Write-Host "  Restricted NTFS permissions set on: $hiddenPath" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Create CTF user accounts
# ---------------------------------------------------------------------------
Write-Host "`n[4/6] Creating CTF user accounts..." -ForegroundColor Yellow

function New-LocalUserIfMissing {
    param([string]$Name, [string]$Password, [string]$Description, [bool]$Admin = $false)
    if (-not (Get-LocalUser -Name $Name -ErrorAction SilentlyContinue)) {
        $secPwd = ConvertTo-SecureString $Password -AsPlainText -Force
        New-LocalUser -Name $Name -Password $secPwd -Description $Description `
                      -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
        if ($Admin) {
            Add-LocalGroupMember -Group "Administrators" -Member $Name
        }
        Write-Host "  Created user: $Name" -ForegroundColor Gray
    } else {
        Write-Host "  User already exists: $Name" -ForegroundColor Gray
    }
}

New-LocalUserIfMissing "reception"  "W0lfpack2009!"  "MGH Reception Desk (CTF low-priv user)"
New-LocalUserIfMissing "drpatel"    "H4ng0v3rMD!"    "MGH Dr Patel (CTF mid-priv user)"
New-LocalUserIfMissing "mgh-admin"  "Sup3rS3cr3t!"   "MGH Admin (CTF high-priv user)" -Admin $true

Write-Host "  Users created (see setup/README.md for credentials)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Start Apache and configure firewall
# ---------------------------------------------------------------------------
Write-Host "`n[5/6] Starting Apache..." -ForegroundColor Yellow

# Start Apache as a service (XAMPP installs it as 'Apache2.4')
$svc = Get-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
if ($svc) {
    Start-Service "Apache2.4" -ErrorAction SilentlyContinue
} else {
    # Fall back to xampp shell command
    & "$XamppPath\apache\bin\httpd.exe" -k start 2>$null
}

# Open port 80 in Windows Firewall
New-NetFirewallRule -DisplayName "MGH CTF HTTP" -Direction Inbound `
    -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue | Out-Null

Write-Host "  Apache started; port 80 open in firewall" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 6. Print summary
# ---------------------------------------------------------------------------
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
       Select-Object -First 1).IPAddress

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Portal URL  : http://$ip/login.php"
Write-Host "  Hospital Dir: $hospitalDir"
Write-Host ""
Write-Host "  Low-priv SSH: reception / W0lfpack2009!"
Write-Host "  Mid-priv SSH: drpatel   / H4ng0v3rMD!"
Write-Host ""
Write-Host "  FLAGS:"
Write-Host "    FLAG 3 (Dental Record)   : patient DB — exploit IDOR on /records.php?pid=MGH-0044"
Write-Host "    FLAG 4 (Security Footage): camera DB  — forge Cookie: role=admin on /camera.php"
Write-Host "    FLAG 5 (Prescription)    : $hospitalDir\prescriptions\hidden\rx_chow_encoded.txt"
Write-Host "                               (path traversal: ?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt then Base64 decode)"
Write-Host ""
