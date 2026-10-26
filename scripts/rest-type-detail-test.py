from rest_fixture import NativeSite
with NativeSite() as s:
    types=s.request('/wp-json/wp/v2/types')[2]
    for kind in ['post','page']:
        route='/wp-json/wp/v2/types/'+kind
        assert s.request(route)[2]==types[kind]
        assert s.request(route+'?_fields=slug')[2]=={'slug':kind}
        assert s.request(route,'HEAD')[0]==200
        assert s.request(route,'OPTIONS')[2]['schema']['properties']['viewable']['type']=='boolean'
        assert s.request(route,'DELETE')[0]==405
    assert s.request('/wp-json/wp/v2/types/attachment')[0]==404
print('Native type detail: collection parity, projection, read-only routing and absent unsupported types passed.')
