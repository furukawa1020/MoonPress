from wp_media_fixture import *
with MediaSite() as s:
    code,h,rows=s.request(ROUTE+'?search=ALPHA')
    assert code==200 and names(rows)==['alpha.png'] and h['X-WP-Total']=='1'
    assert s.request(ROUTE+'?search=missing')[2]==[]
    assert s.request(ROUTE+'?search='+('a'*257))[0]==400
    assert s.request(ROUTE+'/'+str(ident('alpha.png'))+'?search=alpha')[0]==400
