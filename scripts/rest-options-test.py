from rest_fixture import NativeSite
with NativeSite() as site:
    before=list((site.site/'content').iterdir())
    for path,verbs in [('/wp-json/wp/v2/posts',['GET','HEAD','POST','OPTIONS']),('/wp-json/wp/v2/pages/123',['GET','HEAD','POST','DELETE','OPTIONS']),('/wp-json/wp/v2/users/me',['GET','HEAD','OPTIONS'])]:
        status,headers,value=site.request(path,'OPTIONS')
        assert status==200 and value['methods']==verbs and headers['Allow']==', '.join(verbs)
        assert [e['methods'][0] for e in value['endpoints']]==verbs
    status,headers,value=site.request('/wp-json/wp/v2/posts','OPTIONS')
    assert value['schema']['properties']['id']=={'type':'integer','readonly':True}
    assert value['schema']['properties']['content']['properties']['raw']['context']==['edit']
    assert value['moonpress']['subset'] and not value['moonpress']['permanent_delete']
    assert site.request('/wp-json/wp/v2/posts?context=edit','OPTIONS')[0]==400
    assert site.request('/wp-json/wp/v2/posts','OPTIONS',data={})[0]==400
    assert site.request('/wp-json/wp/v2/posts','OPTIONS',headers={'Origin':'https://evil.example'})[0]==400
    assert site.request('/wp-json/wp/v2/posts','OPTIONS',headers={'Authorization':'Basic invalid'})[0]==401
    assert site.request('/wp-json/wp/v2/posts/no-id','OPTIONS')[0]==404
    assert site.request('/wp-json/wp/v2/unknown','OPTIONS')[0]==404
    assert list((site.site/'content').iterdir())==before
print('REST OPTIONS: implemented methods, honest subset schema, strict headers and no source mutations passed.')
