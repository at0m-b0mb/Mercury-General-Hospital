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

# Download candidate URLs in priority order.  The Apache Friends CDN is tried
# first; SourceForge is used as a fallback in case the primary mirror is down
# or rate-limiting direct connections.
$xamppUrls = @(
    "https://www.apachefriends.org/xampp-files/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe",
    "https://downloads.sourceforge.net/project/xampp/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe"
)

if (-not (Test-Path "$XamppPath\xampp-control.exe")) {
    Write-Host "  Downloading XAMPP installer..." -ForegroundColor Gray

    $downloaded = $false
    foreach ($xamppUrl in $xamppUrls) {
        Write-Host "  Trying: $xamppUrl" -ForegroundColor Gray
        try {
            # Use a WebClient with a browser-like User-Agent so CDNs serve the
            # binary rather than returning an HTML landing / redirect page.
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            # Follow redirects (SourceForge uses them heavily).
            [System.Net.ServicePointManager]::SecurityProtocol =
                [System.Net.SecurityProtocolType]::Tls12 -bor
                [System.Net.SecurityProtocolType]::Tls13
            $wc.DownloadFile($xamppUrl, $xamppInstaller)
            $wc.Dispose()

            # Sanity-check: a real installer is several hundred MB; an HTML
            # error page is tiny.
            $installerSize = (Get-Item $xamppInstaller -ErrorAction Stop).Length
            if ($installerSize -ge 10MB) {
                $downloaded = $true
                break
            }

            Write-Host "  Download from this URL appears truncated ($([math]::Round($installerSize/1KB)) KB) — trying next mirror." -ForegroundColor Yellow
            Remove-Item $xamppInstaller -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "  Download failed: $_" -ForegroundColor Yellow
            Remove-Item $xamppInstaller -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $downloaded) {
        throw ("XAMPP download failed from all mirrors.`n" +
               "Please download xampp-windows-x64-8.2.12-0-VS16-installer.exe manually " +
               "from https://www.apachefriends.org/download.html and place it at:`n  $xamppInstaller`n" +
               "Then re-run this script.")
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

# XAMPP may register the Apache service under slightly different names
# depending on the version and whether the service was installed via the
# XAMPP control panel or a previous script run.  Try the most common names.
$apacheServiceNames = @("Apache2.4", "Apache2", "Apache")
$svc = $null
foreach ($svcName in $apacheServiceNames) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "  Found Apache service: '$svcName'" -ForegroundColor Gray
        break
    }
}

$httpdExe = "$XamppPath\apache\bin\httpd.exe"

if ($svc) {
    # Service exists — start it if it isn't already running.
    try {
        if ($svc.Status -ne 'Running') {
            Start-Service $svc.Name -ErrorAction Stop
        }
        Write-Host "  Apache service '$($svc.Name)' is running." -ForegroundColor Green
    } catch {
        Write-Host "  Warning: could not start Apache service — falling back to httpd.exe." -ForegroundColor Yellow
        if (Test-Path $httpdExe) {
            & $httpdExe -k start 2>$null
        }
    }
} else {
    # No service found.  This happens when XAMPP was installed manually and
    # the "Install as service" step was skipped in the XAMPP control panel.
    # Register the service now, then start it.
    if (Test-Path $httpdExe) {
        Write-Host "  Apache service not registered — installing via httpd.exe..." -ForegroundColor Yellow
        & $httpdExe -k install 2>$null
        Start-Sleep -Seconds 2
        # Refresh — the service should now exist as 'Apache2.4'.
        $svc = Get-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
        if ($svc) {
            Start-Service "Apache2.4" -ErrorAction SilentlyContinue
            Write-Host "  Apache service registered and started." -ForegroundColor Green
        } else {
            # Last resort: launch httpd directly (not as a Windows service).
            & $httpdExe -k start 2>$null
            Write-Host "  Apache started directly via httpd.exe (not as a Windows service)." -ForegroundColor Green
        }
    } else {
        Write-Host "  WARNING: httpd.exe not found at $httpdExe" -ForegroundColor Red
        Write-Host "  Please start Apache manually from the XAMPP Control Panel." -ForegroundColor Red
    }
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
