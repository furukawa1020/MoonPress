"""Independent real-core comment queries and configured moderated creation."""
import sys,pathlib,subprocess,json,urllib.parse,html,re,hashlib,datetime
sys.path.insert(0,str(pathlib.Path('scripts').resolve()))
from rest_fixture import NativeSite
from comment_fixture import set_status
wordpress,work=map(pathlib.Path,sys.argv[1:]);output=work/'c5-core.json'
subprocess.run(['php','benchmarks/wordpress/comment-oracle.php',wordpress,output],check=True)
core=json.loads(output.read_text());failures=[]
def text(s):return ' '.join(html.unescape(re.sub('<[^>]*>',' ',s)).split())
with NativeSite() as s:
    posts=[];route='/wp-json/wp/v2/comments';native='/wp-json/moonpress/v1/comments'
    for slug in ['one','two']:posts.append(s.request('/wp-json/wp/v2/posts','POST',{'title':slug,'slug':slug,'status':'publish'},'author')[2]['id'])
    ids=[]
    for i,name in enumerate(['Alpha','Z','beta','Alpha']):
        code,_,row=s.request(native,'POST',{'post':posts[1 if i==2 else 0],'parent':ids[0] if i==1 else 0,'author_name':name,'content':'Text '+str(i)},'subscriber');assert code==201,row
        ids.append(row['id']);set_status(s,row['id'],'approved')
    previous='absent'
    for path in sorted((s.site/'.moonpress-comments').glob('*.json')):
        event=json.loads(path.read_text());event['comment']['created']=str(int(datetime.datetime(2024,2,3,4,5,6,tzinfo=datetime.timezone.utc).timestamp()));event['previous']=previous
        raw=(json.dumps(event)+'\n').encode();path.write_bytes(raw);previous=hashlib.sha256(raw).hexdigest()
    cmap=dict(zip(core['ids'],ids));pmap=dict(zip(core['posts'],posts))
    for probe in core['probes']:
        q={}
        for key,value in probe['params'].items():
            mapping=pmap if key=='post' else cmap
            q[key]=[mapping.get(x,x) for x in value] if isinstance(value,list) else value
        pairs=[]
        for k,v in q.items():pairs.extend([(k+'[]',x) for x in v] if isinstance(v,list) else [(k,v)])
        code,headers,rows=s.request(route+'?'+urllib.parse.urlencode(pairs));expected=probe['result']
        try:
            assert code==expected['code'],(code,expected['code'])
            assert [r['id'] for r in rows]==[cmap[r['id']] for r in expected['rows']],([r['id'] for r in rows],[cmap[r['id']] for r in expected['rows']])
            for a,b in zip(rows,expected['rows']):
                assert a['post']==pmap[b['post']] and a['parent']==cmap.get(b['parent'],0)
                assert a['author_name']==b['author_name'] and text(a['content']['rendered'])==text(b['content']['rendered'])
            for k in ['X-WP-Total','X-WP-TotalPages']:assert str(headers[k])==str(expected['headers'][k])
        except (AssertionError,KeyError,TypeError) as e:failures.append((probe['params'],str(e)))
    code,headers,row=s.request(route,'POST',{'post':posts[0],'parent':ids[0],'content':{'raw':'<p>Pending<br>reply</p><p>Text</p>'}},'subscriber')
    try:
        expected=core['created'];assert code==expected['code']==201,(row,expected)
        assert row['status']==expected['rows']['status']=='hold' and text(row['content']['rendered'])==text(expected['rows']['content']['rendered'])
        assert row['content']['raw']=='Pending\nreply\n\nText' and row['parent']==ids[0] and expected['rows']['parent']==core['ids'][0]
        assert row['id'] not in [r['id'] for r in s.request(route)[2]]
    except (AssertionError,KeyError,TypeError) as e:failures.append(('creation',str(e)))
assert not failures,json.dumps(failures,indent=2)
print('Actual WordPress core: 25 comment query cases, reply relationships, rendered text, totals and configured moderated creation passed.')
