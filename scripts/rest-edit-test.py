#!/usr/bin/env python3
"""Role/ownership matrix through the native HTTP edit surface."""
import base64, concurrent.futures, http.client, json, os, pathlib, socket, subprocess, sys, tempfile, time
CLI=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
def run(*args,ok=True,busy=False):
    result=subprocess.run([CLI,*map(str,args),'--json'],capture_output=True,text=True)
    assert (result.returncode==0)==ok,result.stderr
    if busy:assert 'busy with another MoonPress operation' in result.stderr,result.stderr
    return json.loads(result.stdout)['report'] if ok else None
oracle=json.loads(pathlib.Path(sys.argv[1]).read_text()) if len(sys.argv)>1 else None
with tempfile.TemporaryDirectory() as temporary:
    root=pathlib.Path(temporary);site=root/'site';run('init',site)
    for path in (site/'content').glob('*.md'):path.unlink()
    run('history-enable',site)
    roles=['administrator','subscriber','contributor','author','editor'];tokens={};revision='absent';cases=[]
    for user,role in enumerate(roles,1):
        change=run('access-change',site,revision,'grant','user'+str(user),role);revision=change['report']['revision']
        tokens[role]='Basic '+base64.b64encode(('user'+str(user)+':'+change['secret']).encode()).decode()
        for kind in ['post','page']:
            for published in [False,True]:
                for own in [True,False]:
                    identifier=1000+len(cases);path=site/'content'/f'article-{identifier}.md'
                    fields={'wp_id':identifier,'author':user if own else 100,'kind':kind,'draft':not published,'title':'Original '+str(identifier),'date':'2020-01-01'}
                    path.write_text('---\n'+json.dumps(fields)+'\n---\n# Heading\n\n**Rich** original body.\n')
                    allowed=role in ['administrator','editor'] or (own and kind=='post' and (role=='author' or (role=='contributor' and not published)))
                    cases.append(dict(id=identifier,role=role,kind=kind,published=published,own=own,allowed=allowed,path=path))
    if oracle is not None:
        assert len(oracle)==len(cases)
        for case,expected in zip(cases,oracle):
            assert {key:case[key] for key in ['role','kind','published','own','allowed']}==expected
    ready=root/'ready';release=root/'release';pause=root/'pause.so'
    subprocess.run(['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','tests/native/pause_rest_publish.c','-ldl','-o',pause],check=True)
    listener=socket.socket();listener.bind(('127.0.0.1',0));port=listener.getsockname()[1];listener.close()
    process=subprocess.Popen([CLI,'rest',site,str(port)],stdout=subprocess.DEVNULL,env={**os.environ,'LD_PRELOAD':str(pause),'MOONPRESS_REST_READY':str(ready),'MOONPRESS_REST_RELEASE':str(release)})
    def request(case=None,method='GET',change=None,etag=None,token=None,query='?context=edit',headers=None):
        path='/wp-json/' if case is None else '/wp-json/wp/v2/'+('pages' if case['kind']=='page' else 'posts')+'/'+str(case['id'])+query
        selected={**({'Authorization':tokens[case['role']]} if case is not None else {}),**(headers or {})}
        if token is not None:selected['Authorization']=token
        if etag is not None:selected['If-Match']=etag
        body=None if change is None else json.dumps(change)
        if method=='POST':selected.setdefault('Content-Type','application/json')
        connection=http.client.HTTPConnection('127.0.0.1',port,timeout=8);connection.request(method,path,body,selected)
        response=connection.getresponse();raw=response.read();connection.close()
        for secret in tokens.values():assert secret.encode() not in raw
        return response.status,dict(response.getheaders()),json.loads(raw) if raw else None
    try:
        for attempt in range(100):
            try:
                if request()[0]==200:break
            except OSError:time.sleep(.03)
        else:raise AssertionError('REST edit listener unavailable')
        for role in roles:
            connection=http.client.HTTPConnection('127.0.0.1',port,timeout=8)
            connection.request('GET','/wp-json/wp/v2/posts?context=edit&status=draft&per_page=100',headers={'Authorization':tokens[role]})
            response=connection.getresponse();listed=json.loads(response.read());connection.close()
            if role=='subscriber':assert response.status==403
            else:
                assert response.status==200
                permitted={c['id'] for c in cases if c['kind']=='post' and not c['published'] and (role in ['administrator','editor'] or (c['role']==role and c['own']))}
                assert {p['id'] for p in listed}==permitted
        for case in cases:
            before=case['path'].read_bytes();read=request(case)
            assert read[0]==(200 if case['allowed'] else 403),case
            if case['allowed']:
                assert read[2]['title']['raw'].startswith('Original') and 'source' not in read[2]
                etag=read[1]['ETag'];assert etag=='"'+read[2]['moonpress_revision']+'"'
                updated=request(case,'POST',{'title':'Changed '+str(case['id'])},etag)
                assert updated[0]==200 and updated[2]['title']['raw']=='Changed '+str(case['id']),updated
            else:
                assert request(case,'POST',{'title':'Unauthorized'},'"'+'0'*64+'"')[0]==403
                assert case['path'].read_bytes()==before
        author=next(c for c in cases if c['role']=='author' and c['kind']=='post' and c['own'] and c['published'])
        contributor=next(c for c in cases if c['role']=='contributor' and c['kind']=='post' and c['own'] and not c['published'])
        read=request(author);etag=read[1]['ETag'];before=author['path'].read_bytes()
        head=request(author,method='HEAD');assert head[0]==200 and head[2] is None and head[1]['ETag']==etag
        assert request(author,token='bAsIc '+tokens['author'][6:])[0]==200
        assert request(author,'POST',{'title':'Missing condition'})[0]==428
        assert request(author,'POST',{'title':'Stale'},'"'+'0'*64+'"')[0]==412
        assert request(author,'POST',{'title':'Malformed condition'},read[2]['moonpress_revision'])[0]==400
        for change in [{'author':100},{'wp_id':999},{'slug':'new'},{'kind':'page'},{'content':'<script>alert(1)</script>'},{'content':'<p><strong>Unsupported</strong></p>'},{'status':'private'},{'title':False},{'date_gmt':'2099-01-01T00:00:00Z'}]:
            assert request(author,'POST',change,etag)[0]==400,change
        assert request(author,'POST',{'title':'Bad projection'},etag,query='?context=edit&_fields=id..raw')[0]==400
        assert author['path'].read_bytes()==before
        history=sorted((site/'.moonpress-history').iterdir());versions={p.name:p.read_bytes() for p in history}
        timestamp=author['path'].stat().st_mtime_ns
        assert request(author,'POST',{},etag)[1]['ETag']==etag
        assert request(author,'POST',{'content':read[2]['content']['raw']},etag)[1]['ETag']==etag
        assert author['path'].read_bytes()==before and author['path'].stat().st_mtime_ns==timestamp
        assert versions=={p.name:p.read_bytes() for p in (site/'.moonpress-history').iterdir()}
        contrib_etag=request(contributor)[1]['ETag'];before=contributor['path'].read_bytes()
        assert request(contributor,'POST',{'status':'publish'},contrib_etag)[0]==403
        assert request(contributor,'POST',{'status':'future','date_gmt':'2099-01-01T00:00:00'},contrib_etag)[0]==403
        assert contributor['path'].read_bytes()==before
        scheduled=request(author,'POST',{'status':'future','date_gmt':'2099-01-01T00:00:00'},etag)
        assert scheduled[0]==200 and scheduled[2]['status']=='future'
        assert request(author,query='')[0]==404
        updated=request(author,'POST',{'status':'publish','content':'<p>Updated &amp; text</p>','excerpt':'Summary'},scheduled[1]['ETag'])
        assert updated[0]==200 and updated[2]['status']=='publish' and 'Updated &amp; text' in updated[2]['content']['rendered']
        assert request(author,query='')[0]==200
        assert request(author,token='Basic !!!=')[0]==401
        assert request(author,'POST',{},updated[1]['ETag'],headers={'Origin':'https://attacker.invalid'})[0]==400
        assert request(author,'POST',{},updated[1]['ETag'],headers={'Content-Type':'application/x-www-form-urlencoded'})[0]==400
        fallback=site/'content/fallback.md';fallback.write_text('---\n{"wp_id":8888,"author":4}\n---\nPlain fallback text.\n')
        fallback_case={'id':8888,'role':'author','kind':'post'}
        assert request(fallback_case,query='')[2]['title']['rendered']=='fallback'
        assert request(fallback_case)[2]['title']['raw']=='fallback'
        # Pause precisely before the actual source rename; both locks must remain held.
        (root/'arm').touch()
        # The preload hook is armed by an explicit marker adjacent to ready.
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            pending=executor.submit(request,author,'POST',{'title':'Locked publication'},updated[1]['ETag'])
            for attempt in range(150):
                if ready.exists():break
                time.sleep(.01)
            else:raise AssertionError('Publication pause not reached')
            current=revision
            run('access-change',site,current,'revoke','user4','-',ok=False,busy=True)
            snapshot=run('read',site,author['path'].name)
            replacement=root/'replacement';replacement.write_bytes(author['path'].read_bytes())
            run('save',site,author['path'].name,snapshot['digest'],replacement,ok=False,busy=True)
            release.touch();assert pending.result()[0]==200
        revoked=run('access-change',site,revision,'revoke','user4','-');revision=revoked['report']['revision']
        assert request(author)[0]==401 and request(author,'POST',{},'"'+'0'*64+'"')[0]==401
        assert (site/'.moonpress-history').is_dir() and len(list((site/'.moonpress-history').iterdir()))>=len(versions)
    finally:
        release.touch();process.terminate();process.wait(timeout=8)
print('REST edits passed: all five roles x ownership/type/status, exact no-op, preconditions, publication, strict fields, history, revocation and access/content locks held through publication.')
