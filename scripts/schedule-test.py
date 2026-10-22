#!/usr/bin/env python3
import json
import pathlib
import subprocess
import tempfile
import os
import socket, http.client, urllib.parse, re

CLI = pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
def run(*args, ok=True):
    result = subprocess.run([str(CLI),*map(str,args)], capture_output=True, text=True)
    assert (result.returncode == 0) == ok, result.stderr + result.stdout
    return json.loads(result.stdout)['report'] if result.returncode == 0 and '--json' in args else result.stdout
with tempfile.TemporaryDirectory() as temporary:
    root = pathlib.Path(temporary)
    site = root/'site'
    run('init',site)
    content = site/'content/future.md'
    content.write_text('---\n'+json.dumps({'title':'FutureSecret','tags':['future-only'],'categories':['FutureCategory'],'publish_at':'9999-12-31T23:59:59Z'})+'\n---\n# FutureSecret\n',encoding='utf-8')
    run('build',site,root/'out')
    assert not (root/'out/future.html').exists()
    for path in (root/'out').iterdir():
        if path.suffix in ('.html','.xml'):
            assert 'FutureSecret' not in path.read_text(encoding='utf-8')
            assert 'FutureCategory' not in path.read_text(encoding='utf-8')
    run('build',site,root/'preview','--include-drafts')
    assert (root/'preview/future.html').exists()
    snapshot = run('read',site,'future.md','--json')
    original = content.read_bytes()
    result = run('post-schedule',site,'future.md',snapshot['digest'],'9999-12-31T23:59:59Z','--json')
    assert not result['changed'] and content.read_bytes() == original
    run('post-schedule',site,'future.md','0'*64,'','--json',ok=False)
    assert content.read_bytes() == original
    result = run('post-schedule',site,'future.md',snapshot['digest'],'1970-01-01T00:00:00Z','--json')
    run('build',site,root/'out')
    assert (root/'out/future.html').exists()
    run('post-schedule',site,'future.md',result['digest'],'9999-12-31T23:59:59Z','--json')
    run('build',site,root/'out')
    assert not (root/'out/future.html').exists()
    run('build',site,root/'clean')
    assert {p.name:p.read_bytes() for p in (root/'out').iterdir()} == {p.name:p.read_bytes() for p in (root/'clean').iterdir()}
    for _ in range(100):
        with socket.socket() as first, socket.socket() as second:
            first.bind(('127.0.0.1',0)); port=first.getsockname()[1]
            if port >= 65535: continue
            try: second.bind(('127.0.0.1',port+1))
            except OSError: continue
            break
    else: raise RuntimeError('No port pair')
    server=subprocess.Popen([str(CLI),'admin',str(site),str(port)],stdout=subprocess.PIPE)
    try:
        assert b'MoonPress admin:' in server.stdout.readline()
        def request(path, fields=None):
            connection=http.client.HTTPConnection('127.0.0.1',port,timeout=8)
            try:
                headers={} if fields is None else {'Origin':f'http://127.0.0.1:{port}','Content-Type':'application/x-www-form-urlencoded'}
                connection.request('GET' if fields is None else 'POST',path,body=None if fields is None else urllib.parse.urlencode(fields),headers=headers)
                response=connection.getresponse();return response.status,response.read().decode()
            finally: connection.close()
        status,page=request('/edit?name=future.md'); assert status==200 and 'action="/schedule"' in page
        token=re.search('name="token" value="([a-f0-9]{64})"',page)[1]
        version=run('read',site,'future.md','--json')['digest']
        original=content.read_bytes()
        fields={'token':'wrong','name':'future.md','version':version,'publish_at':'1970-01-01T00:00:00Z'}
        assert request('/schedule',fields)[0]==400 and content.read_bytes()==original
        fields['token']=token
        assert request('/schedule',fields)[0]==200
        assert json.loads(content.read_text().split('\n---\n')[0][4:])['publish_at']=='1970-01-01T00:00:00Z'
        assert request('/schedule',fields)[0]==400  # stale version
    finally:
        server.terminate();server.wait(timeout=8)
    content.write_text('---\n{"publish_at":"2030-01-01T00:00:00Z"}\n---\n# Due\n',encoding='utf-8')
    (site/'content/still-draft.md').write_text('---\n{"draft":true,"publish_at":"1970-01-01T00:00:00Z"}\n---\n# Draft\n')
    subprocess.run(['moon','test','--target','native','--filter','*one explicit clock*'],check=True,env={**os.environ,'MOONPRESS_SCHEDULE_SITE':str(site)})
print('Schedule tests passed: UTC boundary, future route/feed/archive exclusion, preview, guarded editing, shrink/clean parity and reviewed identity.')
