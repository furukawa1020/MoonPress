from embed_fixture import *
with NativeSite() as s:
    p=post(s);root=comment(s,p);held=comment(s,p,parent=root['id'],status='hold')
    assert 'children' not in s.request(C+'/'+str(root['id']))[2]['_links']
    child=comment(s,p,parent=root['id'])
    row=s.request(C+'/'+str(root['id'])+'?_embed=children')[2]
    assert row['_links']['children'][0]['embeddable']
    assert [r['id'] for r in row['_embedded']['children'][0]]==[child['id']]
    assert 'children' not in s.request(C+'/'+str(child['id']))[2]['_links']
