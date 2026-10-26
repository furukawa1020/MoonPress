from rest_fixture import NativeSite
from urllib.parse import urlencode
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    ids=[]
    for title,content,excerpt in [('Needle','<p>body</p>','summary'),('Other','<p>Needle</p>','summary'),('Other','<p>body</p>','Needle')]:
        status,_,row=s.request(route,'POST',dict(title=title,content=content,excerpt=excerpt,status='publish'),'author')
        assert status==201;ids.append(row['id'])
    for index,col in enumerate(['post_title','post_content','post_excerpt']):
        code,h,rows=s.request(route+'?'+urlencode(dict(search='needle',search_columns=col)))
        assert code==200 and [r['id'] for r in rows]==[ids[index]] and h['X-WP-Total']=='1'
    assert {r['id'] for r in s.request(route+'?search=needle&search_columns=post_title,post_excerpt')[2]}=={ids[0],ids[2]}
    assert len(s.request(route+'?search=needle&search_columns=')[2])==3
    assert s.request(route+'?search_columns=password')[0]==400
    assert s.request(route,'OPTIONS')[2]['endpoints'][0]['args']['search_columns']['type']=='array'
print('REST search_columns: title/content/excerpt scopes, unions, defaults and invalid columns passed.')
