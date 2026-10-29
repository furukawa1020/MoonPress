<?php
require $argv[1].'/wp-load.php';
wp_set_current_user(1);
function c5req($path,$params=[],$method='GET') {
 $r=new WP_REST_Request($method,$path);foreach($params as $k=>$v){$r->set_param($k,$v);}
 $v=rest_do_request($r);return ['code'=>$v->get_status(),'rows'=>$v->get_data(),'headers'=>$v->get_headers()];
}
$posts=[];
foreach(['one','two'] as $name){$posts[]=wp_insert_post(['post_title'=>'c5-'.$name,'post_name'=>'c5-'.$name,'post_status'=>'publish','comment_status'=>'open']);}
$labels=['Alpha','Z','beta','Alpha'];$ids=[];
foreach($labels as $i=>$name){
 $ids[]=wp_insert_comment(['comment_post_ID'=>$posts[$i===2?1:0],'comment_parent'=>$i===1?$ids[0]:0,'comment_author'=>$name,'comment_content'=>'Text '.$i,'comment_approved'=>1,'comment_date'=>'2024-02-03 04:05:06','comment_date_gmt'=>'2024-02-03 04:05:06','user_id'=>1]);
}
$probes=[];
foreach(['id','date','date_gmt','parent','post','include'] as $orderby){foreach(['asc','desc'] as $order){$q=['include'=>[$ids[3],$ids[1],$ids[0],$ids[2]],'orderby'=>$orderby,'order'=>$order];$probes[]=$q;}}
foreach([['parent'=>[0]],['parent'=>[$ids[0]]],['parent_exclude'=>[0]],['post'=>[$posts[0]]],['search'=>'Alpha'],['include'=>[$ids[2],$ids[0]],'exclude'=>[$ids[0]]],['per_page'=>2],['per_page'=>2,'page'=>2],['per_page'=>2,'page'=>99],['per_page'=>2,'offset'=>1],['per_page'=>2,'offset'=>0,'page'=>2],['per_page'=>2,'offset'=>99],['per_page'=>2,'offset'=>1,'page'=>99]] as $q){$probes[]=array_merge(['include'=>$ids,'orderby'=>'id','order'=>'asc'],$q);}
$probes[]=['orderby'=>'author_name','order'=>'asc'];$probes[]=['orderby'=>'author_name','order'=>'desc'];
$results=[];foreach($probes as $q){$results[]=['params'=>$q,'result'=>c5req('/wp/v2/comments',$q)];}
// Compare authenticated pending creation with core explicitly configured to moderate all comments.
$user=wp_create_user('c5-reader','disposable-oracle-password','c5-reader@example.invalid');if(is_wp_error($user)){$user=username_exists('c5-reader');}
wp_set_current_user($user);add_filter('pre_comment_approved',fn()=>0);
$created=c5req('/wp/v2/comments',['post'=>$posts[0],'parent'=>$ids[0],'content'=>['raw'=>"Pending\nreply\n\nText"]],'POST');
file_put_contents($argv[2],json_encode(['posts'=>$posts,'ids'=>$ids,'probes'=>$results,'created'=>$created]));
