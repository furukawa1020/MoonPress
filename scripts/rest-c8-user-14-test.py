from user_read_fixture import *
with NativeSite() as s:
    for direction in ['asc','desc']:
        rows=s.request(U+'?slug[]=subscriber&slug[]=author&orderby=include_slugs&order='+direction,role='administrator')[2]
        assert [r['slug'] for r in rows]==['subscriber','author']
    assert s.request(U+'?orderby=include_slugs',role='administrator')[0]==400
    assert s.request(U+'?slug=missing&orderby=include_slugs',role='administrator')[2]==[]
