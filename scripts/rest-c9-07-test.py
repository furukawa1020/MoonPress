from embed_fixture import *
with NativeSite() as s:
    for kind,role in [('posts','author'),('pages','editor')]:
        p=post(s,kind=kind,role=role);url='/wp-json/wp/v2/'+kind+'/'+str(p['id'])
        row=s.request(url+'?_embed')[2]
        assert row['_embedded']['author'][0]['id']==s.ids[role]
        assert 'roles' not in row['_embedded']['author'][0] and '_embedded' not in row['_embedded']['author'][0]
        assert s.request('/wp-json/wp/v2/'+kind+'?_embed=author')[2][0]['_embedded']['author'][0]['id']==s.ids[role]
        assert '_embedded' not in s.request(url)[2]
        assert '_embedded' not in s.request(url+'?_embed=false')[2]
        for value in ['', 'true','1','0']:assert 'author' in s.request(url+'?_embed='+value)[2]['_embedded']
        assert s.request(url+'?_embed=author','HEAD')[2] is None

    row=s.request(url+'?_embed=author%09replies%0Awp%3Aterm')[2]
    assert row['_embedded']['author'][0]['id']==s.ids[role]
    assert s.request(url+'?_embed=author%01')[0]==400
