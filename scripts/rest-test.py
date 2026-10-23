#!/usr/bin/env python3
"""Exercise the actual native REST socket, never the owner editor."""
import base64, http.client, json, pathlib, socket, subprocess, tempfile, time
CLI=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
def run(*args,ok=True):
    result=subprocess.run([CLI,*map(str,args),'--json'],capture_output=True,text=True)
    assert (result.returncode==0)==ok,result.stderr
    return json.loads(result.stdout)['report'] if ok else None
with tempfile.TemporaryDirectory() as temporary:
    site=pathlib.Path(temporary)/'site';run('init',site)
    for source in (site/'content').glob('*.md'):source.unlink()
    def source(stem,identifier,**extra):
        metadata={'wp_id':identifier,'author':1,'title':'REST <title> '+stem,'description':'Description & text','date':'2020-01-01',**extra}
        path=site/'content'/f'{stem}.md';path.write_text('---\n'+json.dumps(metadata)+'\n---\n# Heading\n\nBody <script>secret()</script>.\n',encoding='utf-8');return path
    public=source('newer',100,date='2021-01-01');older=source('older',101)
    source('page',200,kind='page');source('draft',300,draft=True)
    source('future',400,publish_at='2099-01-01T00:00:00Z');source('unlisted',500,listed=False)
    state=run('access-change',site,'absent','grant','alice','administrator')
    secret=state['secret'];state=state['report']
    bob=run('access-change',site,state['revision'],'grant','bobby','subscriber');state=bob['report']
    def basic(login,token):return 'Basic '+base64.b64encode((login+':'+token).encode()).decode()
    token=basic('alice',secret)
    listener=socket.socket();listener.bind(('127.0.0.1',0));port=listener.getsockname()[1];listener.close()
    process=subprocess.Popen([CLI,'rest',site,str(port)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    def request(path='/wp-json/wp/v2/posts',method='GET',headers=None,body=None):
        connection=http.client.HTTPConnection('127.0.0.1',port,timeout=6)
        connection.request(method,path,body,headers or {})
        response=connection.getresponse();raw=response.read();connection.close()
        assert response.getheader('Cache-Control')=='no-store'
        assert response.getheader('X-Content-Type-Options')=='nosniff'
        assert secret.encode() not in raw and bob['secret'].encode() not in raw
        return response.status,dict(response.getheaders()),json.loads(raw) if raw else None
    try:
        for attempt in range(100):
            try:
                if request('/wp-json/')[0]==200:break
            except OSError:time.sleep(.03)
        else:raise AssertionError('REST listener unavailable')
        code,headers,posts=request();assert code==200 and [p['id'] for p in posts]==[100,101]
        assert headers['X-WP-Total']=='2' and headers['X-WP-TotalPages']=='1'
        assert '<script>' not in posts[0]['content']['rendered'] and '&lt;script&gt;' in posts[0]['content']['rendered']
        assert 'raw' not in posts[0]['content'] and posts[0]['author']==1
        assert request('/wp-json/wp/v2/posts/100')[2]==posts[0]
        projected=request('/wp-json/wp/v2/posts?_fields=id,title.rendered');assert set(projected[2][0])=={'id','title'} and set(projected[2][0]['title'])=={'rendered'}
        assert request('/wp-json/wp/v2/posts/100?_fields=title.raw')[2]=={'title':{}}
        assert request('/wp-json/wp/v2/posts/100?_fields=id..raw')[0]==400
        assert request('/wp-json/wp/v2/pages')[2][0]['id']==200
        assert request('/wp-json/wp/v2/posts?per_page=1&page=2')[2][0]['id']==101
        assert request('/wp-json/wp/v2/posts?orderby=id&order=desc')[2][0]['id']==101
        assert request('/wp-json/wp/v2/posts?slug=older')[2][0]['id']==101
        assert request('/wp-json/wp/v2/posts?include=101,100&orderby=include')[2][0]['id']==101
        assert [p['id'] for p in request('/wp-json/wp/v2/posts?exclude=100&author=1')[2]]==[101]
        assert request('/wp-json/wp/v2/posts?author_exclude=1')[2]==[]
        assert request('/wp-json/wp/v2/posts?search=older')[2][0]['id']==101
        assert request('/wp-json/wp/v2/posts?search=draft')[2]==[]
        assert request('/wp-json/wp/v2/posts?offset=1')[2][0]['id']==101
        assert request('/wp-json/wp/v2/posts?offset=0&per_page=1&page=2')[2][0]['id']==100
        assert request('/wp-json/wp/v2/posts?include=0')[0]==400
        assert request('/wp-json/wp/v2/posts?orderby=include')[0]==400
        assert request(method='HEAD')[2] is None
        assert request(method='HEAD')[1]['Content-Length']==headers['Content-Length']
        for identifier in [200,300,400,500,999]:assert request(f'/wp-json/wp/v2/posts/{identifier}')[0]==404
        for query in ['status=draft','per_page=101','page=2','page=01','page=1&page=1','_embed=true','per_page=2147483648']:
            assert request('/wp-json/wp/v2/posts?'+query)[0]==400,query
        assert request('/wp-json/wp/v2/posts/100/revisions')[0]==400
        assert request('/wp-json/wp/v2/comments')[0]==404
        assert request('/wp-json/wp/v2/users/me')[0]==401
        assert request('/wp-json/wp/v2/posts?context=edit')[0]==401
        assert request('/wp-json/wp/v2/posts?context=edit&status=draft',headers={'Authorization':token})[2][0]['id']==300
        assert request('/wp-json/wp/v2/posts?context=edit&status=any&per_page=100',headers={'Authorization':token})[1]['X-WP-Total']=='5'
        assert request('/wp-json/wp/v2/posts?context=edit&status=draft&include=0',headers={'Authorization':token})[0]==400
        me=request('/wp-json/wp/v2/users/me?context=edit',headers={'Authorization':token})
        assert me[0]==200 and me[2]['roles']==['administrator'] and me[2]['capabilities']['manage_options'] is True
        subscriber=request('/wp-json/wp/v2/users/me?context=edit',headers={'Authorization':basic('bobby',bob['secret'])})
        assert subscriber[0]==200 and subscriber[2]['capabilities']=={'read':True}
        assert 'roles' not in request('/wp-json/wp/v2/users/me',headers={'Authorization':token})[2]
        # Authentication never grants access to private content on this read-only slice.
        assert request('/wp-json/wp/v2/posts/300',headers={'Authorization':token})[0]==404
        for credential in ['Bearer '+secret,'Basic !!!=',basic('alice','0'*64),'Basic '+('A'*176)]:
            assert request(headers={'Authorization':credential})[0]==401
        assert request(headers={'Origin':'https://attacker.invalid'})[0]==400
        assert request(headers={'Host':'attacker.invalid'})[0]==400
        assert request(headers={'Cookie':'wordpress_logged_in='+secret})[0]==200
        assert request('/wp-json/wp/v2/users/me',headers={'Cookie':'wordpress_logged_in='+secret})[0]==401
        refused=request(method='POST',body='',headers={'Origin':f'http://127.0.0.1:{port}','Content-Type':'application/json'});assert refused[0]==401
        revoked=run('access-change',site,state['revision'],'revoke','bobby','-');state=revoked['report']
        assert request('/wp-json/wp/v2/users/me',headers={'Authorization':basic('bobby',bob['secret'])})[0]==401
        rotated=run('access-change',site,state['revision'],'rotate','alice','-');state=rotated['report']
        assert request('/wp-json/wp/v2/users/me',headers={'Authorization':token})[0]==401
        assert request('/wp-json/wp/v2/users/me',headers={'Authorization':basic('alice',rotated['secret'])})[0]==200
        # Stable IDs survive source additions, edits and renames. Collisions fail closed.
        source('additional',600);assert request('/wp-json/wp/v2/posts/100')[2]['id']==100
        public.rename(site/'content/renamed.md');assert request('/wp-json/wp/v2/posts/100')[2]['id']==100
        duplicate=source('collision',100);assert request()[0]==500;duplicate.unlink()
        missing=source('missing',700);missing.write_text('---\n{"title":"No ID"}\n---\nPrivate error details');assert request()[0]==500;missing.unlink()
        # Local assignment is version-bound, keeps IDs immutable, and clones clear identity.
        read=run('read',site,'older.md');run('post-identity',site,'older.md',read['digest'],'102','1',ok=False)
        run('duplicate',site,'older.md',read['digest'],'copy','Copy')
        copied=json.loads((site/'content/copy.md').read_text().split('\n---\n')[0][4:]);assert 'wp_id' not in copied and 'author' not in copied
        snapshot=run('read',site,'copy.md');assigned=run('post-identity',site,'copy.md',snapshot['digest'],'700','2')
        run('post-identity',site,'copy.md',snapshot['digest'],'700','2',ok=False)
        again=run('post-identity',site,'copy.md',assigned['digest'],'700','2');assert not again['changed']
    finally:
        process.terminate();process.wait(timeout=8)
print('REST live socket passed: public-only posts/pages, stable IDs, pagination, safe HTML, fresh identity/role/revocation, strict requests and no owner-editor exposure.')
