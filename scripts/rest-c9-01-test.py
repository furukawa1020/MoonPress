from embed_fixture import *
with NativeSite() as s:
    for kind,role in [('posts','author'),('pages','editor')]:
        p=post(s,kind=kind,role=role);row=comment(s,p)
        link=s.request(C+'/'+str(row['id']))[2]['_links']['up'][0]
        assert link['href'].endswith('/'+kind+'/'+str(p['id']))
        assert link['post_type']==('post' if kind=='posts' else 'page')
