from user_read_fixture import *
with NativeSite() as s:
    url=U+'/'+str(s.ids['subscriber'])
    assert s.request(url)[0]==404
    assert s.request(url,role='subscriber')[2]['id']==s.ids['subscriber']
    assert s.request(url+'?context=embed',role='subscriber')[0]==200
    assert s.request(url,role='author')[0]==404
