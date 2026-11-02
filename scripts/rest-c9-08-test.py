from embed_fixture import *
with NativeSite() as s:
    p=post(s,moonpress_categories=['Category'])
    row=s.request(P+'/'+str(p['id'])+'?_embed=wp:term')[2]
    slots=row['_embedded']['wp:term'];assert slots[0][0]['name']=='Category' and slots[1]==[]
    assert 'count' not in slots[0][0] and slots[0][0]['taxonomy']=='category'
    assert '_embedded' not in s.request(P+'/'+str(p['id'])+'?_embed=author')[2]['_embedded']['author'][0]
