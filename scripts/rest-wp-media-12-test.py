from wp_media_fixture import *
with MediaSite() as s:
    for order in ['asc','desc']:
        assert names(s.request(ROUTE+'?orderby=title&order='+order)[2])==sorted(FILES,reverse=order=='desc')
    assert names(s.request(ROUTE+'?orderby=title&order=asc&per_page=1')[2])==['alpha.png']
    assert s.request(ROUTE+'?orderby=author')[0]==400
