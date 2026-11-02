from embed_fixture import *
with NativeSite() as s:
    p=post(s);c=comment(s,p,role='author')
    for url,methods in [(P+'/'+str(p['id']),['GET','HEAD','POST','PUT','PATCH','DELETE','OPTIONS']),(C+'/'+str(c['id']),['GET','HEAD','POST','PUT','PATCH','DELETE','OPTIONS']),('/wp-json/wp/v2/users/'+str(s.ids['author']),['GET','HEAD','OPTIONS'])]:
        link=s.request(url)[2]['_links']['self'][0]
        assert link['targetHints']['allow']==methods
    assert s.request(P+'/'+str(p['id'])+'?_embed=author')[2]['_embedded']['author'][0]['_links']['self'][0]['targetHints']['allow']==['GET','HEAD','OPTIONS']

from wp_media_fixture import MediaSite
with MediaSite() as s:
    p=post(s,moonpress_categories=['Category'],moonpress_tags=['Tag'])
    for route in ['/wp-json/wp/v2/categories','/wp-json/wp/v2/tags','/wp-json/wp/v2/media']:
        code,h,rows=s.request(route);assert code==200 and rows
        for row in rows:
            assert row['_links']['self'][0]['targetHints']['allow']==['GET','HEAD','OPTIONS']
            detail=s.request(route+'/'+str(row['id']))[2]
            assert detail['_links']['self'][0]['targetHints']['allow']==['GET','HEAD','OPTIONS']
    slots=s.request(P+'/'+str(p['id'])+'?_embed=wp:term')[2]['_embedded']['wp:term']
    assert all(row['_links']['self'][0]['targetHints']['allow']==['GET','HEAD','OPTIONS'] for slot in slots for row in slot)
