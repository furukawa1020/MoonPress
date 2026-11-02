from embed_fixture import *
with NativeSite() as s:
    p=post(s);root=comment(s,p);child=comment(s,p,parent=root['id'])
    links=s.request(C+'/'+str(child['id']))[2]['_links']
    assert all(links[rel][0]['embeddable'] for rel in ['author','up','in-reply-to'])
    assert 'embeddable' not in links['self'][0]
