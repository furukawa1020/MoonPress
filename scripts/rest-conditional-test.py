from rest_fixture import NativeSite,run
with NativeSite() as site:
    route='/wp-json/wp/v2/posts'
    status,created,article=site.request(route,'POST',{'title':'Conditional','status':'publish','content':'<p>Original</p>'},'author')
    assert status==201
    detail=route+'/'+str(article['id'])
    for path in ['/wp-json/',route,detail,'/wp-json/wp/v2/search?search=Conditional','/wp-json/moonpress/v1/comments']:
        status,h,row=site.request(path);assert status==200 and 'ETag' in h
        for tag in [h['ETag'],'W/'+h['ETag'],'"'+'0'*64+'", '+h['ETag'],'*']:
            status,new,body=site.request(path,headers={'If-None-Match':tag})
            assert status==304 and body is None and new['ETag']==h['ETag'] and 'Content-Length' not in new
        assert site.request(path,'HEAD',headers={'If-None-Match':h['ETag']})[0]==304
        assert site.request(path,headers={'Authorization':'Basic bad','If-None-Match':h['ETag']})[0]==401
        for malformed in ['bad',h['ETag']+',',h['ETag']+', bad','*, '+h['ETag']]:
            assert site.request(path,headers={'If-None-Match':malformed})[0]==400
    full=site.request(detail)[1]['ETag'];projected=site.request(detail+'?_fields=id')[1]['ETag']
    assert full!=projected
    assert site.request(detail+'?_fields=id',headers={'If-None-Match':full})[0]==200
    assert site.request(detail+'?_fields=id',headers={'If-None-Match':projected})[0]==304
    # Existing source-version tags remain write guards, even on conditional reads.
    edit=site.request(detail+'?context=edit',role='author');assert edit[1]['ETag']==created['ETag']
    assert site.request(detail+'?context=edit',role='author',headers={'If-None-Match':created['ETag']})[0]==200
    status,updated,row=site.request(detail,'POST',{'title':'Changed'},'author',created['ETag'],headers={'If-None-Match':'*'})
    assert status==200 and site.request(detail,headers={'If-None-Match':full})[0]==200
    assert site.request(detail,'POST',{'status':'draft'},'author',updated['ETag'])[0]==200
    assert site.request(detail,headers={'If-None-Match':'*'})[0]==404
    assert site.request(route,headers={'If-None-Match':full})[0]==200
    run('access-change',site.site,site.revision,'revoke','author','-')
    assert site.request(route,role='author',headers={'If-None-Match':'*'})[0]==401
print('Native conditional reads: exact projected representations, weak/list/star matching, bodyless GET/HEAD 304, fresh visibility/auth and preserved write guards passed.')
