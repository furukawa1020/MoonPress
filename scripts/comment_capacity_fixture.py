"""Trusted synthetic full private log; no production mutation helpers."""
import hashlib,json

def fill_events(site):
    vault=site.site/'.moonpress-comments';raw=(vault/'00000001.json').read_bytes();comment=json.loads(raw)['comment']
    for sequence in range(2,4097):
        comment['status']='approved' if comment['status']=='hold' else 'hold'
        event={'schema':1,'sequence':sequence,'previous':hashlib.sha256(raw).hexdigest(),'action':'status','comment':comment}
        raw=(json.dumps(event)+'\n').encode();target=vault/f'{sequence:08}.json';target.write_bytes(raw);target.chmod(0o600)
