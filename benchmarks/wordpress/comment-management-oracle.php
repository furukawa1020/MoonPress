<?php
require $argv[1].'/wp-load.php';
function c6_request($path,$params=[],$verb='GET') {
 $request=new WP_REST_Request($verb,$path);foreach($params as $k=>$v){$request->set_param($k,$v);}
 $response=rest_do_request($request);return ['code'=>$response->get_status(),'data'=>rest_get_server()->response_to_data($response,false),'headers'=>$response->get_headers()];
}
$roles=['subscriber','contributor','author','editor','administrator'];$users=[];
foreach($roles as $role){$login='c6-'.$role;$id=wp_create_user($login,'disposable-oracle-password',$login.'@example.invalid');if(is_wp_error($id)){$id=username_exists($login);}if(!$id){throw new RuntimeException('Cannot seed user');}(new WP_User($id))->set_role($role);$users[$role]=(int)$id;}
$fixtures=[['kind'=>'post','status'=>'publish','owner'=>'author'],['kind'=>'post','status'=>'draft','owner'=>'contributor'],['kind'=>'page','status'=>'publish','owner'=>'author'],['kind'=>'post','status'=>'publish','owner'=>'editor']];
$comments=[];$posts=[];
foreach($fixtures as $i=>$f){
 $p=wp_insert_post(['post_title'=>'c6-'.$i,'post_name'=>'c6-'.$i,'post_type'=>$f['kind'],'post_status'=>$f['status'],'post_author'=>$users[$f['owner']],'comment_status'=>'open'],true);if(is_wp_error($p)){throw new RuntimeException('Cannot seed article');}$posts[]=(int)$p;
 $comments[]=(int)wp_insert_comment(['comment_post_ID'=>$p,'comment_author'=>'Reader','comment_content'=>'Original','comment_approved'=>1,'comment_type'=>'comment','user_id'=>$users['subscriber'],'comment_date'=>'2024-01-01 00:00:00','comment_date_gmt'=>'2024-01-01 00:00:00']);
}
$probes=[];
foreach($fixtures as $i=>$f){foreach(array_merge(['anonymous'],$roles) as $role){
 wp_set_current_user($role==='anonymous'?0:$users[$role]);$path='/wp/v2/comments/'.$comments[$i];
 $probes[]=['fixture'=>$i,'role'=>$role,'read'=>c6_request($path,['context'=>'edit']),'write'=>c6_request($path,['content'=>['raw'=>'Changed'],'author_name'=>'Changed'],'POST')];
}}
$collections=[];foreach(array_merge(['anonymous'],$roles) as $role){wp_set_current_user($role==='anonymous'?0:$users[$role]);$collections[]=['role'=>$role,'result'=>c6_request('/wp/v2/comments',['context'=>'edit','include'=>$comments,'orderby'=>'id','order'=>'asc','per_page'=>100])];}
wp_set_current_user($users['editor']);$sequence=[];$path='/wp/v2/comments/'.$comments[0];
foreach([['POST',['status'=>'hold']],['PUT',['status'=>'approve']],['PATCH',['status'=>'spam']],['PATCH',['status'=>'hold']],['POST',['content'=>['raw'=>"Multiline\nText"],'author_name'=>'Edited','status'=>'approve']],['DELETE',['force'=>false]],['POST',['status'=>'hold']],['PATCH',['status'=>'approve']]] as [$verb,$body]){$sequence[]=['verb'=>$verb,'body'=>$body,'result'=>c6_request($path,$body,$verb)];}
$order=[];foreach(['asc','desc'] as $direction){$order[]=['direction'=>$direction,'result'=>c6_request('/wp/v2/comments',['include'=>$comments,'orderby'=>'type','order'=>$direction,'per_page'=>100])];}
file_put_contents($argv[2],json_encode(['users'=>$users,'fixtures'=>$fixtures,'posts'=>$posts,'comments'=>$comments,'probes'=>$probes,'collections'=>$collections,'sequence'=>$sequence,'type_order'=>$order],JSON_THROW_ON_ERROR));
