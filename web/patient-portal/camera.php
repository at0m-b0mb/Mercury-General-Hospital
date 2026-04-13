<?php
// camera.php — Security camera log viewer
// VULNERABILITY: Broken Access Control via cookie manipulation.
// The flag data in sensitive log entries is gated on a role check, but the role is
// read from the client-supplied 'role' cookie before falling back to the server-side
// session.  Any authenticated user can forge Cookie: role=admin to expose the flag.
require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/db.php';
require_login();

$session_user = current_user();

// VULNERABILITY: client-controlled cookie takes precedence over session role
$display_role = $_COOKIE['role'] ?? $session_user['role'];

$camera_id = $_GET['camera'] ?? '';
$logs      = [];
$error     = '';

// All queries use prepared statements — no injection possible
if ($camera_id !== '') {
    $stmt = $pdo->prepare(
        "SELECT camera_id, timestamp, event, flag FROM camera_logs WHERE camera_id = ?"
    );
    $stmt->execute([$camera_id]);
    $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);
} else {
    $stmt = $pdo->query(
        "SELECT camera_id, timestamp, event, flag FROM camera_logs ORDER BY timestamp"
    );
    $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);
}

// The flag column is only rendered when $display_role is admin or doctor.
// Because $display_role comes from a cookie, players can forge it.
$can_see_flags = ($display_role === 'admin' || $display_role === 'doctor');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Security Logs — Mercury General Hospital</title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <script src="/assets/js/portal.js" defer></script>
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
        <h2>📹 Security Camera Event Log</h2>
        <p style="margin-bottom:18px;color:#555;">Filter by camera ID to view specific camera events.
           <!-- role-restricted content requires doctor or admin access -->
        </p>

        <form method="GET" action="/camera.php">
            <div class="search-bar">
                <div style="flex:1">
                    <label for="camera">Camera ID</label>
                    <input type="text" id="camera" name="camera"
                           value="<?= htmlspecialchars($camera_id) ?>"
                           placeholder="e.g. CAM-01">
                </div>
                <button type="submit" class="btn btn-primary">Filter</button>
            </div>
        </form>

        <?php if ($error): ?>
            <div class="alert alert-error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <?php if (empty($logs) && !$error): ?>
            <div class="alert alert-info">No events found.</div>
        <?php endif; ?>

        <?php if (!empty($logs)): ?>
        <table>
            <thead>
                <tr>
                    <th>Camera</th>
                    <th>Timestamp</th>
                    <th>Event</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach ($logs as $log): ?>
                <tr>
                    <td><?= htmlspecialchars($log['camera_id']) ?></td>
                    <td><?= htmlspecialchars($log['timestamp']) ?></td>
                    <td>
                        <?= htmlspecialchars($log['event']) ?>
                        <?php if ($can_see_flags && !empty($log['flag'])): ?>
                            <div class="flag-box" style="margin-top:8px;">🚩 <?= htmlspecialchars($log['flag']) ?></div>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <?php endif; ?>
    </div>
</div>
<footer>Mercury General Hospital &copy; 2009 — Confidential</footer>
</body>
</html>
