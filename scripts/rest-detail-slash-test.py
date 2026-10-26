from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,h,r=s.request(route,'POST',dict(title='Slash',status='publish'),'author');assert code==201
    detail=route+'/'+str(r['id'])
    assert s.request(detail+'/')[2]==s.request(detail)[2]
    assert s.request(detail+'/?context=embed')[2]==s.request(detail+'?context=embed')[2]
    assert s.request(detail+'/','OPTIONS')[2]==s.request(detail,'OPTIONS')[2]
    assert s.request(detail+'/','HEAD')[2] is None
    code,h,r=s.request(detail+'/','PATCH',dict(title='Updated'),'author',h['ETag']);assert code==200
    assert s.request(detail+'//')[0] in [400,404]
    assert s.request(detail+'/extra')[0] in [400,404]
    assert s.request(detail+'/','DELETE',role='author',etag=h['ETag'])[0]==200
    assert s.request(detail+'/')[0]==404
print('REST article trailing slash: read/update/delete/options parity and extra-segment refusal passed.')
