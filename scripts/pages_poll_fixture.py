import json,os,pathlib,subprocess,tempfile
COMMIT='a'*40
def poll(responses,budget=3):
    with tempfile.TemporaryDirectory() as tmp:
        root=pathlib.Path(tmp);(root/'bin').mkdir()
        (root/'responses.json').write_text(json.dumps(responses))
        command=root/'bin/gh'
        command.write_text("#!/usr/bin/env python3\nimport os,json,pathlib,sys\np=pathlib.Path(os.environ['PAGES_POLL_FIXTURE'])\na=json.loads(p.read_text());row=a.pop(0) if len(a)>1 else a[0];p.write_text(json.dumps(a))\nif row is None:sys.exit(1)\nprint(json.dumps(row))\n")
        command.chmod(0o755)
        env=dict(os.environ,PATH=str(root/'bin')+':'+os.environ['PATH'],PAGES_POLL_FIXTURE=str(root/'responses.json'))
        return subprocess.run(['bash','scripts/wait-pages-build.sh','owner/repo',COMMIT,str(budget)],env=env,capture_output=True,text=True,timeout=budget+5)
