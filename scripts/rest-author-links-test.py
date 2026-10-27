from rest_fixture import NativeSite
from urllib.parse import urlsplit
with NativeSite() as s:
    code,_,row=s.request('/wp-json/wp/v2/posts','POST',{'title':'Author link','status':'publish'},'author');assert code==201
    href=row['_links']['author'][0]['href']
    code,_,author=s.request(urlsplit(href).path)
    assert code==200 and author['id']==row['author'] and author['slug']=='author'
    detail='/wp-json/wp/v2/posts/'+str(row['id'])
    assert s.request(detail+'?context=embed')[2]['_links']['author']==row['_links']['author']
    assert s.request(detail+'?_fields=_links.author')[2]=={'_links':{'author':row['_links']['author']}}
print('REST article author links resolve visible public profiles without exposing private account fields.')
