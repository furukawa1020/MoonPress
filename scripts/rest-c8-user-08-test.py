from user_read_fixture import *
with NativeSite() as s:
    assert s.request(U+'?roles=author')[0]==401
    assert s.request(U+'?roles=author',role='editor')[0]==403
    assert [r['slug'] for r in s.request(U+'?roles=author',role='administrator')[2]]==['author']
    assert {r['slug'] for r in s.request(U+'?roles[]=author&roles[]=subscriber',role='administrator')[2]}=={'author','subscriber'}
    assert s.request(U+'?roles=missing',role='administrator')[2]==[]
    assert s.request(U+'?roles=author&search=subscriber',role='administrator')[2]==[]
