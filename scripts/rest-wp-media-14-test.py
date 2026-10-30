from wp_media_fixture import *
with MediaSite() as s:
    assert names(s.request(ROUTE+'?slug='+slug('alpha.png'))[2])==['alpha.png']
    assert set(names(s.request(ROUTE+'?slug[]='+slug('alpha.png')+'&slug[]='+slug('beta.gif'))[2]))=={'alpha.png','beta.gif'}
    assert s.request(ROUTE+'?slug=media-00')[2]==[]
    assert s.request(ROUTE+'?slug=bad')[0]==400
    assert s.request(ROUTE+'?slug='+slug('alpha.png')+'&search=beta')[2]==[]
