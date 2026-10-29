<?php
require $argv[1] . '/wp-load.php';
wp_set_current_user(1);
$login='moonpress-c3-author';$author=username_exists($login);
if (!$author) { $author=wp_insert_user(['user_login'=>$login,'user_pass'=>wp_generate_password(32),'display_name'=>$login,'role'=>'author']); }
if (is_wp_error($author)) { throw new RuntimeException('Cannot seed author'); }
$rows=[];$created=[];
for ($i=0;$i<16;$i++) {
    $params=['title'=>($i&1)?['raw'=>'Raw title '.$i]:'Raw title '.$i,'content'=>($i&2)?['raw'=>'<p>Safe <strong>bold</strong> text.</p>']:'<p>Safe <strong>bold</strong> text.</p>','excerpt'=>($i&4)?['raw'=>'Plain summary']:'Plain summary','status'=>'draft',(($i&8)?'date':'date_gmt')=>'2020-01-02T03:04:05'];
    $request=new WP_REST_Request('POST','/wp/v2/posts');
    foreach($params as $k=>$v){$request->set_param($k,$v);}
    $response=rest_do_request($request);
    if($response->get_status()!==201){throw new RuntimeException('Core raw input creation failed: '.json_encode($response->get_data()));}
    $rows[]=['params'=>$params,'data'=>$response->get_data()];$created[]=$response->get_data()['id'];
}
$request=new WP_REST_Request('GET','/wp/v2/posts');foreach(['context'=>'edit','status'=>'draft','include'=>$created,'orderby'=>'title','order'=>'asc','per_page'=>100] as $k=>$v){$request->set_param($k,$v);}$response=rest_do_request($request);$title_order=array_map(fn($row)=>$row['title']['raw'],$response->get_data());
$post=wp_insert_post(['post_title'=>'Public author fixture','post_status'=>'publish','post_author'=>$author,'post_name'=>'c3-public-author','post_date'=>'2020-01-01 00:00:00','post_date_gmt'=>'2020-01-01 00:00:00'],true);
if(is_wp_error($post)){throw new RuntimeException('Cannot seed public article');}
$comment=wp_insert_comment(['comment_post_ID'=>$post,'comment_author'=>'Public reader','comment_content'=>'Core comment text.','comment_approved'=>'1','comment_type'=>'comment','comment_parent'=>0,'user_id'=>$author,'comment_date'=>'2020-01-02 03:04:05','comment_date_gmt'=>'2020-01-02 03:04:05']);
wp_set_current_user(0);
$comments=[];
foreach(['view','embed'] as $context){$request=new WP_REST_Request('GET','/wp/v2/comments/'.$comment);$request->set_param('context',$context);$response=rest_do_request($request);if($response->get_status()!==200){throw new RuntimeException('Core public comment failed');}$comments[$context]=rest_get_server()->response_to_data($response,false);}
$request=new WP_REST_Request('GET','/wp/v2/users/'.$author);$response=rest_do_request($request);if($response->get_status()!==200){throw new RuntimeException('Core public author failed');}
file_put_contents($argv[2],json_encode(['title_order'=>$title_order,'raw'=>$rows,'author'=>$response->get_data(),'post'=>(int)$post,'comment'=>$comments],JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE));
