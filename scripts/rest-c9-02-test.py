from embed_fixture import *
with NativeSite() as s:
    p=post(s);root=comment(s,p);child=comment(s,p,parent=root['id'])
    assert 'in-reply-to' not in s.request(C+'/'+str(root['id']))[2]['_links']
    links=s.request(C+'/'+str(child['id']))[2]['_links']
    assert links['in-reply-to'][0]['href'].endswith('/comments/'+str(root['id']))
    assert links['up'][0]['href'].endswith('/posts/'+str(p['id']))
