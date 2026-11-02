from embed_fixture import *
with NativeSite() as s:
    p=post(s,moonpress_tags=['Tag'])
    slots=s.request(P+'/'+str(p['id'])+'?_embed=wp:term')[2]['_embedded']['wp:term']
    assert slots[0]==[] and slots[1][0]['name']=='Tag'
    assert '_embedded' not in s.request(P+'/'+str(p['id'])+'?_embed=https://api.w.org/term')[2]
    assert s.request(P+'/'+str(p['id'])+'?_embed=author,wp:term')[2]['_embedded']['author'][0]['slug']=='author'
