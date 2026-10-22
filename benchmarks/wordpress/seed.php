<?php
// Only called against the comparator's disposable database and synthetic corpus.
if ($argc !== 4) { exit(2); }
$root = $argv[1];
$data = json_decode(file_get_contents($argv[2]), true, 512, JSON_THROW_ON_ERROR);
$origin = $argv[3];
$_SERVER['HTTP_HOST'] = parse_url($origin, PHP_URL_HOST) . ':' . parse_url($origin, PHP_URL_PORT);
$_SERVER['REQUEST_METHOD'] = 'GET';
$_SERVER['REQUEST_URI'] = '/';
define('WP_INSTALLING', true);
require $root . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
if (!is_blog_installed()) {
    wp_install('Synthetic benchmark', 'benchmark', 'nobody@example.invalid', false, '', bin2hex(random_bytes(24)));
}
wp_set_current_user(1);
update_option('home', $origin);
update_option('siteurl', $origin);
update_option('template', 'moonpress-benchmark');
update_option('stylesheet', 'moonpress-benchmark');
update_option('permalink_structure', '');
update_option('default_comment_status', 'closed');
update_option('default_ping_status', 'closed');
update_option('active_plugins', []);
foreach (get_posts(['post_type'=>'any', 'post_status'=>'any', 'numberposts'=>-1]) as $post) {
    wp_delete_post($post->ID, true);
}
$mapping = [];
foreach ($data['articles'] as $article) {
    $body = implode("\n", array_map(fn($p) => '<p>' . esc_html($p) . '</p>', $article['paragraphs']));
    $id = wp_insert_post(['import_id'=>$article['id']+100, 'post_type'=>'post', 'post_status'=>'publish',
        'post_title'=>$article['title'], 'post_name'=>$article['slug'], 'post_content'=>$body,
        'post_date'=>'2026-01-01 00:00:00', 'post_date_gmt'=>'2026-01-01 00:00:00',
        'comment_status'=>'closed', 'ping_status'=>'closed'], true);
    if (is_wp_error($id)) { throw new RuntimeException($id->get_error_message()); }
    $mapping[(string)$article['id']] = $id;
}
wp_cache_flush();
echo json_encode(['wordpress_version'=>$wp_version, 'php_version'=>PHP_VERSION,
    'database_version'=>$wpdb->get_var('SELECT VERSION()'), 'mapping'=>$mapping,
    'count'=>count($mapping), 'plugins'=>get_option('active_plugins'), 'theme'=>'moonpress-benchmark',
    'post_revisions'=>WP_POST_REVISIONS, 'cron_disabled'=>DISABLE_WP_CRON], JSON_THROW_ON_ERROR) . "\n";
