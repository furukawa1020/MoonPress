"""Compare related-resource traversal with the actual pinned WordPress core."""
import json,pathlib,subprocess,sys,urllib.parse
sys.path.insert(0,str(pathlib.Path('scripts').resolve()))
from embed_fixture import *
wordpress,work=map(pathlib.Path,sys.argv[1:]);output=work/'c9-embed-core.json'
subprocess.run(['php','benchmarks/wordpress/embed-oracle.php',wordpress,output],check=True)
core=json.loads(output.read_text());failures=[];privacy=0
with NativeSite() as s:
    posts={'post':post(s,title='c9-post',moonpress_categories=['c9-category'],moonpress_tags=['c9-tag']),
           'page':post(s,title='c9-page',kind='pages',role='editor')}
    comments={}
    for name,parent,role,status in [('root',None,'subscriber','approved'),('child','root','author','approved'),('held','root','subscriber','hold')]:
        code,h,row=s.request('/wp-json/moonpress/v1/comments','POST',{'post':posts['post']['id'],'parent':comments[parent]['id'] if parent else 0,'author_name':name,'content':'Text '+name},role)
        assert code==201,(code,row);comments[name]=row
        if status!='hold':set_status(s,row['id'],status)
    reverse_users={v:k for k,v in core['users'].items()}
    reverse_posts={v:k for k,v in core['posts'].items()}
    reverse_comments={v:k for k,v in core['comments'].items()}
    def identity(row,native):
        if 'taxonomy' in row:return ('term',row['taxonomy'],row['name'])
        if row.get('type')=='comment':
            mapping={v['id']:k for k,v in comments.items()} if native else reverse_comments
            return ('comment',mapping[row['id']])
        if row.get('type') in ['post','page']:
            mapping={v['id']:k for k,v in posts.items()} if native else reverse_posts
            return ('article',mapping[row['id']])
        mapping={v:k for k,v in s.ids.items()} if native else reverse_users
        return ('user',mapping[row['id']])
    def compare(ours,theirs):
        global privacy
        if isinstance(ours,list):
            assert isinstance(theirs,list) and len(ours)==len(theirs),(ours,theirs)
            for a,b in zip(ours,theirs):compare(a,b)
            return
        if 'code' in ours:
            if ours['data']['status']==404 and theirs.get('data',{}).get('status') in [401,403]:privacy+=1;return
            assert ours['code']==theirs['code'] and ours['data']['status']==theirs['data']['status'],(ours,theirs)
            return
        assert identity(ours,True)==identity(theirs,False),(ours,theirs)
        assert '_embedded' not in ours or '_embedded' in theirs,(ours,theirs)
        assert not {'roles','capabilities','username','email','password','secret'}&set(ours)
        if ours.get('type')=='comment':
            assert ('in-reply-to' in ours['_links'])==('in-reply-to' in theirs['_links'])
            assert ('children' in ours['_links'])==('children' in theirs['_links'])
            assert ('author' in ours['_links'])==('author' in theirs['_links'])
            assert ours['_links']['up'][0]['post_type']==theirs['_links']['up'][0]['post_type']=='post'
        for rel in ['author','replies','wp:term','up','in-reply-to','children']:
            if rel in ours.get('_links',{}):
                assert rel in theirs['_links'],(rel,ours,theirs)
                assert [x.get('embeddable',False) for x in ours['_links'][rel]]==[x.get('embeddable',False) for x in theirs['_links'][rel]],(rel,ours,theirs)
        a=ours.get('_embedded',{});b=theirs.get('_embedded',{})
        # Terms/pages with unsupported empty links must not manufacture data.
        assert set(a)==set(b),(a,b)
        for rel in a:compare(a[rel],b[rel])
    for probe in core['probes']:
        target=probe['target'];actor=None if probe['actor']=='anonymous' else probe['actor'];selector=probe['selector']
        if target in posts:url='/wp-json/wp/v2/'+('pages' if target=='page' else 'posts')+'/'+str(posts[target]['id'])
        else:url=C+'/'+str(comments['anonymous' if target=='anonymous-comment' else target]['id'])
        if selector is not None:url+='?'+urllib.parse.urlencode({'_embed':selector})
        code,h,row=s.request(url,role=actor);expected=probe['result']
        try:
            assert code==expected['code'],(code,expected['code'])
            compare(row,expected['data'])
        except (AssertionError,KeyError,TypeError) as e:failures.append((probe['actor'],target,selector,str(e)))
assert not failures,json.dumps(failures,indent=2)
print(f'Actual WordPress core embedding: {len(core["probes"])} probes passed; {privacy} explicit native 404 privacy boundaries. Articles, pages, terms, comments, authors, empty/error slots and selectors checked.')
