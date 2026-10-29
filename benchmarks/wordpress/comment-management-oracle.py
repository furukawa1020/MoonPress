"""Compare actual core edit authority, raw responses and moderated transitions."""
import sys,pathlib,subprocess,json,hashlib,html,re,urllib.parse
sys.path.insert(0,str(pathlib.Path('scripts').resolve()))
from rest_fixture import NativeSite
from comment_fixture import set_status
wordpress,work=map(pathlib.Path,sys.argv[1:]);path=work/'c6-management.json'
subprocess.run(['php','benchmarks/wordpress/comment-management-oracle.php',wordpress,path],check=True)
core=json.loads(path.read_text());failures=[];roles=['subscriber','contributor','author','editor','administrator']
def text(s):return ' '.join(html.unescape(re.sub('<[^>]*>',' ',s)).split())
with NativeSite() as s:
    wp='/wp-json/wp/v2/comments';native='/wp-json/moonpress/v1/comments'
    for i,f in enumerate(core['fixtures']):
        fields={'wp_id':i+1,'title':'Fixture '+str(i),'slug':'c6-'+str(i),'author':s.ids[f['owner']],'date':'2024-01-01','kind':f['kind'],'draft':f['status']=='draft'}
        (s.site/'content'/('c6-'+str(i)+'.md')).write_text('---\n'+json.dumps(fields)+'\n---\nBody')
    first=s.request(native,'POST',{'post':1,'content':'Original','author_name':'Reader'},'subscriber');assert first[0]==201,first
    set_status(s,1,'approved');vault=s.site/'.moonpress-comments'
    for i in range(1,len(core['fixtures'])):
        files=sorted(vault.glob('*.json'));previous=files[-1].read_bytes();record=json.loads(previous)['comment'];record.update(id=i+1,post=i+1,status='hold',content='Original',author_name='Reader')
        event={'schema':1,'sequence':len(files)+1,'previous':hashlib.sha256(previous).hexdigest(),'action':'create','comment':record}
        target=vault/f'{len(files)+1:08}.json';target.write_text(json.dumps(event)+'\n');target.chmod(0o600);set_status(s,i+1,'approved')
    cmap={identifier:i+1 for i,identifier in enumerate(core['comments'])};pmap={identifier:i+1 for i,identifier in enumerate(core['posts'])}
    def compare(code,row,expected,label):
        try:
            assert code==expected['code'],(code,expected)
            if code==200:
                theirs=expected['data']
                assert row['id']==cmap[theirs['id']] and row['post']==pmap[theirs['post']]
                assert row['author']==s.ids['subscriber'] and theirs['author']==core['users']['subscriber'] and row['parent']==theirs['parent']==0
                assert row['status']==theirs['status'] and row['author_name']==theirs['author_name']
                assert text(row['content']['rendered'])==text(theirs['content']['rendered'])
                assert row['content']['raw']==theirs['content']['raw']
                assert not {'author_email','author_ip','author_user_agent'}&set(row)
        except (AssertionError,KeyError,TypeError) as e:failures.append((label,str(e),row,expected))
    for probe in core['probes']:
        url=wp+'/'+str(probe['fixture']+1);role=None if probe['role']=='anonymous' else probe['role']
        code,headers,row=s.request(url+'?context=edit',role=role);compare(code,row,probe['read'],('read',probe['fixture'],role))
        tag=s.request(url+'?context=edit',role='editor')[1]['ETag']
        code,headers,row=s.request(url,'POST',{'content':{'raw':'Changed'},'author_name':'Changed'},role,tag);compare(code,row,probe['write'],('write',probe['fixture'],role))
    for probe in core['collections']:
        role=None if probe['role']=='anonymous' else probe['role'];code,headers,rows=s.request(wp+'?context=edit&include=1,2,3,4&orderby=id&order=asc&per_page=100',role=role)
        try:
            assert code==probe['result']['code'],(code,probe)
            if code==200:assert [r['id'] for r in rows]==[cmap[r['id']] for r in probe['result']['data']]
        except (AssertionError,KeyError,TypeError) as e:failures.append(('collection',role,str(e),probe))
    url=wp+'/1'
    for probe in core['sequence']:
        tag=s.request(url+'?context=edit',role='editor')[1]['ETag'];body=probe['body'];target=url
        if probe['verb']=='DELETE':target+='?force=false';body=None
        code,headers,row=s.request(target,probe['verb'],body,'editor',tag);compare(code,row,probe['result'],('transition',probe['verb'],probe['body']))
    for probe in core['type_order']:
        code,headers,rows=s.request(wp+'?context=edit&include=1,2,3,4&orderby=type&per_page=100&order='+probe['direction'],role='editor')
        try:assert code==200 and [r['id'] for r in rows]==[cmap[r['id']] for r in probe['result']['data']]
        except (AssertionError,KeyError,TypeError) as e:failures.append(('type_order',probe,str(e)))
assert not failures,json.dumps(failures,indent=2)
print('Actual WordPress core: 48 edit read/write permission probes, 6 edit collections, 8 update/trash/restore transitions and 2 type orders passed.')
