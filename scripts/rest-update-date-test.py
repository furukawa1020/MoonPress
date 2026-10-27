from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,h,row=s.request(route,'POST',{'title':'Date update','status':'publish'},'author');assert code==201
    detail=route+'/'+str(row['id']);date='2020-01-01T02:03:04'
    code,new,row=s.request(detail,'PATCH',{'date':date},'author',h['ETag'])
    assert code==200 and row['date']==row['date_gmt']==date
    assert s.request(detail,'PATCH',{'date':date},'author',new['ETag'])[1]['ETag']==new['ETag']
    assert s.request(detail,'PATCH',{'date':date},'author',h['ETag'])[0]==412
    assert s.request(detail,'PATCH',{'date':date,'date_gmt':'2020-02-02T00:00:00'},'author',new['ETag'])[0]==400
    code,h,row=s.request(route,'POST',{'title':'Draft'},'contributor');assert code==201
    assert s.request(route+'/'+str(row['id']),'PATCH',{'date':'2099-01-01T00:00:00'},'contributor',h['ETag'])[2]['status']=='draft'
print('REST update date alias: consistent dates, no-op/stale guards, conflict refusal and unpublished contributor drafts passed.')
