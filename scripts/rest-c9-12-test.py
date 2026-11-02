from embed_fixture import *
with NativeSite() as s:
    p=post(s);root=comment(s,p);child=comment(s,p,parent=root['id'])
    row=s.request(C+'/'+str(child['id'])+'?_embed=in-reply-to')[2]
    assert row['_embedded']['in-reply-to'][0]['id']==root['id']
    assert '_embedded' not in row['_embedded']['in-reply-to'][0]
    assert '_embedded' not in s.request(C+'/'+str(root['id'])+'?_embed=in-reply-to')[2]
