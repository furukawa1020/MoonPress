<?php
// Runs only after benchmarks on the same disposable runner/database.
define('WP_LOAD_IMPORTERS', true);
require $argv[1] . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/import.php';
require_once ABSPATH . 'wp-admin/includes/admin.php';
require_once $argv[2] . '/wordpress-importer.php';
wp_set_current_user(1);
$expected = json_decode(file_get_contents($argv[4]), true, 512, JSON_THROW_ON_ERROR);
$importer = new WP_Import();
$importer->fetch_attachments = false;
ob_start();
$importer->import($argv[3]);
$output = ob_get_clean();
foreach ($expected as $row) {
    $posts = get_posts(['post_type'=>$row['kind'], 'name'=>$row['slug'], 'post_status'=>'any', 'numberposts'=>2]);
    if (count($posts) !== 1) { throw new RuntimeException('Expected exactly one imported post: ' . $row['slug'] . "\n" . $output); }
    $post = $posts[0];
    if ($post->post_title !== $row['title'] || $post->post_content !== $row['html'] || $post->post_status !== $row['status']) {
        throw new RuntimeException('Imported title/content/status differs: ' . $row['slug']);
    }
    if (get_post_meta($post->ID, '_moonpress_source_v1', true) !== $row['source']) {
        throw new RuntimeException('Source round trip differs: ' . $row['slug']);
    }
    foreach (['category'=>$row['categories'], 'post_tag'=>$row['tags']] as $taxonomy=>$names) {
        // WP core pages do not register categories/tags. The exporter retains
        // them in source metadata; this oracle uses only post taxonomies.
        if ($row['kind'] === 'page') { continue; }
        $actual = wp_get_object_terms($post->ID, $taxonomy, ['fields'=>'names']);
        sort($actual); sort($names);
        if ($actual !== $names) { throw new RuntimeException('Taxonomy differs: ' . $row['slug']); }
    }
}
$success = 'WXR actual WordPress import passed: ' . count($expected) . " posts/pages; titles/content/status/source/taxonomy verified.\n";
// Also exercise actual core export in the opposite direction.
$plain_id = wp_insert_post(['post_type'=>'post', 'post_status'=>'publish', 'post_title'=>'WordPress native intake oracle', 'post_name'=>'wp-native-intake-oracle', 'post_content'=>'<h2>Heading</h2><p>Native intake text &amp; data.</p>', 'post_date'=>'2020-01-01 00:00:00', 'post_date_gmt'=>'2020-01-01 00:00:00'], true);
if (is_wp_error($plain_id)) { throw new RuntimeException($plain_id->get_error_message()); }
require_once ABSPATH . 'wp-admin/includes/export.php';
ob_start();
export_wp(['content'=>'post']);
$wxr = ob_get_clean();
if (file_put_contents(dirname($argv[3]) . '/wordpress-export.xml', $wxr) === false) { throw new RuntimeException('Cannot retain core WXR export'); }

echo $success;
