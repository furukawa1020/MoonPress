from embed_fixture import *
with NativeSite() as s:
    for kind,role in [('posts','author'),('pages','editor')]:
        p=post(s,kind=kind,role=role);row=comment(s,p)
        embedded=s.request(C+'/'+str(row['id'])+'?_embed=up')[2]['_embedded']['up'][0]
        assert embedded['id']==p['id'] and embedded['type']==('post' if kind=='posts' else 'page')
        assert 'content' not in embedded and '_embedded' not in embedded
