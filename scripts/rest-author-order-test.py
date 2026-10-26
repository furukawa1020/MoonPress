from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts';ids={}
    for role in ['editor','author','administrator']:
        code,_,r=s.request(route,'POST',dict(title=role,status='publish'),role)
        assert code==201;ids[role]=r['id']
    asc=[ids[x] for x in ['administrator','author','editor']]
    assert [r['id'] for r in s.request(route+'?orderby=author&order=asc')[2]]==asc
    assert [r['id'] for r in s.request(route+'?orderby=author&order=desc')[2]]==asc[::-1]
    code,h,rows=s.request(route+'?orderby=author&order=asc&per_page=1&page=2')
    assert code==200 and rows[0]['id']==ids['author'] and h['X-WP-Total']=='3'
print('REST author ordering: numeric author identity, ascending/descending and pagination passed.')
