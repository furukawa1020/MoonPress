from user_read_fixture import *
with NativeSite() as s:
    for path in [U+'/'+str(s.ids['subscriber']),U+'/me']:
        assert s.request(path+'/',role='subscriber')[2]==s.request(path,role='subscriber')[2]
        assert s.request(path+'//',role='subscriber')[0]==404
    for suffix in ['/0','/2147483648','/1/extra','/01']:
        assert s.request(U+suffix)[0]==404
