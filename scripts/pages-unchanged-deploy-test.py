"""Unchanged publication verifies live bytes without requesting another build."""
import os
import pathlib
import shutil
import subprocess
from pages_preview_fixture import source, script
from pages_verification_fixture import PublicFixture

with source() as root, PublicFixture() as public:
    bundle = root / 'bundle'
    script('prepare-pages.sh', root / 'public', bundle, root / 'site')
    previous = root / 'previous'
    shutil.copytree(bundle, previous)
    for path in bundle.iterdir():
        shutil.copyfile(path, public.served / path.name)
    tools = root / 'bin'
    tools.mkdir()
    calls = root / 'calls'
    (tools / 'git').write_text('''#!/usr/bin/env python3
import os,pathlib,shutil,sys
a=sys.argv[1:];work=pathlib.Path(a[1]);a=a[2:]
previous=pathlib.Path(os.environ['PAGES_PREVIOUS'])
def inventory(p):return {f.name:f.read_bytes() for f in p.iterdir() if f.is_file()}
if a[0]=='checkout':shutil.copytree(previous,work,dirs_exist_ok=True)
elif a[0]=='rm':
 for p in work.iterdir():p.unlink()
elif a[0]=='diff':sys.exit(inventory(previous)!=inventory(work))
elif a[0]=='rev-parse':print('a'*40)
elif 'push' in a:
 with open(os.environ['PAGES_CALLS'],'a') as f:f.write('push\\n')
''')
    (tools / 'gh').write_text('''#!/usr/bin/env python3
import json,os,sys
a=sys.argv[1:]
if a==['api','repos/example/moonpress/pages']:
 print(json.dumps({'source':{'branch':'gh-pages','path':'/'},'html_url':os.environ['PAGES_URL']}))
elif 'POST' in a:
 with open(os.environ['PAGES_CALLS'],'a') as f:f.write('build\\n')
 print('{}')
else:print(json.dumps({'status':'built','commit':'a'*40}))
''')
    # Bound the deliberately stale-public case without waiting ten minutes.
    (tools / 'timeout').write_text('''#!/usr/bin/env bash
if [[ "$1" == 600 ]]; then shift; exec /usr/bin/timeout 2 "$@"; fi
exec /usr/bin/timeout "$@"
''')
    for path in tools.iterdir():
        path.chmod(0o755)
    env = dict(os.environ, PATH=str(tools) + ':' + os.environ['PATH'],
               GITHUB_REPOSITORY='example/moonpress', GITHUB_SHA='fixture',
               GH_TOKEN='fixture', PAGES_URL=public.url,
               PAGES_PREVIOUS=str(previous), PAGES_CALLS=str(calls))
    def deploy():
        return subprocess.run(['bash','scripts/deploy-pages.sh',str(root/'public'),str(root/'site')],
                              env=env,capture_output=True,text=True,timeout=15)
    result = deploy()
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert not calls.exists() and 'Verified 7 public artifacts' in result.stdout
    (previous / 'index.html').write_text('older deployment')
    result = deploy()
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert calls.read_text().splitlines() == ['push', 'build']
    shutil.copyfile(bundle / 'index.html', previous / 'index.html')
    calls.unlink()
    (public.served / 'index.html').write_text('stale CDN content')
    result = deploy()
    assert result.returncode != 0 and 'Published:' not in result.stdout
    assert not calls.exists()
print('Unchanged publication verifies every public artifact; changed bytes request a build; stale public bytes fail closed.')
