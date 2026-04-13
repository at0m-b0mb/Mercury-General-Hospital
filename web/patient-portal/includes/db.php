<?php
// db.php — SQLite database initialisation

$db_path = __DIR__ . '/hospital.db';
$pdo = new PDO('sqlite:' . $db_path);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Create tables if they don't exist
$pdo->exec("
CREATE TABLE IF NOT EXISTS users (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    role     TEXT NOT NULL DEFAULT 'staff'
);

CREATE TABLE IF NOT EXISTS patients (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id  TEXT NOT NULL UNIQUE,
    first_name  TEXT NOT NULL,
    last_name   TEXT NOT NULL,
    dob         TEXT NOT NULL,
    notes       TEXT,
    flag        TEXT
);

CREATE TABLE IF NOT EXISTS camera_logs (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    camera_id  TEXT NOT NULL,
    timestamp  TEXT NOT NULL,
    event      TEXT NOT NULL,
    flag       TEXT
);
");

// Seed default data if tables are empty
$count = $pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
if ($count == 0) {
    // Staff accounts (SHA-1 password hashes)
    $pdo->exec("INSERT INTO users (username, password, role) VALUES
        ('admin',     'e405e1563f7391c03f4a28dfda0e0874a6b34675', 'admin'),
        ('drpatel',   '471874a0b856cf240cb429bd1a7e83f5c520f5d1', 'doctor'),
        ('reception', '1ecd7bca6714b73c06bff71a040f615a0af72802', 'staff')
    ");

    // Patient records
    $pdo->exec("INSERT INTO patients (patient_id, first_name, last_name, dob, notes, flag) VALUES
        ('MGH-0042', 'Alan',   'Garner',   '1971-03-12', 'Admitted for observation. Patient brought in by family.', NULL),
        ('MGH-0043', 'Phil',   'Wenneck',  '1973-07-04', 'Minor lacerations. Discharged same day.', NULL),
        ('MGH-0044', 'Stuart', 'Price',    '1975-11-21',
            'Patient self-extracted tooth #8 (upper central incisor) at 02:47 on admission date. States he did so ''to prove his love.'' Administered local anaesthetic post-extraction. Accompanying individual described as a short, angry Asian man who dropped patient off and left immediately. Attending physician: Dr. R. Patel.',
            'FLAG{d3nt4l_r3c0rd_stu_pull3d_h1s_0wn_t00th_0247AM_t0_pr0v3_h1s_l0v3}')
    ");

    // Camera log entries
    $pdo->exec("INSERT INTO camera_logs (camera_id, timestamp, event, flag) VALUES
        ('CAM-01', '2009-06-01 00:14:00', 'Motion detected — lobby entrance. Two males entered.', NULL),
        ('CAM-02', '2009-06-01 01:55:00', 'Motion detected — emergency bay. Vehicle: silver Mercedes. Four individuals and large duffel bag.', NULL),
        ('CAM-03', '2009-06-01 03:15:00',
            'Motion detected — rear car park. Subjects: Phil Wenneck, Stuart Price, Alan Garner, and unidentified male (short stature, later identified as Leslie Chow). Loading heavy object into trunk of silver Mercedes. License plate visible: NV ESV-7749. Plate traced to warehouse at 3850 S Valley View Blvd, Las Vegas, NV 89103.',
            'FLAG{s3cur1ty_f00t4g3_ESV7749_Ch0w_w4r3h0us3_3850_V4ll3y_V13w}'),
        ('CAM-04', '2009-06-01 03:22:00', 'Vehicle exited rear car park heading south on Valley View Blvd.', NULL)
    ");
}
