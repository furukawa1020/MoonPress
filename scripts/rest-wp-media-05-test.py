from wp_media_fixture import *
with MediaSite() as s:
    url=ROUTE+'/'+str(ident('alpha.png'))
    row=s.request(url+'?context=embed')[2]
    assert row['source_url'].endswith('/alpha.png') and row['title']['rendered']=='alpha.png'
    assert 'media_type' in row and 'mime_type' in row
    assert s.request(ROUTE+'?context=embed')[0]==200
    assert s.request(url+'?context=edit',role='administrator')[0]==400
    assert s.request(ROUTE+'?context=other')[0]==400
