from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/types'
    assert s.request(route+'?context=edit')[0]==401
    assert s.request(route+'?context=edit',role='subscriber')[0]==403
    assert set(s.request(route+'?context=edit',role='author')[2])=={'post'}
    assert set(s.request(route+'?context=edit',role='editor')[2])=={'post','page'}
    for kind in ['post','page']:
        code,_,meta=s.request(route+'/'+kind+'?context=edit',role='administrator')
        assert code==200 and meta['supports']['editor'] is True
        assert meta['capabilities']['edit_posts']=='edit_'+('posts' if kind=='post' else 'pages')
        assert 'supports' not in s.request(route+'/'+kind)[2]
    assert s.request(route+'/page?context=edit',role='author')[0]==403
    assert s.request(route+'?context=edit&_fields=slug,supports.title',role='author')[2]=={'post':{'slug':'post','supports':{'title':True}}}
print('Native type edit metadata: fresh role scope, gated capabilities, nested projection and public omission passed.')
