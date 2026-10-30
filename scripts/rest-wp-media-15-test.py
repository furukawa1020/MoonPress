from wp_media_fixture import *
with MediaSite() as s:
    allrows=s.request(ROUTE)[2]
    assert s.request(ROUTE+'?per_page=1&page=2&offset=0')[2]==allrows[:1]
    assert s.request(ROUTE+'?per_page=1&offset=1')[2]==allrows[1:2]
    code,h,row=s.request(ROUTE+'?per_page=2&offset=1')
    assert code==200 and row==allrows[1:] and h['X-WP-Total']=='3' and h['X-WP-TotalPages']=='2'
    assert s.request(ROUTE+'?offset=3')[2]==[]
    assert s.request(ROUTE+'?per_page=1&page=9&offset=0')[0]==400
    assert s.request(ROUTE+'?offset=-1')[0]==400
