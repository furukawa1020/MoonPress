from user_read_fixture import *
with NativeSite() as s:
    assert s.request(U+'?capabilities=upload_files')[0]==401
    assert s.request(U+'?capabilities=read',role='author')[0]==403
    assert {r['slug'] for r in s.request(U+'?capabilities=upload_files',role='administrator')[2]}=={'author','editor','administrator'}
    assert len(s.request(U+'?capabilities[]=read&capabilities[]=upload_files',role='administrator')[2])==5
    assert s.request(U+'?capabilities=unknown',role='administrator')[2]==[]
    assert len(s.request(U+'?capabilities=publish_posts&roles=subscriber',role='administrator')[2])==4
