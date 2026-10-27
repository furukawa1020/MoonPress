from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,h,row=s.request(route,'POST',{'title':'Transfer'},'author');assert code==201
    detail=route+'/'+str(row['id'])
    assert s.request(detail,'PATCH',{'author':s.ids['editor']},'author',h['ETag'])[0]==403
    assert s.request(detail,'PATCH',{'author':999},'administrator',h['ETag'])[0]==400
    code,new,row=s.request(detail,'PATCH',{'author':s.ids['editor']},'administrator',h['ETag'])
    assert code==200 and row['author']==s.ids['editor']
    assert s.request(detail+'?context=edit',role='author')[0]==403
    assert s.request(detail,'PATCH',{'author':s.ids['administrator']},'administrator',h['ETag'])[0]==412
    assert s.request(detail,'PATCH',{'author':s.ids['editor']},'administrator',new['ETag'])[1]['ETag']==new['ETag']
print('REST author reassignment: current ownership, active target, edit-others capability, stale guard and exact no-op passed.')
