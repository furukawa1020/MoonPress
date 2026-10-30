from wp_media_fixture import *
with MediaSite() as s:
    row=s.request(ROUTE+'/'+str(ident('alpha.png')))[2]
    assert row['_links']['self'][0]['href'].endswith(ROUTE+'/'+str(ident('alpha.png')))
    assert row['_links']['collection'][0]['href'].endswith(ROUTE)
    code,h,rows=s.request(ROUTE+'?per_page=1&orderby=title&order=asc')
    assert 'page=2' in h['Link'] and 'orderby=title' in h['Link'] and 'rel="next"' in h['Link']
    code,h,rows=s.request(ROUTE+'?per_page=1&offset=1')
    assert 'offset=1' in h['Link'] and 'page=2' in h['Link'] and 'rel="next"' in h['Link']
    assert s.request(ROUTE+'?search=alpha')[1].get('Link') is None
