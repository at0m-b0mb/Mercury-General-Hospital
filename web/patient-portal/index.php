<?php
// index.php — portal home page
require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/db.php';
require_login();
$user = current_user();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Mercury General Hospital — Patient Portal</title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <script src="/assets/js/portal.js" defer></script>
    <!--
        Mercury General Hospital — Internal Patient Portal
        Version 2.3  |  Deployed: 2009-05-28
        Webmaster: it-helpdesk@mercury-general.internal

        Hint: Good sysadmins always check robots.txt first.
    -->
</head>
<body>
<header>
    <div>
        <div class="logo">🏥 Mercury General Hospital</div>
        <div class="tagline">Patient Portal v2.3 — Internal Use Only</div>
    </div>
    <nav>
        <a href="/index.php">Home</a>
        <a href="/records.php">Patient Records</a>
        <a href="/camera.php">Security Logs</a>
        <a href="/files.php">Files</a>
        <a href="/logout.php">Logout</a>
    </nav>
</header>
<div class="container">
    <div class="card">
        <h1>Welcome, <?= htmlspecialchars($user['username']) ?>
            <span class="badge badge-<?= htmlspecialchars($user['role']) ?>"><?= htmlspecialchars($user['role']) ?></span>
        </h1>
        <p style="color:var(--text-muted);margin-top:6px;">
            You are logged in to the Mercury General Hospital internal patient portal.<br>
            Use the navigation above to access patient records, security camera logs, and the file store.
        </p>
    </div>

    <div class="card">
        <h2>Quick Links</h2>
        <ul class="quick-links" style="margin-top:8px;">
            <li>
                <a href="/records.php">📋 Patient Records</a>
                <span style="color:var(--text-muted);font-size:.85rem;margin-left:8px;">— search and view patient files</span>
            </li>
            <li>
                <a href="/camera.php">📹 Security Camera Logs</a>
                <span style="color:var(--text-muted);font-size:.85rem;margin-left:8px;">— review camera event history</span>
            </li>
            <li>
                <a href="/files.php">📂 File Viewer</a>
                <span style="color:var(--text-muted);font-size:.85rem;margin-left:8px;">— browse and download hospital documents</span>
            </li>
        </ul>
    </div>

    <div class="card" style="border-left: 4px solid #f59e0b; background: #fffbeb;">
        <h2 style="color:#b45309;">⚠️ System Notice</h2>
        <p style="color:#92400e;font-size:.9rem;">
            Las Vegas Metro Police have requested access to security footage from the night of 1 June 2009.
            All camera logs from that date are under administrative review.
            Please contact Dr. Patel or the admin team for authorised access.
        </p>
    </div>
</div>
<footer>Mercury General Hospital &copy; 2009 — Confidential</footer>
</body>
</html>
