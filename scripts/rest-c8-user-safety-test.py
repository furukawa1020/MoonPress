"""User read boundary regressions use only disposable account logs."""
import json,pathlib
from user_read_fixture import *
with NativeSite() as s:
    url=U+'/'+str(s.ids['subscriber']);pub=post(s,'author')
    code,h,row=s.request(url+'?context=edit',role='subscriber');assert code==200
    for key in ['email','registered_date','password','secret','token_digest','active']:assert key not in row
    assert s.request(url+'?context=edit&_fields=roles',role='subscriber')[2]=={'roles':['subscriber']}
    assert s.request(url+'?context=edit&_fields=roles')[0]==401
    assert s.request(U+'/'+str(s.ids['author'])+'?_fields=roles')[2]=={}
    tag=h['ETag'];assert s.request(url+'?context=edit',role='subscriber',headers={'If-None-Match':tag})[0]==304
    assert s.request(url+'?context=edit',headers={'If-None-Match':tag})[0]==401
    env=s.request(url+'?context=edit&_envelope=1',role='subscriber')[2];assert env['status']==200 and env['body']['roles']==['subscriber']
    before={p.name:p.read_bytes() for p in (s.site/'.moonpress-access').iterdir()}
    assert s.request(url,'PATCH',{'roles':['administrator']},'subscriber')[0]==405
    assert before=={p.name:p.read_bytes() for p in (s.site/'.moonpress-access').iterdir()}
    run('access-change',s.site,s.revision,'revoke','subscriber','-')
    assert s.request(url,role='subscriber')[0]==401
    assert s.request(url,role='administrator')[0]==404
    assert s.ids['subscriber'] not in [r['id'] for r in s.request(U,role='administrator')[2]]
    log=sorted((s.site/'.moonpress-access').glob('*.json'))[-1];data=json.loads(log.read_text());data['previous']='0'*64;log.write_text(json.dumps(data)+'\n');log.chmod(0o600)
    code,h,row=s.request(U);assert code==500 and 'subscriber' not in json.dumps(row)
    assert s.request(U+'/me')[0]==401
print('User reads: credential omission, context/conditional/envelope guards, rejected writes, revocation and corrupt-chain refusal passed.')
