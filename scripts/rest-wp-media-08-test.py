from wp_media_fixture import *
with MediaSite() as s:
    assert set(names(s.request(ROUTE+'?media_type=image')[2]))=={'alpha.png','beta.gif'}
    assert names(s.request(ROUTE+'?media_type=application')[2])==['fake.png']
    assert s.request(ROUTE+'?media_type=audio')[2]==[]
    assert s.request(ROUTE+'?media_type=file')[0]==400
    assert len(s.request(ROUTE+'?media_type=image&mime_type=application%2Foctet-stream')[2])==3
