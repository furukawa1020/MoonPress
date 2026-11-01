from user_read_fixture import *
with NativeSite() as s:
    url=U+'/'+str(s.ids['subscriber'])
    assert s.request(url,role='administrator')[0]==200
    assert s.request(url+'?context=embed',role='administrator')[2]['slug']=='subscriber'
    assert s.request(U+'/999',role='administrator')[0]==404
    assert s.request(url,role='editor')[0]==404
