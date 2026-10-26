<?php
// Disposable WordPress core, never a production installation.
require $argv[1] . '/wp-load.php';
$roles = ['anonymous'=>0, 'administrator'=>1];
foreach (['author','subscriber'] as $role) {
    $id = username_exists('moonpress-meta-' . $role);
    if (!$id) { $id = wp_insert_user(['user_login'=>'moonpress-meta-' . $role, 'user_pass'=>wp_generate_password(32), 'role'=>$role]); }
    if (is_wp_error($id)) { throw new RuntimeException('Cannot prepare oracle role'); }
    $roles[$role] = (int)$id;
}
$probes = [];
foreach ($roles as $role=>$id) {
    wp_set_current_user($id);
    foreach (['types','types/post','types/page','statuses','statuses/publish','statuses/draft','statuses/future','statuses/trash'] as $route) {
        foreach (['view','embed','edit'] as $context) {
            $request = new WP_REST_Request('GET', '/wp/v2/' . $route);
            $request->set_param('context', $context);
            $response = rest_do_request($request);
            $probes[] = ['route'=>$route,'role'=>$role,'context'=>$context,'status'=>$response->get_status(),'data'=>$response->get_data()];
        }
    }
}
wp_set_current_user(1);
$posts = [];
for ($i=1; $i<=3; $i++) {
    $slug = 'moonpress-link-oracle-' . $i;
    $id = wp_insert_post(['post_type'=>'post','post_status'=>'publish','post_title'=>'Link oracle ' . $i,'post_name'=>$slug,'post_date'=>'2020-01-01 00:00:00','post_date_gmt'=>'2020-01-01 00:00:00'], true);
    if (is_wp_error($id)) { throw new RuntimeException('Cannot seed pagination fixture'); }
    $posts[] = ['id'=>(int)$id,'slug'=>$slug];
}
wp_set_current_user(0);
$request = new WP_REST_Request('GET', '/wp/v2/posts');
foreach (['slug'=>array_column($posts,'slug'),'per_page'=>1,'page'=>2,'orderby'=>'id','order'=>'asc'] as $key=>$value) { $request->set_param($key,$value); }
$response = rest_do_request($request);
$pagination = ['posts'=>$posts,'ids'=>array_column($response->get_data(),'id'),'headers'=>$response->get_headers()];
file_put_contents($argv[2], json_encode(['probes'=>$probes,'pagination'=>$pagination], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE));
