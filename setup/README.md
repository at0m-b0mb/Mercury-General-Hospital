# 🔧 Mercury General Hospital — Setup Guide

## Deployment Options

| Platform | Guide |
|----------|-------|
| **Windows** (bare-metal or any x86 VM) | [Windows Setup](#windows-setup) below |
| **MacBook with UTM** (x86 Windows VM, Apple Silicon or Intel) | 📄 [docs/macbook-utm-setup.md](../docs/macbook-utm-setup.md) |
| **VMware Fusion / Workstation** | 📄 [docs/macbook-utm-setup.md — VMware section](../docs/macbook-utm-setup.md#8-import-vmdk-in-vmware-fusion-mac) |
| **VirtualBox** | 📄 [docs/macbook-utm-setup.md — VirtualBox section](../docs/macbook-utm-setup.md#10-import-vmdk-in-virtualbox) |
| **Docker** (web app only, any OS) | [Docker Setup](#docker-setup) below |

---

## Windows Setup

### Requirements

- Windows Server 2019 / Windows 10 or later (x64)
- PowerShell 5.1+ (run as **Administrator**)
- Internet access (to download XAMPP during setup)

### Quick Start

```powershell
# From an Administrator PowerShell prompt:
cd C:\path\to\Mercury-General-Hospital\setup

# Allow script execution for this session
Set-ExecutionPolicy Bypass -Scope Process -Force

# Run the setup script
.\setup.ps1
```

The script will:
1. Download and silently install **XAMPP** (Apache 2.4 + PHP 8.2)
2. Deploy the **patient portal** web app directly to `C:\xampp\htdocs\`
3. Deploy the **hospital file structure** to `C:\xampp\htdocs\hospital-files\` (HTTP access blocked by `.htaccess`; readable by PHP via path traversal)
4. Create local Windows user accounts (reception, drpatel, mgh-admin)
5. Start Apache and open port 80 in Windows Firewall

### Custom Paths

```powershell
.\setup.ps1 -XamppPath "D:\xampp"
```

### Verifying the Setup

After the script completes:

- Browse to `http://localhost/login.php` — you should see the login page.
- Log in with `reception` / `W0lfpack2009!` (low-privilege staff account).

---

## Docker Setup

> **Note:** Docker runs only the web application (no Windows users / NTFS permissions).
> All three web flags (IDOR, Broken Access Control, Path Traversal) work correctly.

```bash
# From the repo root
docker-compose up --build -d
```

Portal: `http://localhost/login.php`

```bash
# Stop
docker-compose down
```

---

## Default Credentials (CTF organiser reference)

Players do **not** receive these — they are meant to be discovered via exploitation
(credentials are in `web/patient-portal/staff-backup/credentials.txt`).

| Account    | Password       | Role      |
|------------|----------------|-----------|
| reception  | W0lfpack2009!  | staff     |
| drpatel    | H4ng0v3rMD!    | doctor    |
| mgh-admin  | Sup3rS3cr3t!   | admin     |

## Flag Locations (CTF organiser reference)

| Flag | Location | Exploit |
|------|----------|---------|
| FLAG 3 | `patients` DB table, `flag` column (patient MGH-0044) | IDOR — request `/records.php?pid=MGH-0044` (no role check on detail view) |
| FLAG 4 | `camera_logs` DB table, `flag` column (CAM-03) | Broken Access Control — forge `Cookie: role=admin` |
| FLAG 5 | `C:\xampp\htdocs\hospital-files\prescriptions\hidden\rx_chow_encoded.txt` | Path traversal: `files.php?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt` + Base64 decode |

## Resetting the Machine

To reset to a clean CTF state:

```powershell
# Delete the SQLite database (resets to seeded data on next page load)
Remove-Item "C:\xampp\htdocs\includes\hospital.db" -Force
# Restart Apache
Restart-Service Apache2.4
```

---

## macOS / UTM / VMware / VirtualBox

For full instructions on running this on a MacBook with UTM, or distributing
as a VMDK for VMware / VirtualBox, see:

📄 **[docs/macbook-utm-setup.md](../docs/macbook-utm-setup.md)**
