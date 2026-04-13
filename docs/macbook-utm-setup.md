# 🍎 Running the CTF on a MacBook — UTM (x86 Windows) Guide

This guide walks you through running the **Mercury General Hospital CTF** on an
Apple Silicon or Intel MacBook using **UTM** as your hypervisor, with an x86-64
Windows guest.

It also covers **exporting the finished VM to VMDK / OVF** so it can be shared
with players running VMware Workstation, VMware Fusion, or VirtualBox.

---

## Table of Contents

1. [Why UTM?](#1-why-utm)
2. [Prerequisites](#2-prerequisites)
3. [Install UTM on your Mac](#3-install-utm-on-your-mac)
4. [Create an x86-64 Windows VM](#4-create-an-x86-64-windows-vm)
5. [Install the CTF inside the Windows VM](#5-install-the-ctf-inside-the-windows-vm)
6. [Network Setup — attacking from your Mac](#6-network-setup--attacking-from-your-mac)
7. [Export to VMDK / VMware-compatible image](#7-export-to-vmdk--vmware-compatible-image)
8. [Import VMDK in VMware Fusion (Mac)](#8-import-vmdk-in-vmware-fusion-mac)
9. [Import VMDK in VMware Workstation (Windows/Linux)](#9-import-vmdk-in-vmware-workstation-windowslinux)
10. [Import VMDK in VirtualBox](#10-import-vmdk-in-virtualbox)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Why UTM?

[UTM](https://mac.getutm.app/) is a free, open-source hypervisor for macOS built
on QEMU. Key advantages for this CTF:

| Feature | Detail |
|---------|--------|
| **Free** | No licence fee, unlike VMware Fusion Pro |
| **Apple Silicon support** | Runs x86-64 VMs via emulation on M1/M2/M3/M4 Macs |
| **Intel Mac support** | Runs x86-64 VMs via hardware acceleration (WHPX / HVF) |
| **QCOW2 / VMDK support** | Can export to formats compatible with VMware and VirtualBox |
| **App Store & direct download** | Easy to install |

> **Note for Apple Silicon Macs (M1/M2/M3/M4):**  
> UTM will *emulate* x86-64, which is slower than native ARM virtualisation.
> Expect the Windows VM to boot in 3–5 minutes and be noticeably slower than
> on an Intel Mac. The CTF itself is very lightweight, so it will still work fine.
> If performance is critical, consider the [Docker approach](#alternative-docker)
> instead.

---

## 2. Prerequisites

You need:

| Item | Where to get it |
|------|----------------|
| **UTM 4.x** | [mac.getutm.app](https://mac.getutm.app/) or Mac App Store |
| **Windows ISO** | Windows 10 or Windows Server 2019 (any edition) |
| **This repository** | Already cloned to the VM (or copy from your Mac) |
| **QEMU tools** (for VMDK export) | `brew install qemu` |

### Getting a Windows ISO

- **Windows 10 (free evaluation):** [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise)
- **Windows Server 2019 (180-day eval):** [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019)

Download the **x64** ISO. The filename will be something like
`Win10_22H2_English_x64.iso`.

---

## 3. Install UTM on your Mac

**Option A — Direct download (recommended, always latest version):**

1. Go to [mac.getutm.app](https://mac.getutm.app/)
2. Click **Download**
3. Open the downloaded `.dmg`, drag **UTM.app** to `/Applications`

**Option B — Mac App Store:**

Search for "UTM" and click **Get** (identical app, updates through App Store).

**Option C — Homebrew:**

```bash
brew install --cask utm
```

---

## 4. Create an x86-64 Windows VM

### Step 1 — Open UTM and create a new VM

1. Launch **UTM**
2. Click **Create a New Virtual Machine**
3. Select **Emulate** (required for Apple Silicon; on Intel you can pick either
   Emulate or Virtualize — choose **Virtualize** for better performance)

> **Apple Silicon users:** You *must* choose **Emulate** to run an x86-64 Windows
> guest. Choosing Virtualize would only let you run ARM Windows.

### Step 2 — Operating System

Select **Windows** from the list.

### Step 3 — Hardware

| Setting | Recommended value |
|---------|-------------------|
| Architecture | x86_64 |
| RAM | **4096 MB** (4 GB minimum; 6–8 GB if your Mac has ≥ 16 GB RAM) |
| CPU Cores | **2–4** |

### Step 4 — Storage

| Setting | Value |
|---------|-------|
| Storage size | **60 GB** (enough for Windows + XAMPP + repo) |

Leave the "Import VHDX / VHD" field empty — you will boot from your ISO.

### Step 5 — Shared directory (optional but recommended)

Enable the shared directory option and point it to the folder where you cloned
this repository on your Mac. This lets you copy files into the VM without
needing USB or networking tricks.

```
/Users/<yourname>/path/to/Mercury-General-Hospital
```

### Step 6 — Summary

Give the VM a name like **Mercury General Hospital CTF** and click **Save**.

### Step 7 — Attach the Windows ISO

1. Select your new VM in the UTM sidebar
2. Click the **pencil icon** (Edit)
3. Go to **Drives** → click **New Drive** → choose **Import** → select your
   Windows ISO
4. Make sure the new drive's **Interface** is set to `USB` and **Boot Order**
   puts this drive first
5. Click **Save**

### Step 8 — Boot and install Windows

1. Click the **▶ Play** button in UTM
2. The VM will boot from the ISO into the Windows installer
3. Follow the Windows Setup wizard:
   - Language: English, Time: your preference, Keyboard: your layout
   - Click **Install now**
   - Accept the licence
   - Choose **Custom: Install Windows only**
   - Select the unallocated disk → **Next**
4. Windows will install and reboot several times (allow 20–40 minutes on
   Apple Silicon due to emulation overhead)
5. Complete the OOBE (Out-of-Box Experience): create a local user account called
   `ctfadmin` with any password you like

### Step 9 — Install SPICE Guest Tools (for clipboard/display)

After Windows boots, in the UTM menu bar choose:
**Virtual → Install SPICE Guest Tools and QEMU Agent**

This installs drivers that improve display resolution and enable copy-paste
between your Mac and the VM.

### Step 10 — Detach the ISO

1. Shut down the Windows VM
2. Edit the VM → Drives → select the ISO drive → **Remove**
3. Save and restart — Windows will now boot from the disk

---

## 5. Install the CTF inside the Windows VM

### Option A — Via Shared Folder (easiest)

If you set up a shared directory in Step 5 above:

1. Boot the Windows VM
2. Open **File Explorer** → click **Network** in the left sidebar
3. You should see a network share — double-click it to see your Mac files
4. Copy the `Mercury-General-Hospital` folder to `C:\`

If the share doesn't appear automatically, map it:

```
net use Z: \\10.0.2.2\qemu /persistent:yes
```

Then navigate to `Z:\` in File Explorer.

### Option B — Via USB Drive

Copy the repo to a USB drive, plug it into your Mac, and use
**Virtual → USB → Mount** in UTM to attach it to the VM.

### Option C — Download directly in the VM

Inside the VM, open a browser and download a ZIP of the repo from GitHub, or
open PowerShell and run:

```powershell
cd C:\
git clone https://github.com/at0m-b0mb/Mercury-General-Hospital.git
```

(Install [Git for Windows](https://git-scm.com/download/win) first if needed.)

### Run the CTF setup script

Once the repo is on the VM:

1. Open **PowerShell as Administrator**:
   Start → search "PowerShell" → right-click → **Run as administrator**

2. Navigate to the setup folder:

```powershell
cd C:\Mercury-General-Hospital\setup
```

3. Run the setup script:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup.ps1
```

The script will:
- Download and install **XAMPP** (Apache + PHP)
- Deploy the patient portal web application
- Create the hospital file structure with all hidden prescription files
- Create CTF user accounts (`reception`, `drpatel`, `mgh-admin`)
- Start Apache and open port 80 in Windows Firewall

4. When the script finishes, it will print a URL like:

```
Portal URL: http://10.0.2.15/patient-portal/login.php
```

Open that URL **inside the Windows VM** in a browser to verify it works.

---

## 6. Network Setup — Attacking from your Mac

You want to attack the Windows VM from your Mac (e.g. using a Kali terminal on
your Mac). Here are the two UTM networking modes:

### Mode A — Shared Network (default, easiest)

UTM puts the VM behind NAT. The VM has an IP like `10.0.2.15` that is **not
directly reachable** from your Mac.

To reach it from your Mac, set up a **port forward** in UTM:

1. Shut down the VM
2. Edit the VM → **Network** → click **New Port Forward**:

| Field | Value |
|-------|-------|
| Protocol | TCP |
| Guest Address | (leave blank) |
| Guest Port | 80 |
| Host Address | 127.0.0.1 |
| Host Port | 8080 |

3. Save and restart the VM
4. From your Mac, the CTF is now reachable at:

```
http://127.0.0.1:8080/patient-portal/login.php
```

### Mode B — Bridged Network (recommended for multi-player CTF)

Bridged mode puts the VM directly on your local network, making it reachable
from any machine on the same Wi-Fi.

1. Shut down the VM
2. Edit the VM → **Network**
3. Change **Network Mode** from `Shared Network` to `Bridged (Advanced)`
4. Set **Bridged Interface** to `en0` (your Mac's Wi-Fi adapter)
5. Save and restart the VM
6. Inside the VM, run `ipconfig` to find the VM's IP (e.g. `192.168.1.50`)
7. Players on the same network can now attack:

```
http://192.168.1.50/patient-portal/login.php
```

---

## 7. Export to VMDK / VMware-compatible image

VMDK (VMware Virtual Machine Disk) is the format used by VMware Fusion, VMware
Workstation, and (with conversion) VirtualBox.

### Step 1 — Shut down the Windows VM cleanly

Inside the VM: **Start → Power → Shut down**. Wait for UTM to show the VM as
stopped.

### Step 2 — Find the UTM VM bundle and the disk image

UTM stores VMs as `.utm` bundles in:

```
~/Library/Containers/com.utmapp.UTM/Data/Documents/
```

Or if you installed UTM from the Mac App Store, check:

```
~/Library/Group Containers/JEMA986UMX.com.utmapp.UTM/Library/Application Support/utmapp/Documents/
```

Right-click your VM in UTM → **Show in Finder** to locate it quickly.

Inside the `.utm` bundle (right-click → **Show Package Contents**):

```
Mercury General Hospital CTF.utm/
└── Data/
    └── <UUID>.qcow2      ← this is the disk image
```

Note the full path — you will need it in the next step.

### Step 3 — Install QEMU tools on your Mac (for qemu-img)

```bash
brew install qemu
```

Verify:

```bash
qemu-img --version
```

### Step 4 — Convert QCOW2 → VMDK

Replace the paths below with the actual UUID and location from Step 2:

```bash
# Navigate somewhere with plenty of free space (the VMDK will be ~20–40 GB)
cd ~/Desktop

qemu-img convert \
  -f qcow2 \
  -O vmdk \
  -o subformat=streamOptimized \
  "/Users/<you>/Library/Containers/com.utmapp.UTM/Data/Documents/Mercury General Hospital CTF.utm/Data/<UUID>.qcow2" \
  "MercuryGeneralHospital.vmdk"
```

> **`-o subformat=streamOptimized`** produces a compressed, portable VMDK that
> VMware can import directly. Use `subformat=monolithicSparse` for a larger but
> more widely compatible file.

This step may take 10–30 minutes depending on the disk size and your Mac's CPU.

### Step 5 (optional) — Create an OVF package for easy import

An OVF (Open Virtualization Format) package bundles the VMDK with machine
metadata so VMware/VirtualBox can import all settings in one click.

Create a minimal `MercuryGeneralHospital.ovf`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Envelope xmlns="http://schemas.dmtf.org/ovf/envelope/1">
  <References>
    <File ovf:id="disk1" ovf:href="MercuryGeneralHospital.vmdk"/>
  </References>
  <DiskSection>
    <Disk ovf:diskId="disk1" ovf:fileRef="disk1"
          ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized"
          ovf:capacity="64424509440"/>
  </DiskSection>
  <VirtualSystem ovf:id="MercuryGeneralHospital">
    <Name>Mercury General Hospital CTF</Name>
    <OperatingSystemSection ovf:id="80">
      <Description>Windows 10 (64-bit)</Description>
    </OperatingSystemSection>
    <VirtualHardwareSection>
      <Item><rasd:ElementName>2 virtual CPU</rasd:ElementName>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>2</rasd:VirtualQuantity></Item>
      <Item><rasd:ElementName>4096 MB RAM</rasd:ElementName>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>4096</rasd:VirtualQuantity></Item>
    </VirtualHardwareSection>
  </VirtualSystem>
</Envelope>
```

Or use `ovftool` (included with VMware Fusion / Workstation) to generate it:

```bash
ovftool MercuryGeneralHospital.vmdk MercuryGeneralHospital.ovf
```

---

## 8. Import VMDK in VMware Fusion (Mac)

1. Open **VMware Fusion**
2. File → **Import…** (if you have an OVF) — or —
   File → **New** → **Create a custom virtual machine**
3. If importing OVF: select `MercuryGeneralHospital.ovf` → Continue → Save
4. If using VMDK directly:
   - Choose OS: **Windows 10 and later x64**
   - On the **Virtual Machine Configuration** screen, click **Customize Settings**
   - Under **Hard Disk**, remove the default disk and click **Add Device →
     Existing Hard Disk** → select `MercuryGeneralHospital.vmdk`
5. Set RAM to **4 GB**, CPU to **2 cores**
6. Click **Finish / Play**

---

## 9. Import VMDK in VMware Workstation (Windows/Linux)

1. Open **VMware Workstation**
2. **File → Open…** → select `MercuryGeneralHospital.vmdk`
   (Workstation can open VMDK files directly as a virtual machine)
3. If prompted about a non-standard VM, click **Retry**
4. Edit VM settings → set RAM to 4 GB, CPUs to 2
5. Click **Power On**

Alternatively, use **File → Import…** if you have the OVF package.

---

## 10. Import VMDK in VirtualBox

VirtualBox uses VDI natively but can import VMDK files.

**Option A — Directly attach the VMDK:**

1. **Machine → New**
2. Name: `Mercury General Hospital CTF`, Type: Windows, Version: Windows 10 (64-bit)
3. RAM: 4096 MB
4. On the **Hard disk** screen, choose **Use an existing virtual hard disk file**
5. Click the folder icon → **Add** → select `MercuryGeneralHospital.vmdk`
6. Click **Create**, then **Start**

**Option B — Convert VMDK → VDI (better VirtualBox compatibility):**

```bash
VBoxManage clonehd MercuryGeneralHospital.vmdk MercuryGeneralHospital.vdi --format VDI
```

Then attach the VDI in step 5 above instead of the VMDK.

---

## Alternative: Docker (no Windows VM needed) {#alternative-docker}

If you only need the web application (not the full Windows environment with
NTFS permissions and Windows user accounts), Docker is much faster and works
natively on both Apple Silicon and Intel Macs:

```bash
# From the repo root
docker-compose up --build -d
```

The portal is then available at `http://localhost:80/patient-portal/login.php`.

> **Limitation:** The Docker approach doesn't replicate the NTFS permission
> structure used for the path traversal challenge. The web vulnerability flags
> (FLAG 3, 4, 5) all work fine via Docker.

---

## 11. Troubleshooting

### Windows VM boots to black screen in UTM (Apple Silicon)

- Wait up to 5 minutes — x86 emulation is slow on first boot
- If still black after 5 min: Edit VM → Display → change **Emulated Display Card**
  to `VGA` instead of `virtio-vga`

### "Secure Boot" / "TPM required" error during Windows 11 install

Use Windows 10 instead — it has no TPM requirement. Windows 11 requires a TPM
which complicates QEMU/UTM setup.

### setup.ps1 fails: "Running scripts is disabled"

Run this first in PowerShell (as Administrator):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### XAMPP Apache won't start ("Port 80 already in use")

IIS or another service may be using port 80. In PowerShell (as Administrator):

```powershell
# Find what's using port 80
netstat -ano | findstr :80
# Kill it by PID (replace 1234 with the actual PID)
Stop-Process -Id 1234 -Force
```

Or configure XAMPP to use port 8080 by editing
`C:\xampp\apache\conf\httpd.conf` and changing `Listen 80` to `Listen 8080`.

### qemu-img: "error opening input file — permission denied"

The `.utm` bundle is protected by macOS. Grant terminal access:

**System Preferences → Privacy & Security → Full Disk Access → Terminal** (or
your terminal app) → toggle ON.

### VMDK import fails in VMware ("unsupported or invalid disk type")

Re-convert using `monolithicSparse` subformat instead of `streamOptimized`:

```bash
qemu-img convert -f qcow2 -O vmdk \
  -o subformat=monolithicSparse \
  input.qcow2 MercuryGeneralHospital.vmdk
```

### VM network not reachable from Mac after port forward

Make sure:
1. Apache is running in the VM (`http://localhost/` works *inside* the VM)
2. Windows Firewall allows port 80 inbound (the setup script does this, but
   verify with `netsh advfirewall firewall show rule name="MGH CTF HTTP"`)
3. The UTM port forward uses **Host Address: 127.0.0.1** (not 0.0.0.0 for
   security)

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│  MacBook (attacker)          Windows VM (target)            │
│                                                             │
│  Terminal / Browser  ──────► UTM Port Forward 8080 → 80    │
│  http://127.0.0.1:8080       Apache + PHP + CTF portal      │
│                              C:\MercuryGeneral\...          │
└─────────────────────────────────────────────────────────────┘

Shared Network (NAT):   Mac → 127.0.0.1:8080 → VM:80
Bridged Network:        Any machine → 192.168.x.x:80 → VM:80
```

---

*For general CTF setup questions see [`setup/README.md`](../setup/README.md).*  
*For the attack walkthrough see [`solution/walkthrough.md`](../solution/walkthrough.md).*
