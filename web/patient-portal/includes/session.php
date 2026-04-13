<?php
// session.php — simple session helpers
session_start();

function is_logged_in(): bool {
    return isset($_SESSION['user_id']);
}

function require_login(): void {
    if (!is_logged_in()) {
        header('Location: /login.php');
        exit;
    }
}

function current_user(): array {
    return $_SESSION['user'] ?? [];
}
