from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,h,row=s.request(route,'POST',{'title':'Excerpt','excerpt':{'raw':'Plain & text'}},'author')
    assert code==201 and row['excerpt']['raw']=='Plain & text' and '&amp;' in row['excerpt']['rendered']
    detail=route+'/'+str(row['id'])
    code,h,row=s.request(detail,'PATCH',{'excerpt':{'raw':'New summary'}},'author',h['ETag'])
    assert code==200 and row['excerpt']['raw']=='New summary'
    for value in [{'raw':'<b>Markup</b>'},{'raw':False},{'raw':'X','rendered':'Y'}]:
        assert s.request(detail,'PATCH',{'excerpt':value},'author',h['ETag'])[0]==400
print('Raw excerpt objects: plain text create/update, escaping and unsupported markup/shape refusal passed.')
