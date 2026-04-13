<?php
// login.php — Staff authentication
require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/db.php';

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = sha1($_POST['password'] ?? '');

    $stmt = $pdo->prepare("SELECT * FROM users WHERE username = ? AND password = ?");
    $stmt->execute([$username, $password]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['user']    = ['username' => $user['username'], 'role' => $user['role']];
        header('Location: /index.php');
        exit;
    } else {
        $error = 'Invalid username or password.';
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Mercury General Hospital — Login</title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <style>
        body { align-items: center; justify-content: center; }
        .login-wrap { max-width: 420px; width: 100%; margin: 0 auto; padding: 60px 20px; }
        .login-wrap .card { padding: 40px; }
        .login-wrap h2 { text-align: center; margin-bottom: 24px; font-size: 1.35rem; }
        .login-wrap .btn { width: 100%; text-align: center; padding: 12px; font-size: 1rem; }
        .hospital-icon { text-align: center; font-size: 2.5rem; margin-bottom: 8px; }
    </style>
</head>
<body>
<header>
    <div>
        <div class="logo">🏥 Mercury General Hospital</div>
        <div class="tagline">Patient Portal v2.3 — Internal Use Only</div>
    </div>
</header>
<div class="login-wrap">
    <div class="card">
        <div class="hospital-icon">🏥</div>
        <h2>Staff Login</h2>

        <?php if ($error): ?>
            <div class="alert alert-error">⚠️ <?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <form method="POST" action="/login.php">
            <label for="username">Username</label>
            <input type="text" id="username" name="username" placeholder="Enter username" required autocomplete="off">

            <label for="password">Password</label>
            <input type="password" id="password" name="password" placeholder="Enter password" required>

            <button type="submit" class="btn btn-primary">Login →</button>
        </form>

        <p style="margin-top:18px;font-size:.78rem;color:var(--text-muted);text-align:center;">
            Authorised personnel only. All access is logged and audited.
        </p>
    </div>
</div>
<footer>Mercury General Hospital &copy; 2009 — Confidential</footer>
</body>
</html>
