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
echo 'WXR actual WordPress import passed: ' . count($expected) . " posts/pages; titles/content/status/source/taxonomy verified.\n";
