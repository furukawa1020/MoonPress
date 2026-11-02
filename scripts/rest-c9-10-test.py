from embed_fixture import *
with NativeSite() as s:
    p=post(s);root=comment(s,p);comment(s,p,status='hold')
    row=s.request(P+'/'+str(p['id'])+'?_embed=replies')[2]
    assert [r['id'] for r in row['_embedded']['replies'][0]]==[root['id']]
    assert 'post' not in row['_embedded']['replies'][0][0] and 'status' not in row['_embedded']['replies'][0][0]
    p2=post(s,title='Empty');assert '_embedded' not in s.request(P+'/'+str(p2['id'])+'?_embed=replies')[2]
