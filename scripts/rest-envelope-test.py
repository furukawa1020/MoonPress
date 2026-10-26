from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,_,created=s.request(route+'?_envelope=1','POST',dict(title='Enveloped',status='publish'),'author')
    assert code==200 and created['status']==201 and 'Location' in created['headers']
    normal=s.request(route)[2]
    code,h,value=s.request(route+'?_envelope=1&_fields=id')
    assert code==200 and value['status']==200 and value['body']==[{'id':normal[0]['id']}]
    assert value['headers']['X-WP-Total']==1 and value['headers']['X-WP-TotalPages']==1
    assert 'X-WP-Total' not in h
    code,_,err=s.request('/wp-json/absent?_envelope=1')
    assert code==200 and err['status']==404 and err['body']['code']=='rest_no_route'
    code,_,err=s.request(route+'?_envelope=1','POST',dict(title='Unauthorized'))
    assert code==200 and err['status']==401
    assert s.request(route+'?_envelope=1','HEAD')[2] is None
    code,_,err=s.request(route+'?_envelope=1',headers={'Authorization':'Basic invalid'})
    assert code==200 and err['status']==401

print('REST envelopes: original success/error statuses, data projection, pagination and Location metadata passed.')
