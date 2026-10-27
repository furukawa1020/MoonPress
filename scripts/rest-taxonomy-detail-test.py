from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/taxonomies'
    for kind in ['category','post_tag']:
        expected=s.request(route)[2][kind]
        assert s.request(route+'/'+kind)[2]==expected
        assert s.request(route+'/'+kind+'/')[2]==expected
        assert s.request(route+'/'+kind+'?_fields=slug')[2]=={'slug':kind}
        assert s.request(route+'/'+kind,'DELETE')[0]==405
    assert s.request(route+'/private')[0]==404
    assert s.request(route+'/category?type=page')[0]==400
