from user_read_fixture import *
with NativeSite() as s:
    post(s,'author');post(s,'editor',kind='pages');post(s,'administrator',status='draft')
    assert [r['slug'] for r in s.request(U+'?has_published_posts=post',role='administrator')[2]]==['author']
    assert [r['slug'] for r in s.request(U+'?has_published_posts=page')[2]]==['editor']
    assert {r['slug'] for r in s.request(U+'?has_published_posts[]=page&has_published_posts[]=post',role='administrator')[2]}=={'author','editor'}
    assert s.request(U+'?has_published_posts=attachment')[0]==400
