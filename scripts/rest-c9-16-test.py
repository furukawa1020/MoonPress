from embed_fixture import *
with NativeSite() as s:
    for _ in range(3):post(s)
    rows=s.request(P+'?_embed=author&per_page=100')[2]
    assert len(rows)==3 and all(r['_embedded']['author'][0]['id']==s.ids['author'] for r in rows)
    assert s.request(P+'?_embed='+','.join('rel'+str(i) for i in range(17)))[0]==400
