from rest_fixture import NativeSite
with NativeSite() as s:
    root='/wp-json/wp/v2/statuses'
    for status in ['publish','draft','future','trash']:
        route=root+'/'+status
        assert s.request(route+'?context=edit',role='author')[2]==s.request(root+'?context=edit',role='author')[2][status]
        assert s.request(route)[0]==(200 if status=='publish' else 401)
        assert s.request(route,role='subscriber')[0]==(200 if status=='publish' else 403)
        assert s.request(route+'?context=embed',role='author')[2]['slug']==status
        assert s.request(route,'OPTIONS')[0]==200
    assert s.request(root+'/pending')[0]==404
    assert s.request(root+'/private')[0]==404
    assert s.request(root+'/unknown')[2]['code']=='rest_status_invalid'
print('Native status details: list/detail parity, public/capability boundaries and unsupported states passed.')
