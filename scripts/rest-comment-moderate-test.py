from rest_fixture import NativeSite
with NativeSite() as site:
    _,_,post=site.request('/wp-json/wp/v2/posts','POST',{'title':'Discussion','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments';_,h,row=site.request(route,'POST',{'post':post['id'],'content':'Text','author_name':'Reader'},'subscriber')
    detail=route+'/'+str(row['id']);body={'status':'approved'};vault=site.site/'.moonpress-comments'
    for role in ['subscriber','contributor','author']:assert site.request(detail,'POST',body,role,h['ETag'])[0]==403
    assert site.request(detail,'POST',body,'editor')[0]==428
    assert site.request(detail,'POST',body,'editor','"'+'0'*64+'"')[0]==412
    assert site.request(detail,'POST',dict(body,author=1),'editor',h['ETag'])[0]==400 and len(list(vault.iterdir()))==1
    status,new,approved=site.request(detail,'POST',body,'editor',h['ETag']);assert status==200 and approved['status']=='approved'
    assert len(site.request(route)[2])==1
    assert site.request(detail,'POST',body,'editor',new['ETag'])[1]['ETag']==new['ETag'] and len(list(vault.iterdir()))==2
    status,spam,_=site.request(detail,'POST',{'status':'spam'},'editor',new['ETag']);assert status==200 and site.request(route)[2]==[]
    site.restart();assert site.request(detail+'?context=edit',role='editor')[2]['status']=='spam'
print('Native moderation: fresh capability, missing/stale guards, immutable fields, approval/spam visibility, exact no-op and restart passed.')
