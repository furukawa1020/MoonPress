from user_read_fixture import *
with NativeSite() as s:
    rows=s.request(U,role='administrator')[2]
    assert s.request(U+'?per_page=1&page=2&offset=0',role='administrator')[2]==rows[1:2]
    assert s.request(U+'?per_page=1&page=9&offset=2',role='administrator')[2]==rows[2:3]
    code,h,empty=s.request(U+'?offset=99',role='administrator');assert code==200 and empty==[] and h['X-WP-Total']=='5'
    assert s.request(U+'?page=99',role='administrator')[2]==[]
    assert s.request(U+'?offset=-1',role='administrator')[0]==400
    assert 'rel="prev"' in h['Link']
