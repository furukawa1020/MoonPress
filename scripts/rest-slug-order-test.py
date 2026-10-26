from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    for slug in ['alpha','beta','gamma']:
        assert s.request(route,'POST',dict(title=slug,slug=slug,status='publish'),'author')[0]==201
    for order in ['asc','desc']:
        code,h,rows=s.request(route+'?slug=gamma,alpha,gamma,beta&orderby=include_slugs&order='+order)
        assert code==200 and [r['slug'] for r in rows]==['gamma','alpha','beta'] and h['X-WP-Total']=='3'
    assert [r['slug'] for r in s.request(route+'?slug=missing,beta&orderby=include_slugs')[2]]==['beta']
    assert s.request(route+'?orderby=include_slugs')[0]==400
    assert s.request(route+'?orderby=include_slugs&slug=')[0]==400
print('REST include_slugs: caller sequence, duplicates, missing slugs, order independence and required input passed.')
