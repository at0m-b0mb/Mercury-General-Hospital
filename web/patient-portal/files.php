<?php
// files.php — Hospital file viewer
// VULNERABILITY: Path traversal on the 'file' parameter.
// The application reads files relative to a base directory (docs/) but does NOT
// sanitise '../' sequences, allowing players to read arbitrary files on the system,
// including the hidden prescription file that contains FLAG 5.
//
// Intended traversal target (all platforms):
//   ?file=../hospital-files/prescriptions/hidden/rx_chow_encoded.txt
//
// Layout: docs/ is one level below the web root; hospital-files/ sits adjacent
// to docs/ at the same level as the web root.  One '../' escapes docs/ and
// lands in htdocs, then 'hospital-files/...' reaches the target directory.
//
require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/db.php';
require_login();

// Base directory for "public" hospital documents
define('FILES_BASE', realpath(__DIR__ . '/docs'));

$file    = $_GET['file'] ?? '';
$content = null;
$error   = '';

// Allowed "public" files listing (never shows the hidden prescription dir)
$public_files = [
    'hospital_info.txt'        => 'Mercury General Hospital — General Information',
    'staff_directory.txt'      => 'Staff Directory',
    'patient_intake_form.txt'  => 'Patient Intake Form Template',
    'emergency_protocols.txt'  => 'Emergency Protocols',
];

if ($file !== '') {
    // VULNERABILITY: path traversal — base path is not enforced
    $target = FILES_BASE . DIRECTORY_SEPARATOR . $file;
    if (file_exists($target) && is_file($target)) {
        $content = file_get_contents($target);
    } else {
        $error = 'File not found: ' . htmlspecialchars($file);
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>File Viewer — Mercury General Hospital</title>
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

    <?php if ($content !== null): ?>
    <div class="card">
        <h2>📄 <?= htmlspecialchars(basename($file)) ?></h2>
        <a href="/files.php" class="btn btn-primary" style="margin-bottom:16px;display:inline-block;">← Back</a>
        <pre style="background:#f4f4f4;padding:16px;border-radius:5px;overflow-x:auto;white-space:pre-wrap;font-size:.9rem;"><?= htmlspecialchars($content) ?></pre>
    </div>

    <?php else: ?>
    <div class="card">
        <h2>📂 Hospital Documents</h2>
        <p style="margin-bottom:18px;color:var(--text-muted);">
            Select a document below, or specify a file path directly using the
            <code>?file=</code> URL parameter (e.g. <code>?file=hospital_info.txt</code>).
        </p>

        <?php if ($error): ?>
            <div class="alert alert-error"><?= $error ?></div>
        <?php endif; ?>

        <table>
            <thead>
                <tr><th>Filename</th><th>Description</th><th>Action</th></tr>
            </thead>
            <tbody>
            <?php foreach ($public_files as $fname => $desc): ?>
                <tr>
                    <td><code><?= htmlspecialchars($fname) ?></code></td>
                    <td><?= htmlspecialchars($desc) ?></td>
                    <td><a href="/files.php?file=<?= urlencode($fname) ?>" class="btn btn-primary" style="padding:5px 14px;font-size:.85rem;">View</a></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php endif; ?>

</div>
<footer>Mercury General Hospital &copy; 2009 — Confidential</footer>
</body>
</html>
