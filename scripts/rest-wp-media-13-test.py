from wp_media_fixture import *
with MediaSite() as s:
    wanted=['fake.png','alpha.png','beta.gif'];ids=','.join(str(ident(n)) for n in wanted)
    for order in ['asc','desc']:
        assert names(s.request(ROUTE+'?include='+ids+'&orderby=include&order='+order)[2])==wanted
    assert s.request(ROUTE+'?orderby=include')[0]==400
    assert names(s.request(ROUTE+'?include='+ids+'&orderby=include&per_page=1&page=2')[2])==['alpha.png']
