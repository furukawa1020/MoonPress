from user_read_fixture import *
with NativeSite() as s:
    for role in s.ids:
        for context in ['view','embed','edit']:
            assert s.request(U+'/me?context='+context,role=role)[2]==s.request(U+'/'+str(s.ids[role])+'?context='+context,role=role)[2]
    assert s.request(U+'/me')[0]==401
    assert s.request(U+'/me','HEAD',role='subscriber')[2] is None
    assert s.request(U+'/me?_fields=id',role='subscriber')[2]=={'id':s.ids['subscriber']}
