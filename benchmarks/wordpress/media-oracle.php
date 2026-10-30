<?php
require $argv[1].'/wp-load.php';
function c7_read($path,$params=[]){$r=new WP_REST_Request('GET',$path);foreach($params as $k=>$v){$r->set_param($k,$v);}$response=rest_do_request($r);return ['code'=>$response->get_status(),'data'=>rest_get_server()->response_to_data($response,false),'headers'=>$response->get_headers()];}
wp_set_current_user(0);$manifest=json_decode(file_get_contents($argv[2]),true,512,JSON_THROW_ON_ERROR);$ids=[];$slugs=[];
$uploads=wp_upload_dir();$dir=$uploads['basedir'].'/moonpress-c7';if(!wp_mkdir_p($dir)){throw new RuntimeException('Cannot prepare disposable media');}
foreach($manifest['files'] as $f){
 $path=$dir.'/'.$f['name'];$bytes=base64_decode($f['base64'],true);if($bytes===false||file_put_contents($path,$bytes)===false){throw new RuntimeException('Cannot write fixture');}
 $id=wp_insert_attachment(['post_title'=>$f['name'],'post_name'=>substr($f['name'],0,-4),'post_status'=>'inherit','post_mime_type'=>$f['mime']],$path,0,true);if(is_wp_error($id)){throw new RuntimeException($id->get_error_message());}
 update_attached_file($id,$path);wp_update_attachment_metadata($id,['filesize'=>strlen($bytes)]);$ids[]=(int)$id;$slugs[]=get_post_field('post_name',$id);
}
$queries=[];
foreach($manifest['queries'] as $q){$params=$q['params'];foreach(['include','exclude'] as $key){if(isset($params[$key])){$params[$key]=array_map(fn($index)=>$ids[$index],$params[$key]);}}if(isset($params['slug'])){$params['slug']=array_map(fn($index)=>$slugs[$index],$params['slug']);}$queries[]=['query'=>$q,'result'=>c7_read('/wp/v2/media',$params)];}
$details=[];foreach($ids as $id){foreach(['view','embed'] as $context){$details[]=['id'=>$id,'context'=>$context,'result'=>c7_read('/wp/v2/media/'.$id,['context'=>$context])];}}
file_put_contents($argv[3],json_encode(['ids'=>$ids,'queries'=>$queries,'details'=>$details],JSON_THROW_ON_ERROR));
