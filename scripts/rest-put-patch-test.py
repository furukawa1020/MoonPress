from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,h,r=s.request(route,'POST',dict(title='Original',status='publish'),'author');assert code==201
    detail=route+'/'+str(r['id']);etag=h['ETag']
    for verb in ['PUT','PATCH']:
        assert s.request(detail,verb,dict(title='Forbidden'),'subscriber',etag)[0]==403
        assert s.request(detail,verb,dict(title='Missing'),'author')[0]==428
        code,h,r=s.request(detail,verb,dict(title=verb),'author',etag)
        assert code==200 and r['title']['raw']==verb and r['status']=='publish'
        assert s.request(detail,verb,dict(title='Stale'),'author',etag)[0]==412
        etag=h['ETag']
        assert s.request(route,verb,dict(title='No create'),'author')[0]==405
        assert verb in s.request(detail,'OPTIONS')[2]['methods']
    assert s.request(detail)[2]['title']['rendered']=='PATCH'
print('REST PUT/PATCH: shared update semantics, ownership, required/stale versions, preserved fields and unsupported collection writes passed.')
