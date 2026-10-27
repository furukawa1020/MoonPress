<?php
require $argv[1] . '/wp-load.php';
wp_set_current_user(1);
function c4_request($path,$params=[],$method='GET') {
    $request=new WP_REST_Request($method,$path);
    foreach($params as $k=>$v){$request->set_param($k,$v);}
    $response=rest_do_request($request);
    if($response->get_status()!==200){throw new RuntimeException($path.': '.json_encode($response->get_data()));}
    return ['rows'=>$response->get_data(),'headers'=>$response->get_headers()];
}
$names=['c4-a','c4-aa','c4-z','c4-secret','c4-page'];$terms=[];
foreach(['category','post_tag'] as $kind){
    foreach($names as $name){
        $slug='term-'.bin2hex($name);$term=get_term_by('slug',$slug,$kind);
        if(!$term){$insert=wp_insert_term($name,$kind,['slug'=>$slug]);if(is_wp_error($insert)){throw new RuntimeException('Cannot seed terms');}$term=get_term($insert['term_id'],$kind);}
        $terms[$kind][$name]=(int)$term->term_id;
    }
}
$fixtures=[
 ['slug'=>'c4-one','status'=>'publish','kind'=>'post','categories'=>['c4-a','c4-aa','c4-z'],'tags'=>['c4-a']],
 ['slug'=>'c4-two','status'=>'publish','kind'=>'post','categories'=>['c4-a','c4-aa'],'tags'=>['c4-a','c4-aa']],
 ['slug'=>'c4-three','status'=>'publish','kind'=>'post','categories'=>['c4-a'],'tags'=>['c4-a','c4-aa','c4-z']],
 ['slug'=>'c4-draft','status'=>'draft','kind'=>'post','categories'=>['c4-secret'],'tags'=>['c4-secret']],
 ['slug'=>'c4-page','status'=>'publish','kind'=>'page','categories'=>['c4-page'],'tags'=>['c4-page']],
];
foreach($fixtures as &$f){
 $id=wp_insert_post(['post_title'=>$f['slug'],'post_name'=>$f['slug'],'post_status'=>$f['status'],'post_type'=>$f['kind'],'post_content'=>'<p>Body</p>'],true);
 if(is_wp_error($id)){throw new RuntimeException('Cannot seed articles');}$f['id']=(int)$id;
 foreach(['categories'=>'category','tags'=>'post_tag'] as $plural=>$kind){wp_set_object_terms($id,array_map(fn($n)=>$terms[$kind][$n],$f[$plural]),$kind);}
}
unset($f);wp_set_current_user(0);
$out=['fixtures'=>$fixtures,'ids'=>$terms,'metadata'=>[],'details'=>[],'queries'=>[],'relations'=>[],'search'=>[]];
foreach(['view','embed'] as $context){
 foreach(['category','post_tag'] as $kind){$out['metadata'][$context][$kind]=c4_request('/wp/v2/taxonomies/'.$kind,['context'=>$context])['rows'];}
}
foreach(['categories','tags','taxonomies/category'] as $route){$out['options'][$route]=c4_request('/wp/v2/'.$route,[],'OPTIONS')['rows'];}
$public=['c4-a','c4-aa','c4-z'];
foreach(['categories'=>'category','tags'=>'post_tag'] as $plural=>$kind){
 foreach(['view','embed'] as $context){
  foreach($public as $name){$out['details'][$plural][$context][$name]=c4_request('/wp/v2/'.$plural.'/'.$terms[$kind][$name],['context'=>$context])['rows'];}
 }
 $probes=[[],
  ['search'=>'C4-AA'],
  ['search'=>'secret'],
  ['search'=>'%'],
  ['slug'=>['term-'.bin2hex('c4-z'),'term-'.bin2hex('c4-a')],'orderby'=>'include_slugs'],
  ['include_names'=>['c4-z','c4-a'],'orderby'=>'include','order'=>'desc'],
  ['include_names'=>['c4-z','c4-a'],'orderby'=>'include','order'=>'asc'],
  ['slug'=>['term-'.bin2hex('c4-z'),'term-'.bin2hex('c4-a')],'orderby'=>'include_slugs','order'=>'desc'],
  ['exclude_names'=>['c4-a']],
  ['include_names'=>['c4-z','c4-a'],'exclude_names'=>['c4-a']],
  ['post'=>$fixtures[0]['id']],
  ['post'=>$fixtures[2]['id']],
  ['orderby'=>'name','order'=>'desc'],
  ['orderby'=>'slug'],
  ['orderby'=>'count','order'=>'desc'],
  ['per_page'=>1,'page'=>2],
  ['per_page'=>1,'offset'=>2],
  ['per_page'=>1,'page'=>9],
  ['per_page'=>1,'page'=>2,'offset'=>0],
  ['per_page'=>2,'offset'=>1],
  ['per_page'=>1,'offset'=>9],
  ['context'=>'embed']];
 foreach($probes as $probe){
  $params=['slug'=>array_map(fn($n)=>'term-'.bin2hex($n),$public),'hide_empty'=>true,'per_page'=>100];
  foreach($probe as $k=>$v){
   if($k==='include_names'){$params['include']=array_map(fn($n)=>$terms[$kind][$n],$v);}
   elseif($k==='exclude_names'){$params['exclude']=array_map(fn($n)=>$terms[$kind][$n],$v);}
   else{$params[$k]=$v;}
  }
  $out['queries'][]=['plural'=>$plural,'probe'=>(object)$probe,'result'=>c4_request('/wp/v2/'.$plural,$params)];
 }
}
$relations=[['categories'=>['c4-z']],['tags'=>['c4-z']],['categories'=>['c4-z','c4-aa']],['categories_exclude'=>['c4-a']],['categories'=>['c4-z'],'tags'=>['c4-z'],'tax_relation'=>'AND'],['categories'=>['c4-z'],'tags'=>['c4-z'],'tax_relation'=>'OR'],['categories'=>['c4-z'],'categories_exclude'=>['c4-z'],'tax_relation'=>'OR'],['categories_exclude'=>['c4-z'],'tags_exclude'=>['c4-z'],'tax_relation'=>'AND'],['categories_exclude'=>['c4-z'],'tags_exclude'=>['c4-z'],'tax_relation'=>'OR']];
foreach($relations as $probe){
 $params=['include'=>array_map(fn($f)=>$f['id'],array_slice($fixtures,0,3)),'orderby'=>'id','order'=>'asc'];
 foreach($probe as $k=>$v){if($k==='tax_relation'){$params[$k]=$v;}else{$kind=str_starts_with($k,'categories')?'category':'post_tag';$params[$k]=array_map(fn($n)=>$terms[$kind][$n],$v);}}
 $out['relations'][]=['probe'=>(object)$probe,'slugs'=>array_map(fn($p)=>$p['slug'],c4_request('/wp/v2/posts',$params)['rows'])];
}
foreach(['category','post_tag'] as $kind){$out['search'][$kind]=c4_request('/wp/v2/search',['type'=>'term','subtype'=>$kind,'search'=>'c4-','include'=>array_map(fn($n)=>$terms[$kind][$n],$public),'per_page'=>100])['rows'];}
foreach(array_slice($fixtures,0,3) as $f){$out['post_embed'][$f['slug']]=c4_request('/wp/v2/posts/'.$f['id'],['context'=>'embed'])['rows'];}
foreach(['categories','tags'] as $plural){
 $request=new WP_REST_Request('GET','/wp/v2/'.$plural);$request->set_param('post',$fixtures[3]['id']);$response=rest_do_request($request);
 $out['private_post_selector'][$plural]=['status'=>$response->get_status(),'data'=>$response->get_data()];
}
foreach(['category','post_tag'] as $kind){$out['search_with_exclusion'][$kind]=c4_request('/wp/v2/search',['type'=>'term','subtype'=>$kind,'search'=>'c4-','include'=>array_map(fn($n)=>$terms[$kind][$n],$public),'exclude'=>[$terms[$kind]['c4-a']],'per_page'=>100])['rows'];}
file_put_contents($argv[2],json_encode($out,JSON_THROW_ON_ERROR|JSON_UNESCAPED_UNICODE));
