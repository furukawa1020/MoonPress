<?php
// Actual core REST handlers against the imported fixture, after all timings.
require $argv[1] . '/wp-load.php';
wp_set_current_user(0);
$result = ['ids'=>[], 'responses'=>[]];
foreach (['oracle-post', 'oracle-page', 'oracle-draft', 'oracle-unlisted', 'oracle-future'] as $slug) {
    $kind = $slug === 'oracle-page' ? 'page' : 'post';
    // Resolve private fixture IDs as the disposable owner; dispatch as anonymous.
    wp_set_current_user(1);
    $posts = get_posts(['post_type'=>$kind, 'name'=>$slug, 'post_status'=>'any', 'numberposts'=>2]);
    if (count($posts) !== 1) { throw new RuntimeException('Missing REST oracle fixture: ' . $slug . ' count=' . count($posts)); }
    $result['ids'][$slug] = ['id'=>(int)$posts[0]->ID, 'author'=>(int)$posts[0]->post_author];
    $path = '/wp/v2/' . ($kind === 'page' ? 'pages' : 'posts');
    $request = new WP_REST_Request('GET', $path);
    $request->set_param('slug', $slug);
    wp_set_current_user(0);
    $response = rest_do_request($request);
    if ($response->get_status() !== 200) { throw new RuntimeException('Core REST read failed'); }
    $result['responses'][$slug] = $response->get_data();
}
if (file_put_contents($argv[2], json_encode($result, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE)) === false) {
    throw new RuntimeException('Cannot retain REST oracle responses');
}
