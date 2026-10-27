"""Native collision/visibility regressions, plus optional actual WordPress oracle."""
from rest_fixture import NativeSite
import hashlib,json,pathlib,sys,urllib.parse

def query(params):
    return urllib.parse.urlencode([(k,','.join(map(str,v)) if isinstance(v,list) else str(v).lower() if isinstance(v,bool) else v) for k,v in params.items()])
def term_id(kind,name):return (int(hashlib.sha256((kind+'\n'+name).encode()).hexdigest()[:8],16)&0x7fffffff) or 1
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    # A real precomputed SHA-256-prefix collision must fail closed, never alias.
    assert term_id('category','collision-4962')==term_id('category','collision-85199')==779651567
    assert s.request(posts,'POST',{'title':'Collision','status':'publish','moonpress_categories':['collision-4962','collision-85199']},'author')[0] in (201,500)
    code,_,result=s.request('/wp-json/wp/v2/categories');assert code==500 and result['code']=='moonpress_terms_unavailable'
    assert 'collision-' not in json.dumps(result)
    # Source corruption is an unavailable store, not a partial public inventory.
    for p in (s.site/'content').glob('*.md'):p.unlink()
    p=s.site/'content/broken.md';p.write_text('---\n{"wp_id":1,"unknown":true}\n---\nBody')
    assert s.request('/wp-json/wp/v2/tags')[0]==500
print('Public terms fail closed on colliding IDs and corrupt source snapshots.')
with NativeSite() as s:
    for identifier,extra,name in [(1,{},'public'),(2,{'draft':True},'draft-only'),(3,{'listed':False},'unlisted-only'),(4,{'publish_at':'2099-01-01T00:00:00Z'},'future-only'),(5,{'kind':'page'},'page-only')]:
        fields={'wp_id':identifier,'title':name,'categories':[name],'tags':[name],**extra}
        (s.site/'content'/('guard-'+str(identifier)+'.md')).write_text('---\n'+json.dumps(fields)+'\n---\nBody')
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural;code,_,rows=s.request(route,role='administrator')
        assert code==200 and [r['name'] for r in rows]==['public'] and rows[0]['count']==1
        assert s.request(route+'?hide_empty=false')[2]==rows
        assert s.request(route+'?search=only')[2]==[]
        assert len(s.request('/wp-json/wp/v2/search?type=term&subtype='+('category' if plural=='categories' else 'post_tag'))[2])==1
    row=s.request('/wp-json/wp/v2/categories')[2][0]
    (s.site/'content/guard-1.md').unlink()
    assert s.request('/wp-json/wp/v2/categories/'+str(row['id']))[0]==404
    assert s.request('/wp-json/wp/v2/categories')[2]==[]
print('Public term inventories/search exclude draft, unlisted, future and page-only names; fresh removals are reflected.')
if len(sys.argv)==1:raise SystemExit(0)
core=json.loads(pathlib.Path(sys.argv[1]).read_text())
with NativeSite() as s:
    for f in core['fixtures']:
        fields={'wp_id':f['id'],'title':f['slug'],'slug':f['slug'],'type':f['kind'],'draft':f['status']=='draft','categories':f['categories'],'tags':f['tags']}
        # Native Document's type key is kind, matching the established WXR fixture.
        fields['kind']=fields.pop('type')
        (s.site/'content'/ (f['slug']+'.md')).write_text('---\n'+json.dumps(fields)+'\n---\nBody\n')
    native={}
    failures=[]
    for plural,kind in [('categories','category'),('tags','post_tag')]:
        route='/wp-json/wp/v2/'+plural;code,_,rows=s.request(route);assert code==200,(code,rows)
        assert {r['name'] for r in rows}=={'c4-a','c4-aa','c4-z'}
        native[plural]={r['name']:r['id'] for r in rows}
        for context in ['view','embed']:
            for row in rows:
                ours=s.request(route+'/'+str(row['id'])+'?context='+context)[2]
                theirs=core['details'][plural][context][row['name']]
                assert set(ours)-{'_links'}<=set(theirs),(ours,theirs)
                for k in ['name','slug','taxonomy']+(['count','description'] if context=='view' else []):assert ours[k]==theirs[k],(k,ours,theirs)
                if plural=='categories' and context=='view':assert ours['parent']==theirs['parent']==0
                assert ours['id']==native[plural][row['name']] and theirs['id']==core['ids'][kind][row['name']]
                assert ours['link'].endswith('.html') and theirs['link'].startswith('http')
    for context in ['view','embed']:
        for kind in ['category','post_tag']:
            code,_,ours=s.request('/wp-json/wp/v2/taxonomies/'+kind+'?context='+context);assert code==200
            theirs=core['metadata'][context][kind]
            assert set(ours)<=set(theirs)
            for k in ours:assert ours[k]==theirs[k],(k,ours,theirs)
    for route,theirs in core['options'].items():
        options=s.request('/wp-json/wp/v2/'+route,'OPTIONS')[2]
        if route in ['categories','tags']:
            ours_args=next(e['args'] for e in options['endpoints'] if 'GET' in e['methods'])
            core_args=next(e['args'] for e in theirs['endpoints'] if 'GET' in e['methods'])
            assert ('offset' in ours_args)==('offset' in core_args),(route,ours_args,core_args)
        for name,prop in options['schema']['properties'].items():
            actual=theirs['schema']['properties'][name]
            assert prop['type']==actual['type'],(route,name,prop,actual)
            assert set(prop['context'])<=set(actual['context']),(route,name,prop,actual)
            if name in ['id','count']:assert prop['readonly']==actual['readonly']==True
    # Private selector response status is an explicit public-only subset difference.
    draft=next(f for f in core['fixtures'] if f['status']=='draft')
    for plural,probe in core['private_post_selector'].items():
        assert probe['status']==401 and probe['data']['code']=='rest_forbidden_context'
        code,_,rows=s.request('/wp-json/wp/v2/'+plural+'?post='+str(draft['id']))
        assert code==200 and rows==[]
    for p in core['queries']:
        try:
            plural=p['plural'];params={'slug':['term-'+n.encode().hex() for n in native[plural]],'hide_empty':True,'per_page':100}
            for k,v in p['probe'].items():
                if k=='include_names':params['include']=[native[plural][n] for n in v]
                elif k=='exclude_names':params['exclude']=[native[plural][n] for n in v]
                else:params[k]=v
            code,h,rows=s.request('/wp-json/wp/v2/'+plural+'?'+query(params));assert code==200,(p,code,rows)
            assert [r['name'] for r in rows]==[r['name'] for r in p['result']['rows']],(p,rows)
            assert int(h['X-WP-Total'])==int(p['result']['headers']['X-WP-Total'])
            assert int(h['X-WP-TotalPages'])==int(p['result']['headers']['X-WP-TotalPages'])
        except AssertionError as error:
            failures.append(repr((p['plural'],p['probe'],str(error))))
    for p in core['relations']:
        try:
            params={'include':[f['id'] for f in core['fixtures'][:3]],'orderby':'id','order':'asc'}
            for k,v in p['probe'].items():
                if k=='tax_relation':params[k]=v
                else:
                    plural='categories' if k.startswith('categories') else 'tags';params[k]=[native[plural][n] for n in v]
            code,_,rows=s.request('/wp-json/wp/v2/posts?'+query(params));assert code==200,(code,rows)
            assert [r['slug'] for r in rows]==p['slugs'],(p,rows)
        except AssertionError as error:
            failures.append(repr((p['probe'],str(error))))
    for kind,plural in [('category','categories'),('post_tag','tags')]:
        try:
            params={'type':'term','subtype':kind,'search':'c4-','include':list(native[plural].values()),'per_page':100}
            code,_,rows=s.request('/wp-json/wp/v2/search?'+query(params));assert code==200
            theirs=core['search'][kind]
            assert {r['title'] for r in rows}=={r['title'] for r in theirs}, ('titles',rows,theirs)
            assert all(r['type']==kind and 'subtype' not in r for r in rows+theirs), ('shape',rows,theirs)
            params['exclude']=[native[plural]['c4-a']]
            code,_,rows=s.request('/wp-json/wp/v2/search?'+query(params));assert code==200
            assert {r['title'] for r in rows}=={r['title'] for r in core['search_with_exclusion'][kind]}==set(native[plural])
        except AssertionError as error:
            failures.append(repr((kind,str(error))))
    # Relationship IDs use independently allocated stores, but identify the same names.
    for f in core['fixtures'][:3]:
        row=s.request('/wp-json/wp/v2/posts/'+str(f['id']))[2]
        embed=s.request('/wp-json/wp/v2/posts/'+str(f['id'])+'?context=embed')[2]
        assert 'categories' not in embed and 'tags' not in embed
        assert 'categories' not in core['post_embed'][f['slug']] and 'tags' not in core['post_embed'][f['slug']]
        for plural in ['categories','tags']:assert set(row[plural])=={native[plural][n] for n in f[plural]}
    assert not failures, '\n'.join(failures)
print('Actual WordPress core: taxonomy metadata, view/embed terms, 44 term queries, 9 taxonomy relations and public term search agree within the documented public flat subset; IDs are explicitly mapped across independent stores.')
