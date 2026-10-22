<?php
// Read-only comparison against the disposable benchmark's actual core roles.
require $argv[1] . '/wp-load.php';
$rows = json_decode(file_get_contents($argv[2]), true, 32, JSON_THROW_ON_ERROR);
foreach ($rows as $row) {
    $role = get_role($row['role']);
    if (!$role) { throw new RuntimeException('Missing core role: ' . $row['role']); }
    foreach ($row['capabilities'] as $capability) {
        if (!$role->has_cap($capability)) {
            throw new RuntimeException('Native advertised capability exceeds core role: ' . $row['role'] . '/' . $capability);
        }
    }
}
echo "Native access advertised capability subset matches actual WordPress core roles.\n";
