from wp_media_fixture import *
with MediaSite() as s:
    code,h,rows=s.request(ROUTE)
    assert code==200 and names(rows)==sorted(FILES,key=ident,reverse=True),(code,rows)
    assert h['X-WP-Total']=='3' and h['X-WP-TotalPages']=='1'
    assert all('digest' not in r and 'bytes' not in r for r in rows)
    assert s.request(ROUTE,'HEAD')[2] is None
    assert s.request(ROUTE,'POST',{})[0]==405
    assert s.request(ROUTE+'?per_page=101')[0]==400
    assert s.request(ROUTE+'?page=2')[0]==400
    assert s.request(ROUTE+'?private=1')[0]==400
    for f in (s.site/'public').iterdir():f.unlink()
    assert s.request(ROUTE)[2]==[]
    assert s.request(ROUTE)[1]['X-WP-Total']=='0'
