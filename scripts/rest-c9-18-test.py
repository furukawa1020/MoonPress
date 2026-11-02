from embed_fixture import *
with NativeSite() as s:
    p=post(s);c=comment(s,p,role='author')
    for url,methods in [(P+'/'+str(p['id']),['GET','HEAD','POST','PUT','PATCH','DELETE','OPTIONS']),(C+'/'+str(c['id']),['GET','HEAD','POST','PUT','PATCH','DELETE','OPTIONS']),('/wp-json/wp/v2/users/'+str(s.ids['author']),['GET','HEAD','OPTIONS'])]:
        link=s.request(url)[2]['_links']['self'][0]
        assert link['targetHints']['allow']==methods
    assert s.request(P+'/'+str(p['id'])+'?_embed=author')[2]['_embedded']['author'][0]['_links']['self'][0]['targetHints']['allow']==['GET','HEAD','OPTIONS']
