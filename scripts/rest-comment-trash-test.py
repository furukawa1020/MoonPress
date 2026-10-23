from rest_fixture import NativeSite
with NativeSite() as site:
    _,_,post=site.request('/wp-json/wp/v2/posts','POST',{'title':'Discussion','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments';_,h,row=site.request(route,'POST',{'post':post['id'],'content':'Text','author_name':'Reader'},'subscriber')
    detail=route+'/'+str(row['id']);_,approved,_=site.request(detail,'POST',{'status':'approved'},'editor',h['ETag'])
    assert site.request(detail,'DELETE',role='author',etag=approved['ETag'])[0]==403
    assert site.request(detail,'DELETE',role='editor')[0]==428
    status,trash,row=site.request(detail,'DELETE',role='editor',etag=approved['ETag']);assert status==200 and row['status']=='trash'
    assert site.request(route)[2]==[] and site.request(detail)[0]==404
    assert site.request(detail,'POST',{'status':'approved'},'editor',trash['ETag'])[0]==409
    assert site.request(detail,'DELETE',role='editor',etag=trash['ETag'])[1]['ETag']==trash['ETag']
    status,held,row=site.request(detail,'POST',{'status':'hold'},'editor',trash['ETag']);assert status==200 and row['status']=='hold' and site.request(route)[2]==[]
    site.restart();assert site.request(detail+'?context=edit',role='editor')[2]['status']=='hold'
    assert site.request(detail+'?force=true','DELETE',role='editor',etag=held['ETag'])[0]==400
    assert site.request(detail,'POST',{'status':'approved'},'editor',trash['ETag'])[0]==412
print('Native comment trash: moderator-only conditional removal, hidden public state, hold-only restore, no silent reapproval or permanent purge passed.')
