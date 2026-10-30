from wp_media_fixture import *
with MediaSite() as s:
    for order in ['asc','desc']:
        rows=s.request(ROUTE+'?orderby=id&order='+order)[2]
        assert [r['id'] for r in rows]==sorted(map(ident,FILES),reverse=order=='desc')
    assert s.request(ROUTE+'?order=bad')[0]==400
    assert s.request(ROUTE+'?orderby=date')[0]==400
