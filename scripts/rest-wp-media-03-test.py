from wp_media_fixture import *
with MediaSite() as s:
    url=ROUTE+'/'+str(ident('alpha.png'))
    code,h,row=s.request(url)
    assert code==200 and row['id']==ident('alpha.png') and row['mime_type']=='image/png',(code,row)
    assert s.request(url+'/')[2]==row
    assert s.request(url,'HEAD')[2] is None
    assert s.request(url+'?page=1')[0]==400
    for suffix in ['/0','/2147483648','/1//','/1/other']:
        assert s.request(ROUTE+suffix)[0]==404
    assert s.request(ROUTE+'/1')[0]==404
