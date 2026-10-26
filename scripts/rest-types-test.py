from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/types'
    code,h,types=s.request(route)
    assert code==200 and set(types)=={'post','page'}
    for kind,plural in [('post','posts'),('page','pages')]:
        assert types[kind]['slug']==kind and types[kind]['rest_base']==plural and types[kind]['rest_namespace']=='wp/v2' and types[kind]['viewable'] is True
    assert s.request(route+'/')[2]==types
    assert s.request(route+'?_fields=slug,rest_base')[2]=={k:{'slug':v['slug'],'rest_base':v['rest_base']} for k,v in types.items()}
    assert s.request(route,'HEAD')[2] is None
    assert s.request(route,'POST',{},'administrator')[0]==405
    assert s.request(route+'?unknown=1')[0]==400
    assert s.request(route,'OPTIONS')[2]['methods']==['GET','HEAD','OPTIONS']
    assert '/wp/v2/types' in s.request('/wp-json/')[2]['routes']
print('Native type discovery: supported kinds, keyed field projection, HEAD/OPTIONS and strict input passed.')
