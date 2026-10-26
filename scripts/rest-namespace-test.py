from rest_fixture import NativeSite
with NativeSite() as s:
    root=s.request('/wp-json/')[2]
    code,h,index=s.request('/wp-json/wp/v2')
    assert code==200 and index['namespace']=='wp/v2'
    assert index['routes']=={k:v for k,v in root['routes'].items() if k.startswith('/wp/v2/')}
    assert '/wp/v2/posts' in index['routes'] and '/wp/v2/users/me' in index['routes']
    assert s.request('/wp-json/wp/v2/')[2]==index
    assert s.request('/wp-json/wp/v2?context=view')[2]==index
    assert s.request('/wp-json/wp/v2?context=edit')[0]==400
    assert s.request('/wp-json/wp/v2','HEAD')[2] is None
    assert s.request('/wp-json/wp/v2','OPTIONS')[2]['methods']==['GET','HEAD','OPTIONS']
    assert s.request('/wp-json/wp/v2','POST',{},'administrator')[0]==405
    assert s.request('/wp-json/wp/v2?unknown=1')[0]==400
print('REST namespace: discovery subset parity, trailing slash, HEAD/OPTIONS and strict unsupported operations passed.')
