<?php
// Runs only inside the disposable WordPress benchmark installation.
require $argv[1].'/wp-load.php';
$users=[];$posts=[];$comments=[];
foreach(['author','editor','subscriber'] as $role){
 $login='c9-'.$role;$id=wp_create_user($login,'disposable-fixture-password',$login.'@example.invalid');
 if(is_wp_error($id)){$id=username_exists($login);}
 (new WP_User($id))->set_role($role);wp_update_user(['ID'=>$id,'display_name'=>$role]);$users[$role]=(int)$id;
}
foreach(['post','page'] as $kind){
 $id=wp_insert_post(['post_title'=>'c9-'.$kind,'post_name'=>'c9-'.$kind,'post_type'=>$kind,'post_status'=>'publish','post_author'=>$users[$kind==='post'?'author':'editor'],'comment_status'=>'open'],true);
 if(is_wp_error($id)){throw new RuntimeException('Cannot seed article');}$posts[$kind]=(int)$id;
}
wp_set_object_terms($posts['post'],['c9-category'],'category');wp_set_object_terms($posts['post'],['c9-tag'],'post_tag');
foreach([['root',0,'subscriber',1],['child','root','author',1],['held','root','subscriber',0]] as [$name,$parent,$owner,$approved]){
 $comments[$name]=(int)wp_insert_comment(['comment_post_ID'=>$posts['post'],'comment_parent'=>$parent?$comments[$parent]:0,'comment_author'=>$name,'comment_content'=>'Text '.$name,'comment_approved'=>$approved,'comment_type'=>'comment','user_id'=>$owner?$users[$owner]:0]);
}
function c9_request($path,$params){
 $request=new WP_REST_Request('GET',$path);foreach($params as $key=>$value){$request->set_param($key,$value);}
 $response=rest_do_request($request);$embed=array_key_exists('_embed',$params)?rest_parse_embed_param($params['_embed']):false;
 return ['code'=>$response->get_status(),'data'=>rest_get_server()->response_to_data($response,$embed)];
}
$probes=[];
foreach(['anonymous','subscriber','author'] as $actor){
 wp_set_current_user($actor==='anonymous'?0:$users[$actor]);
 foreach(['post','page','root','child'] as $target){
  $path=isset($posts[$target])?'/wp/v2/'.($target==='page'?'pages':'posts').'/'.$posts[$target]:'/wp/v2/comments/'.$comments[$target==='anonymous-comment'?'anonymous':$target];
  foreach([null,'','true','1','0','false','author','wp:term','replies','up','in-reply-to','children','author,wp:term','https://api.w.org/term'] as $selector){
   $params=$selector===null?[]:['_embed'=>$selector];
   $probes[]=['actor'=>$actor,'target'=>$target,'selector'=>$selector,'result'=>c9_request($path,$params)];
  }
 }
}
$parser=[];foreach(['','true','1','0','false',' , ','author,wp:term author'] as $value){$parser[$value]=rest_parse_embed_param($value);}
file_put_contents($argv[2],json_encode(['users'=>$users,'posts'=>$posts,'comments'=>$comments,'probes'=>$probes,'parser'=>$parser],JSON_THROW_ON_ERROR));
