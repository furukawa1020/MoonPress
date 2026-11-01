from user_read_fixture import *
with NativeSite() as s:
    assert s.request(U+'?who=authors')[0]==401
    assert s.request(U+'?who=authors',role='subscriber')[0]==403
    for role in ['contributor','author','editor','administrator']:
        code,h,rows=s.request(U+'?who=authors',role=role)
        assert code==200 and {r['slug'] for r in rows}=={'administrator','author','editor','contributor'}
    assert s.request(U+'?who=any',role='administrator')[0]==400
