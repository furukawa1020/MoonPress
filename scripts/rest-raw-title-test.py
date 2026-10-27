from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,h,row=s.request(route,'POST',{'title':{'raw':'Raw <title>'}},'author')
    assert code==201 and row['title']['raw']=='Raw <title>'
    detail=route+'/'+str(row['id'])
    code,h,row=s.request(detail,'PATCH',{'title':{'raw':'Changed'}},'author',h['ETag'])
    assert code==200 and row['title']['raw']=='Changed'
    assert s.request(detail,'PATCH',{'title':{'raw':'Changed'}},'author',h['ETag'])[1]['ETag']==h['ETag']
    for value in [{'rendered':'No raw'},{'raw':False},{'raw':'X','unknown':1},[],None]:
        assert s.request(route,'POST',{'title':value},'author')[0]==400
print('Raw title input: create/update, text escaping, exact no-op and strict object shape passed.')
