# =============================================================================
#  Mercury General Hospital - CTF Machine Setup Script
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

# This is the exact URL the browser opens when clicking Download on apachefriends.org.
# In a browser it shows a 5-second countdown then saves the file.
# curl -L skips the countdown entirely by following the HTTP redirect chain
# straight to the CDN mirror binary.
$xamppUrl     = "https://sourceforge.net/projects/xampp/files/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe/download"
$xamppReferer = "https://www.apachefriends.org/download.html"

if (-not (Test-Path "$XamppPath\xampp-control.exe")) {

    # Allow the user to pre-place the installer to skip the download entirely.
    # If the file already exists at $xamppInstaller and is larger than 10 MB,
    # it is assumed to be the real binary and the download is skipped.
    $preExisting = (Test-Path $xamppInstaller) -and ((Get-Item $xamppInstaller).Length -gt 10MB)

    if ($preExisting) {
        Write-Host "  Found pre-placed installer at $xamppInstaller - skipping download." -ForegroundColor Gray
    } else {
        Write-Host "  Downloading XAMPP installer (this may take a few minutes)..." -ForegroundColor Gray

        $downloaded = $false

        # Prefer curl.exe (ships with Windows 10 1803+). It follows HTTP 302
        # redirects reliably. The -e flag sets the Referer header that
        # SourceForge requires to serve a redirect instead of HTML.
        # Note: avoid the ?. operator - not supported on Windows PowerShell 5.1.
        $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
        $curlBin = if ($curlCmd) { $curlCmd.Source } else { $null }

        if ($curlBin) {
            Write-Host "  Using curl.exe..." -ForegroundColor Gray
            $curlArgs = @("-L", "--max-redirs", "10", "--retry", "3",
                          "-e", $xamppReferer,
                          "-A", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                          "-o", $xamppInstaller, $xamppUrl)
            $curl = Start-Process -FilePath $curlBin -ArgumentList $curlArgs `
                        -Wait -PassThru -NoNewWindow
            if ($curl.ExitCode -eq 0 -and
                (Test-Path $xamppInstaller) -and
                (Get-Item $xamppInstaller).Length -gt 10MB) {
                $downloaded = $true
            }
        }

        if (-not $downloaded) {
            Write-Host "  Falling back to WebClient..." -ForegroundColor Gray
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $wc.Headers.Add("Referer", $xamppReferer)
            try {
                $wc.DownloadFile($xamppUrl, $xamppInstaller)
            } finally {
                $wc.Dispose()
            }
        }
    }

    # Sanity-check: a real installer is several hundred MB; an HTML error page
    # is tiny. Abort early with a clear message instead of a cryptic COM error.
    $installerSize = (Get-Item $xamppInstaller).Length
    if ($installerSize -lt 10MB) {
        Remove-Item $xamppInstaller -Force -ErrorAction SilentlyContinue
        $msg  = "XAMPP installer is only $([math]::Round($installerSize/1KB)) KB - this is an HTML page, not the binary.`n"
        $msg += "SourceForge is blocking automated downloads. Please:`n"
        $msg += "  1. Download XAMPP 8.2.12 (Windows x64) from https://www.apachefriends.org/download.html`n"
        $msg += "  2. Copy the downloaded file to: $xamppInstaller`n"
        $msg += "  3. Re-run this script."
        throw $msg
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

$httpdExe = "$XamppPath\apache\bin\httpd.exe"

# XAMPP can register Apache under several service names depending on version
# and install method.  Manually-installed XAMPP does NOT auto-register Apache
# as a Windows service (you normally click Install in the Control Panel).
# We handle that registration here so the script works either way.
$apacheSvcNames = @("Apache2.4", "Apache2", "Apache")
$svc = $null
foreach ($n in $apacheSvcNames) {
    $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "  Found Apache service: $n" -ForegroundColor Gray
        break
    }
}

if (-not $svc) {
    if (Test-Path $httpdExe) {
        Write-Host "  Apache not registered as a service - registering now..." -ForegroundColor Gray
        $instArgs = @{
            FilePath     = $httpdExe
            ArgumentList = "-k install"
            Wait         = $true
            PassThru     = $true
            NoNewWindow  = $true
        }
        $inst = Start-Process @instArgs
        if ($inst.ExitCode -eq 0) {
            Write-Host "  Apache service registered successfully." -ForegroundColor Gray
            foreach ($n in $apacheSvcNames) {
                $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
                if ($svc) { break }
            }
        } else {
            Write-Host "  Service registration returned exit $($inst.ExitCode) - will try direct launch." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  httpd.exe not found at: $httpdExe" -ForegroundColor Red
        Write-Host "  Is XAMPP installed at $XamppPath ?" -ForegroundColor Red
    }
}

if ($svc) {
    if ($svc.Status -ne 'Running') {
        Start-Service $svc.Name -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $svc.Refresh()
    }
    if ($svc.Status -eq 'Running') {
        Write-Host "  Apache service '$($svc.Name)' is running." -ForegroundColor Green
    } else {
        Write-Host "  Service did not start - falling back to direct launch." -ForegroundColor Yellow
        if (Test-Path $httpdExe) {
            Start-Process -FilePath $httpdExe -ArgumentList "-k start" -NoNewWindow
            Start-Sleep -Seconds 2
        }
    }
} else {
    Write-Host "  Starting Apache directly (no Windows service)..." -ForegroundColor Yellow
    if (Test-Path $httpdExe) {
        Start-Process -FilePath $httpdExe -ArgumentList "-k start" -NoNewWindow
        Start-Sleep -Seconds 2
    } else {
        Write-Host "  ERROR: Cannot locate httpd.exe" -ForegroundColor Red
        Write-Host "  Open the XAMPP Control Panel and click Start next to Apache." -ForegroundColor Yellow
    }
}

# Open port 80 in Windows Firewall
New-NetFirewallRule -DisplayName "MGH CTF HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue | Out-Null

# Quick sanity-check: is something listening on port 80?
Start-Sleep -Seconds 1
$port80 = $null
try { $port80 = (netstat -an 2>$null | Select-String ":80 .*LISTEN") } catch {}
if ($port80) {
    Write-Host "  Apache is listening on port 80." -ForegroundColor Green
} else {
    Write-Host "  Warning: port 80 not detected yet." -ForegroundColor Yellow
    Write-Host "  If the portal does not load, open XAMPP Control Panel and Start Apache." -ForegroundColor Yellow
}

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
Write-Host "    FLAG 3 (Dental Record)   : patient DB - exploit IDOR on /records.php?pid=MGH-0044"
Write-Host "    FLAG 4 (Security Footage): camera DB  - forge Cookie: role=admin on /camera.php"
Write-Host "    FLAG 5 (Prescription)    : $hospitalDir\prescriptions\hidden\rx_chow_encoded.txt"
Write-Host "                               (path traversal: ?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt then Base64 decode)"
Write-Host ""
