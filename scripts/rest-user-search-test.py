from rest_fixture import NativeSite
with NativeSite() as s:
    root='/wp-json/wp/v2/users'
    for role in ['author','editor']:assert s.request('/wp-json/wp/v2/posts','POST',{'title':role,'status':'publish'},role)[0]==201
    assert [r['slug'] for r in s.request(root+'?search=AUTH')[2]]==['author']
    assert [r['slug'] for r in s.request(root+'?slug=EDITOR')[2]]==['editor']
    assert s.request(root+'?slug=subscriber',role='administrator')[2]==[]
    assert s.request(root+'?search=author&slug=editor')[2]==[]
    assert s.request(root+'?slug[]=author&slug[]=editor')[1]['X-WP-Total']=='2'
    for q in ['slug=','slug=../bad','search='+('x'*257)]:assert s.request(root+'?'+q)[0]==400
print('Public user search and slug selection: bounded native labels, normalized matching and visibility-preserving intersections passed.')
