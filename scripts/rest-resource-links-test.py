from rest_fixture import NativeSite
from urllib.parse import urlsplit
with NativeSite() as s:
    for plural in ['posts','pages']:
        route='/wp-json/wp/v2/'+plural
        code,h,row=s.request(route,'POST',{'title':'Linked','status':'publish'},'administrator');assert code==201
        for rel in ['self','collection','about']:
            href=row['_links'][rel][0]['href'];target=urlsplit(href).path
            assert s.request(target)[0]==200,(rel,target)
        self_path=urlsplit(row['_links']['self'][0]['href']).path
        assert s.request(self_path)[2]['_links']==row['_links']
        assert s.request(self_path+'?context=embed')[2]['_links']==row['_links']
        assert s.request(self_path+'?_fields=_links.about')[2]=={'_links':{'about':row['_links']['about']}}
        assert set(row['_links'])=={'self','collection','about','author'} | ({'wp:term','curies'} if plural=='posts' else set())
print('REST article links: resolvable native self/collection/type resources, contexts and nested projection passed.')
