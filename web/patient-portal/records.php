<?php
// records.php — Patient record search
// VULNERABILITY: Insecure Direct Object Reference (IDOR)
// The search and list use secure prepared statements.
// However the individual record detail view (?pid=MGH-XXXX) only checks that the
// user is authenticated — it does NOT verify that their role permits access to this
// patient's department/record.  Any staff member (including low-privilege reception)
// can directly request any patient's full record, including physician notes and flag,
// by supplying a known or guessed patient ID in the URL.
require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/db.php';
require_login();

$search  = $_GET['search'] ?? '';
$pid     = $_GET['pid']    ?? '';   // patient_id string, e.g. MGH-0044
$results = [];
$detail  = null;
$error   = '';

// Secure search — prepared statement with LIKE
if ($search !== '') {
    $like = '%' . $search . '%';
    $stmt = $pdo->prepare(
        "SELECT id, patient_id, first_name, last_name, dob FROM patients
         WHERE first_name LIKE ? OR last_name LIKE ? OR patient_id LIKE ?"
    );
    $stmt->execute([$like, $like, $like]);
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
}

// IDOR: record detail is fetched by patient_id string from URL.
// Authentication is checked (require_login above) but there is no
// authorisation check — any role can reach any patient's full record.
if ($pid !== '') {
    $stmt = $pdo->prepare("SELECT * FROM patients WHERE patient_id = ?");
    $stmt->execute([$pid]);
    $detail = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$detail) {
        $error = 'Patient record not found.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Patient Records — Mercury General Hospital</title>
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

    <?php if ($detail): ?>
    <!-- Individual patient record view -->
    <div class="card">
        <h2>📋 Patient Record — <?= htmlspecialchars($detail['first_name'] . ' ' . $detail['last_name']) ?></h2>
        <div class="record-detail">
            <p><span class="field-label">Patient ID:</span> <?= htmlspecialchars($detail['patient_id']) ?></p>
            <p><span class="field-label">Name:</span> <?= htmlspecialchars($detail['first_name'] . ' ' . $detail['last_name']) ?></p>
            <p><span class="field-label">Date of Birth:</span> <?= htmlspecialchars($detail['dob']) ?></p>
            <p><span class="field-label">Physician Notes:</span><br>
               <?= nl2br(htmlspecialchars($detail['notes'] ?? 'No notes on file.')) ?>
            </p>
            <?php if (!empty($detail['flag'])): ?>
            <div class="flag-box">🚩 <?= htmlspecialchars($detail['flag']) ?></div>
            <?php endif; ?>
        </div>
        <br>
        <a href="/records.php" class="btn btn-primary">← Back to Search</a>
    </div>

    <?php else: ?>
    <!-- Search form -->
    <div class="card">
        <h2>📋 Patient Records Search</h2>
        <form method="GET" action="/records.php">
            <div class="search-bar">
                <div style="flex:1">
                    <label for="search">Search by name or patient ID</label>
                    <input type="search" id="search" name="search"
                           value="<?= htmlspecialchars($search) ?>"
                           placeholder="e.g. Smith, MGH-0044">
                </div>
                <button type="submit" class="btn btn-primary">Search</button>
            </div>
        </form>

        <?php if ($error): ?>
            <div class="alert alert-error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <?php if ($search !== '' && empty($results) && !$error): ?>
            <div class="alert alert-info">No records matched your search.</div>
        <?php endif; ?>

        <?php if (!empty($results)): ?>
        <table>
            <thead>
                <tr>
                    <th>Patient ID</th>
                    <th>First Name</th>
                    <th>Last Name</th>
                    <th>DOB</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach ($results as $row): ?>
                <tr>
                    <td><?= htmlspecialchars($row['patient_id']) ?></td>
                    <td><?= htmlspecialchars($row['first_name']) ?></td>
                    <td><?= htmlspecialchars($row['last_name']) ?></td>
                    <td><?= htmlspecialchars($row['dob']) ?></td>
                    <td><a href="/records.php?pid=<?= urlencode($row['patient_id']) ?>" class="btn btn-primary" style="padding:5px 14px;font-size:.85rem;">View</a></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <?php endif; ?>
    </div>
    <?php endif; ?>

</div>
<footer>Mercury General Hospital &copy; 2009 — Confidential</footer>
</body>
</html>
