"""Compare the active, single-role user read subset with actual WordPress."""
import pathlib,subprocess,sys,json,urllib.parse
sys.path.insert(0,str(pathlib.Path('scripts').resolve()))
from rest_fixture import NativeSite
wordpress,work=map(pathlib.Path,sys.argv[1:]);manifest=work/'c8-users-manifest.json';output=work/'c8-users-core.json'
roles=['administrator','author','contributor','subscriber','editor'];queries=[]
def case(actor='administrator',**params):
    p={'orderby':'id','order':'asc','per_page':100};p.update(params);queries.append({'actor':actor,'params':p})
for actor in ['anonymous',*roles]:
    for context in ['view','embed','edit']:case(actor,context=context)
    for extra in [{'roles':['author']},{'capabilities':['upload_files']},{'who':'authors'},{'has_published_posts':True},{'has_published_posts':False}]:case(actor,**extra)
for params in [
 {'roles':['author','subscriber']},{'roles':['missing']},{'capabilities':['read','upload_files']},{'capabilities':['unknown']},
 {'capabilities':['publish_posts'],'roles':['subscriber']},{'capabilities':['unknown'],'roles':['author']},
 {'has_published_posts':['post']},{'has_published_posts':['page']},{'has_published_posts':['post','page']},
 {'who':'authors','has_published_posts':True},{'include':['subscriber']},{'exclude':['subscriber']},{'include':['subscriber'],'exclude':['subscriber']},
 {'include':['editor','subscriber','administrator'],'orderby':'include','order':'asc'},
 {'include':['editor','subscriber','administrator'],'orderby':'include','order':'desc'},
 {'slug':['subscriber','author'],'orderby':'include_slugs','order':'asc'},
 {'slug':['subscriber','author'],'orderby':'include_slugs','order':'desc'},
 {'orderby':'name','order':'asc'},{'orderby':'name','order':'desc'},{'orderby':'slug','order':'asc'},
 {'per_page':1,'page':2,'offset':0},{'per_page':1,'page':9,'offset':2},{'per_page':2,'offset':99},{'page':99},
 {'search':'author','search_columns':['name','slug']},{'search':'$subscriber_id','search_columns':['id']},
 {'search':'missing','page':99},
]:case(**params)
manifest.write_text(json.dumps({'queries':queries}));subprocess.run(['php','benchmarks/wordpress/user-read-oracle.php',wordpress,manifest,output],check=True);core=json.loads(output.read_text());failures=[];privacy=0
with NativeSite() as s:
    for i,(owner,kind,status) in enumerate([('author','post','publish'),('editor','page','publish'),('administrator','post','draft'),('contributor','post','draft')]):
        fields={'wp_id':i+1,'title':'c8-'+owner,'slug':'c8-'+owner,'kind':kind,'author':s.ids[owner],'date':'2020-01-01','draft':status=='draft'}
        (s.site/'content'/('c8-'+owner+'.md')).write_text('---\n'+json.dumps(fields)+'\n---\nBody')
    cmap={ident:role for role,ident in core['users'].items()};U='/wp-json/wp/v2/users'
    def profile(ours,theirs,context):
        role=cmap[theirs['id']];assert ours['id']==s.ids[role] and ours['name']==theirs['name']==role
        assert ours['slug']==theirs['slug'].removeprefix('c8-')==role
        assert not {'email','registered_date','token_digest','secret','password','active'}&set(ours)
        if context=='edit':
            assert ours['username']==theirs['username'].removeprefix('c8-')==role and ours['roles']==theirs['roles']==[role]
            assert all(value is True and theirs['capabilities'].get(key) is True for key,value in ours['capabilities'].items())
        else:assert not {'roles','username','capabilities'}&set(ours)
    for probe in core['details']:
        actor=None if probe['actor']=='anonymous' else probe['actor'];target=probe['target'];context=probe['context'];code,h,row=s.request(U+'/'+str(s.ids[target])+'?context='+context,role=actor);expected=probe['result']
        # Native public view intentionally does not confirm unpublished identities.
        hide=context!='edit' and target not in ['author','editor'] and actor not in [target,'administrator']
        try:
            if hide:assert code==404 and expected['code'] in [401,403];privacy+=1
            else:
                assert code==expected['code'],(code,expected['code'])
                if code==200:profile(row,expected['data'],context)
        except (AssertionError,KeyError,TypeError) as e:failures.append(('detail',probe['actor'],target,context,str(e),row,expected))
    for probe in core['me']:
        actor=None if probe['actor']=='anonymous' else probe['actor'];code,h,row=s.request(U+'/me?context='+probe['context'],role=actor);expected=probe['result']
        try:
            assert code==expected['code'],(code,expected['code'])
            if code==200:profile(row,expected['data'],probe['context'])
        except (AssertionError,KeyError,TypeError) as e:failures.append(('me',probe['actor'],str(e),row,expected))
    for probe in core['queries']:
        params=dict(probe['query']['params']);actor=probe['query']['actor']
        if 'include' not in params and 'exclude' not in params:params['include']=list(s.ids.values())
        else:
            for key in ['include','exclude']:
                if key in params:params[key]=[s.ids[role] for role in params[key]]
        if params.get('search')=='$subscriber_id':params['search']=str(s.ids['subscriber'])
        pairs=[]
        for key,value in params.items():
            if isinstance(value,list):pairs.extend((f'{key}[{i}]',part) for i,part in enumerate(value))
            elif isinstance(value,bool):pairs.append((key,str(value).lower()))
            else:pairs.append((key,value))
        code,h,rows=s.request(U+'?'+urllib.parse.urlencode(pairs),role=None if actor=='anonymous' else actor);expected=probe['result']
        try:
            assert code==expected['code'],(code,expected['code'])
            if code==200:
                assert [r['id'] for r in rows]==[s.ids[cmap[r['id']]] for r in expected['data']]
                for key in ['X-WP-Total','X-WP-TotalPages']:assert int(h[key])==int(expected['headers'][key]),(key,h,expected['headers'])
                for row,theirs in zip(rows,expected['data']):profile(row,theirs,params.get('context','view'))
        except (AssertionError,KeyError,TypeError) as e:failures.append(('query',actor,params,str(e),rows,expected))
assert not failures,json.dumps(failures,indent=2)
print(f'Actual WordPress core users: {len(core["details"])} detail probes, {len(core["me"])} me probes and {len(core["queries"])} collection queries passed; {privacy} explicit native 404 privacy boundaries verified.')
