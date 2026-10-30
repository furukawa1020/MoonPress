from wp_media_fixture import *
with MediaSite() as s:
    for query in ['mime_type=image/png,image/gif','mime_type[]=image/png&mime_type[]=image/gif','media_type=image&mime_type[0]=image/png&mime_type[1]=image/gif']:
        assert set(names(s.request(ROUTE+'?'+query)[2]))=={'alpha.png','beta.gif'}
    assert len(s.request(ROUTE+'?media_type=image,application')[2])==3
    for query in ['mime_type[1]=image/png','mime_type=image/png&mime_type[]=image/gif','media_type[]=image&media_type[]=bad','mime_type=image/png,']:
        assert s.request(ROUTE+'?'+query)[0]==400
    assert s.request(ROUTE,'OPTIONS')[2]['endpoints'][0]['args']['mime_type']['type']=='array'
