from user_read_fixture import *
with NativeSite() as s:
    post(s,'author');post(s,'administrator',status='draft')
    assert [r['slug'] for r in s.request(U+'?has_published_posts=true',role='administrator')[2]]==['author']
    assert len(s.request(U+'?has_published_posts=false',role='administrator')[2])==5
    assert [r['slug'] for r in s.request(U+'?has_published_posts=false')[2]]==['author']
    assert s.request(U+'?has_published_posts=bad')[0]==400
