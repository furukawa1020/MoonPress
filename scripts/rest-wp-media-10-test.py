from wp_media_fixture import *
with MediaSite() as s:
    a=ident('alpha.png')
    assert set(names(s.request(ROUTE+'?exclude='+str(a))[2]))=={'beta.gif','fake.png'}
    assert names(s.request(ROUTE+f'?include={a}&exclude={a}')[2])==['alpha.png']
    assert s.request(ROUTE+'?exclude=x')[0]==400
    assert s.request(ROUTE+'?exclude=1')[1]['X-WP-Total']=='3'
