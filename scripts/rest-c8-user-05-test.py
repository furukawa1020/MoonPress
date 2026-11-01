from user_read_fixture import *
with NativeSite() as s:
    url=U+'/'+str(s.ids['subscriber'])+'?context=edit'
    assert s.request(url)[0]==401 and s.request(url,role='author')[0]==403
    for role in ['subscriber','administrator']:
        row=s.request(url,role=role)[2];assert row['username']=='subscriber' and row['roles']==['subscriber']
        assert row['capabilities']['read'] is True and row['capabilities']['subscriber'] is True
        assert not {'token_digest','secret','email','registered_date'}&set(row)
    assert 'roles' not in s.request(U+'/'+str(s.ids['subscriber']),role='subscriber')[2]
