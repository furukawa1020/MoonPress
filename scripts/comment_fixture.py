"""Trusted disposable log fixture for testing reads before moderation HTTP exists."""
import hashlib,json

def set_status(site,identifier,status):
    vault=site.site/'.moonpress-comments';files=sorted(vault.glob('*.json'));last=files[-1].read_bytes()
    row=next(json.loads(p.read_text())['comment'] for p in reversed(files) if json.loads(p.read_text())['comment']['id']==identifier)
    row['status']=status
    event={'schema':1,'sequence':len(files)+1,'previous':hashlib.sha256(last).hexdigest(),'action':'status','comment':row}
    target=vault/f'{len(files)+1:08}.json';target.write_text(json.dumps(event)+'\n');target.chmod(0o600)
