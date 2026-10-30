from wp_media_fixture import *
with MediaSite() as s:
    assert names(s.request(ROUTE+'?mime_type=image%2Fpng')[2])==['alpha.png']
    assert names(s.request(ROUTE+'?mime_type=application%2Foctet-stream')[2])==['fake.png']
    assert s.request(ROUTE+'?mime_type=image%2Fjpeg')[2]==[]
    assert s.request(ROUTE+'?mime_type=bad')[0]==400
    assert s.request(ROUTE+'?mime_type=image%2Fpng&search=fake')[2]==[]
