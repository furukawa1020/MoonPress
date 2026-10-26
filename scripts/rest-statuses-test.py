from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/statuses'
    assert set(s.request(route)[2])=={'publish'}
    assert set(s.request(route,role='subscriber')[2])=={'publish'}
    assert set(s.request(route,role='author')[2])=={'publish','draft','future','trash'}
    code,_,rows=s.request(route+'?context=edit',role='author')
    assert code==200 and rows['draft']['date_floating'] is True and rows['draft']['protected'] is True
    assert rows['publish']['public'] is True and rows['trash']['show_in_list'] is False
    assert s.request(route+'?context=edit')[0]==401 and s.request(route+'?context=edit',role='subscriber')[0]==403
    assert s.request(route+'?context=embed')[2]=={'publish':{'name':'Published','slug':'publish'}}
    assert s.request(route+'?_fields=slug')[2]=={'publish':{'slug':'publish'}}
    assert s.request(route+'/')[2]==s.request(route)[2]
    assert s.request(route,'HEAD')[2] is None and s.request(route,'POST',{})[0]==405
    assert s.request(route,'OPTIONS')[2]['schema']['properties']['protected']['context']==['edit']
print('Native status discovery: implemented states, public/editor scopes, floating dates, schemas and projection passed.')
