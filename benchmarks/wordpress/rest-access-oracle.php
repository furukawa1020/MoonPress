<?php
// Actual map_meta_cap decisions on disposable data, after all timed work.
require $argv[1] . '/wp-load.php';
wp_set_current_user(1);
$other = wp_insert_user(['user_login'=>'native-rest-other', 'user_pass'=>wp_generate_password(48), 'role'=>'subscriber']);
if (is_wp_error($other)) { throw new RuntimeException($other->get_error_message()); }
$rows = [];
foreach (['administrator', 'subscriber', 'contributor', 'author', 'editor'] as $role) {
    $user = wp_insert_user(['user_login'=>'native-rest-' . $role, 'user_pass'=>wp_generate_password(48), 'role'=>$role]);
    if (is_wp_error($user)) { throw new RuntimeException($user->get_error_message()); }
    foreach (['post', 'page'] as $kind) {
        foreach ([false, true] as $published) {
            foreach ([true, false] as $own) {
                $post = wp_insert_post(['post_type'=>$kind, 'post_status'=>$published ? 'publish' : 'draft', 'post_title'=>'Native REST permission oracle', 'post_content'=>'Fixture', 'post_author'=>$own ? $user : $other], true);
                if (is_wp_error($post)) { throw new RuntimeException($post->get_error_message()); }
                $rows[] = ['role'=>$role, 'kind'=>$kind, 'published'=>$published, 'own'=>$own, 'allowed'=>user_can($user, 'edit_post', $post), 'delete_allowed'=>user_can($user, 'delete_post', $post)];
            }
        }
    }
}
if (file_put_contents($argv[2], json_encode($rows, JSON_THROW_ON_ERROR)) === false) { throw new RuntimeException('Cannot retain access decisions'); }
