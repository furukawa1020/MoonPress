from rest_fixture import NativeSite,run
with NativeSite() as s:
    route='/wp-json/wp/v2/users'
    assert s.request(route)[2]==[]
    for kind,role,status in [('posts','author','publish'),('pages','editor','publish'),('posts','administrator','draft')]:
        assert s.request('/wp-json/wp/v2/'+kind,'POST',{'title':role,'status':status},role)[0]==201
    code,h,rows=s.request(route)
    assert code==200 and {r['id'] for r in rows}=={s.ids['author'],s.ids['editor']} and h['X-WP-Total']=='2'
    assert all(set(r)=={'id','name','slug'} for r in rows)
    assert s.request(route,role='administrator')[2]==rows
    assert s.request(route+'?context=edit',role='administrator')[0]==400
    assert s.request(route,'HEAD')[2] is None and s.request(route,'POST',{})[0]==405
    run('access-change',s.site,s.revision,'revoke','author','-')
    assert [r['id'] for r in s.request(route)[2]]==[s.ids['editor']]
print('Public users: published post/page authors only, active identities, no private fields and fresh revocation passed.')
