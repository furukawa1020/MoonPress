from rest_fixture import NativeSite
with NativeSite() as s:
    root='/wp-json/wp/v2/users'
    for role in ['editor','author','administrator']:assert s.request('/wp-json/wp/v2/posts','POST',{'title':role,'status':'publish'},role)[0]==201
    assert [r['slug'] for r in s.request(root)[2]]==['administrator','author','editor']
    assert [r['slug'] for r in s.request(root+'?orderby=id&order=desc')[2]]==['editor','author','administrator']
    code,h,rows=s.request(root+'?per_page=1&page=2')
    assert code==200 and rows[0]['slug']=='author' and h['X-WP-Total']=='3' and h['X-WP-TotalPages']=='3' and 'rel="next"' in h['Link']
    selected=[]
    for title in ['z','aa','a']:
        selected.append(str(s.request('/wp-json/wp/v2/posts','POST',{'title':title,'status':'publish'},'author')[2]['id']))
    for field in ['title','slug']:
        rows=s.request('/wp-json/wp/v2/posts?include='+','.join(selected)+'&orderby='+field+'&order=asc')[2]
        assert [r['title']['rendered'] for r in rows]==['a','aa','z']
    for q in ['page=0','page=5','per_page=101','orderby=email','order=no']:assert s.request(root+'?'+q)[0]==400
print('Public user ordering and pagination: deterministic visible scope, total headers, next links and bounds passed.')
