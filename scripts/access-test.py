#!/usr/bin/env python3
import json,os,pathlib,shutil,subprocess,tempfile
CLI=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
def run(*args,ok=True):
    result=subprocess.run([CLI,*map(str,args),'--json'],capture_output=True,text=True)
    assert (result.returncode==0)==ok,result.stderr
    return json.loads(result.stdout)['report'] if ok else None
for role in ['subscriber','contributor','author','editor','administrator']:
    result=run('access-role',role);assert result['role']==role and 'read' in result['capabilities']
run('access-role','superadmin',ok=False)
with tempfile.TemporaryDirectory() as temporary:
    site=pathlib.Path(temporary)/'site';run('init',site)
    assert run('access-read',site)=={'revision':'absent','users':[]}
    run('access-change',site,'absent','grant','alice','author',ok=False)
    assert not (site/'.moonpress-access').exists()
    first=run('access-change',site,'absent','grant','alice','administrator');secret=first['secret'];state=first['report']
    vault=site/'.moonpress-access'
    assert vault.stat().st_mode&0o777==0o700
    assert len(secret)==64 and all(secret not in p.read_text() for p in vault.iterdir())
    assert all(p.stat().st_mode&0o777==0o600 for p in vault.iterdir())
    def authenticate(token,expected):
        subprocess.run(['moon','test','--target','native','--filter','*native access authentication*'],check=True,env={**os.environ,'MOONPRESS_ACCESS_SITE':str(site),'MOONPRESS_ACCESS_SECRET':token,'MOONPRESS_ACCESS_EXPECTED':expected},stdout=subprocess.DEVNULL)
    authenticate(secret,'active')
    revision=state['revision'];before={p.name:p.read_bytes() for p in vault.iterdir()}
    for action,role in [('revoke','-'),('role','author')]:run('access-change',site,revision,action,'alice',role,ok=False)
    run('access-change',site,'absent','grant','other','author',ok=False)
    assert before=={p.name:p.read_bytes() for p in vault.iterdir()}
    other=run('access-change',site,revision,'grant','other','administrator');state=other['report']
    revoked=run('access-change',site,state['revision'],'revoke','alice','-');state=revoked['report'];authenticate(secret,'inactive')
    rotated=run('access-change',site,state['revision'],'rotate','alice','-');state=rotated['report'];authenticate(rotated['secret'],'active');authenticate(secret,'inactive')
    same=run('access-change',site,state['revision'],'role','alice','administrator');assert same['report']['revision']==state['revision'] and 'secret' not in same
    record=next(vault.iterdir());mode=record.stat().st_mode;record.chmod(0o644);run('access-read',site,ok=False);record.chmod(mode)
    original=record.read_bytes();record.write_bytes(original.replace(b'"schema":1',b'"schema":9'));run('access-read',site,ok=False);record.write_bytes(original)
    # Every hostile copy must reject both inspection and a version-bound mutation.
    for attack in ['symlink','hardlink','gap','oversize','bad-parent','unknown-field','invalid-transition','public-vault']:
        copy=pathlib.Path(temporary)/attack;shutil.copytree(site,copy)
        copied=copy/'.moonpress-access';entry=copied/'00000001.json'
        if attack=='symlink':
            payload=copy/'payload';entry.rename(payload);entry.symlink_to(payload)
        elif attack=='hardlink':os.link(entry,copy/'alias')
        elif attack=='gap':entry.unlink()
        elif attack=='oversize':entry.write_bytes(b'x'*4097)
        elif attack=='public-vault':copied.chmod(0o755)
        else:
            data=json.loads(entry.read_bytes())
            if attack=='bad-parent':data['previous']='0'*64
            elif attack=='unknown-field':data['unexpected']=True
            else:data['action']='rotate'
            entry.write_text(json.dumps(data))
        snapshot={p.name:p.read_bytes() for p in copied.iterdir()}
        run('access-read',copy,ok=False)
        run('access-change',copy,state['revision'],'grant','third','author',ok=False)
        assert snapshot=={p.name:p.read_bytes() for p in copied.iterdir()}
    # Owner-only vault aliases are rejected too.
    alias=pathlib.Path(temporary)/'alias-site';shutil.copytree(site,alias)
    shutil.rmtree(alias/'.moonpress-access');(alias/'.moonpress-access').symlink_to(vault,target_is_directory=True)
    run('access-read',alias,ok=False)
    (vault/'foreign').write_bytes(b'keep');run('access-read',site,ok=False);assert (vault/'foreign').read_bytes()==b'keep'
print('Access tests passed: private hashed credentials, fresh authentication, rotation/revocation, stale state, last-admin protection, no-op and corruption refusal.')
