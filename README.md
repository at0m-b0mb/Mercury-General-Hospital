# 🏥 Mercury General Hospital — CTF Machine

> *"What happened last night?"*  
> *Las Vegas, 2 June 2009, 6:47 AM — three men wake up in a trashed hotel suite with no memory of the night before. The only lead: a receipt from Mercury General Hospital.*

---

## Machine Details

| Detail       | Info                                  |
|--------------|---------------------------------------|
| **OS**       | Windows (also runs on Linux/Docker)   |
| **Difficulty** | Easy–Medium                         |
| **Flags**    | 3 (FLAG 3, FLAG 4, FLAG 5)            |
| **Services** | HTTP (80)                             |
| **Stack**    | PHP 8 + SQLite + Apache               |

---

## Story

The Wolfpack has tracked down a lead at **Mercury General Hospital** in Las Vegas.
Stu's dental records are in their system — he apparently pulled his own tooth at
2:47 AM *"to prove his love."*

The hospital's patient portal is running outdated software with a series of
glaring security misconfigurations:

- A credential backup file left on the web server
- No authorization checks on patient record access  
- Camera footage restricted by a client-controlled cookie
- A hidden prescription archive reachable via path traversal

Three flags are waiting to be found.

---

## The Three Flags

| Flag | Name                    | Vulnerability                                    | Points |
|------|-------------------------|--------------------------------------------------|--------|
| FLAG 3 | **The Dental Record** | **IDOR** — access any patient record by ID       | 100    |
| FLAG 4 | **The Security Footage** | **Broken Access Control** — forge a role cookie to unlock restricted camera logs | 150 |
| FLAG 5 | **The Prescription**  | **Path Traversal** — read a hidden file + Base64 decode | 200 |

### Why these three vulnerabilities?

| Vuln | Real-world significance |
|------|------------------------|
| **IDOR** | OWASP Top 10 #1. Responsible for countless healthcare data breaches. Easy to exploit, often overlooked in code review. |
| **Broken Access Control** | OWASP Top 10 #1 (same category). Trusting client-supplied data for security decisions is one of the most common mistakes in web development. |
| **Path Traversal** | OWASP Top 10 #3 (Injection). Still found in production systems. Teaches filesystem security and the danger of unsanitized file paths. |

---

## Setup

| Platform | Guide |
|----------|-------|
| **Windows** (bare-metal or VM) | [`setup/README.md`](setup/README.md) |
| **MacBook (UTM — x86 Windows VM)** | [`docs/macbook-utm-setup.md`](docs/macbook-utm-setup.md) |
| **VMware Fusion / Workstation** | [`docs/macbook-utm-setup.md`](docs/macbook-utm-setup.md#8-import-vmdk-in-vmware-fusion-mac) |
| **VirtualBox** | [`docs/macbook-utm-setup.md`](docs/macbook-utm-setup.md#10-import-vmdk-in-virtualbox) |
| **Docker** (web app only, any OS) | `docker-compose up --build -d` |

**Quick start on Windows (run as Administrator):**

```powershell
cd setup
.\setup.ps1
```

**Quick start on Mac (UTM):** see [docs/macbook-utm-setup.md](docs/macbook-utm-setup.md) for the full step-by-step guide including VMDK/VMware export.

---

## Attack Path (Spoiler-free)

1. **Enumerate** the web application on port 80 using standard recon tools
2. **Discover** a hidden directory that leaks staff credentials
3. **Log in** and identify authorization flaws in the patient records system
4. **Escalate** your access to unlock restricted camera footage
5. **Traverse** the file system to locate and decode a hidden prescription archive

---

## Intended Attack Chain (Organizers Only)

See [`solution/walkthrough.md`](solution/walkthrough.md).

---

## Flag Format

All flags follow the format: `FLAG{...}`

---

## Recommended Tools

| Tool | Use |
|------|-----|
| `nmap` / browser | Port scan + initial recon |
| `curl` / browser DevTools | Request manipulation, cookie editing |
| Burp Suite (Community) | Intercept and modify HTTP requests |
| `base64 -d` / CyberChef | Decode FLAG 5 |

---

## CTF Safety Notice

This machine is intentionally vulnerable. Deploy it only on an **isolated network**
or **localhost**. Do not expose it to the internet.
