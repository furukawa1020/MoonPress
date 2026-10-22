<?php
// Disposable runner-only database; never accepted from a user project.
define('DB_NAME', 'moonpress_benchmark');
define('DB_USER', 'moonpress_bench');
define('DB_PASSWORD', getenv('MOONPRESS_BENCH_DB_PASSWORD'));
define('DB_HOST', '127.0.0.1');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
$table_prefix = 'bench_';
define('WP_DEBUG', false);
define('WP_ENVIRONMENT_TYPE', 'local');
define('WP_HTTP_BLOCK_EXTERNAL', true);
define('DISABLE_WP_CRON', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_AUTO_UPDATE_CORE', false);
define('WP_POST_REVISIONS', false);
define('WP_CACHE', false);
foreach (['AUTH_KEY','SECURE_AUTH_KEY','LOGGED_IN_KEY','NONCE_KEY','AUTH_SALT','SECURE_AUTH_SALT','LOGGED_IN_SALT','NONCE_SALT'] as $key) {
    define($key, hash('sha256', getenv('MOONPRESS_BENCH_DB_PASSWORD') . $key));
}
if (!defined('ABSPATH')) { define('ABSPATH', __DIR__ . '/'); }
require_once ABSPATH . 'wp-settings.php';
