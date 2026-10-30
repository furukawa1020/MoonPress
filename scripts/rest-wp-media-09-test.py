from wp_media_fixture import *
with MediaSite() as s:
    a,b=ident('alpha.png'),ident('beta.gif')
    assert names(s.request(ROUTE+'?include='+str(a))[2])==['alpha.png']
    assert set(names(s.request(ROUTE+f'?include[]={a}&include[]={b}')[2]))=={'alpha.png','beta.gif'}
    assert s.request(ROUTE+'?include=1')[2]==[]
    for value in ['-1','x','2147483648']:
        assert s.request(ROUTE+'?include='+value)[0]==400
