from rest_fixture import NativeSite
from urllib.parse import urlsplit,parse_qs
import re
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    for i in range(3):assert s.request(route,'POST',dict(title='Paged '+str(i),status='publish'),'author')[0]==201
    code,h,rows=s.request(route+'?per_page=1&orderby=id&order=asc&_fields=id')
    assert code==200 and 'rel="next"' in h['Link'] and 'rel="prev"' not in h['Link']
    target=urlsplit(re.search(r'<([^>]+)>',h['Link'])[1]);q=parse_qs(target.query)
    assert q['page']==['2'] and q['_fields']==['id'] and q['order']==['asc']
    code,h,middle=s.request(target.path+'?'+target.query)
    assert middle[0]['id']!=rows[0]['id'] and 'rel="prev"' in h['Link'] and 'rel="next"' in h['Link']
    code,h,_=s.request(route+'?per_page=1&page=3');assert 'rel="next"' not in h['Link']
    assert 'Link' not in s.request(route)[1]
    assert 'Link' in s.request(route+'?per_page=1','HEAD')[1]
    value=s.request(route+'?per_page=1&_envelope=1')[2];assert 'Link' in value['headers']
    assert 'Link' not in s.request(route+'?page=0')[1]
print('REST page links: traversable prev/next, retained filters/projection, HEAD/envelope and boundary handling passed.')
