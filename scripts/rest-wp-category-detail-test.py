from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    route='/wp-json/wp/v2/categories'
    for row in s.request(route)[2]:
        detail=route+'/'+str(row['id'])
        assert s.request(detail)[2]==row
        assert s.request(detail+'/')[2]==row
        assert s.request(detail,'HEAD')[2] is None
        assert s.request(detail,'DELETE')[0]==405
    assert s.request(route+'/2147483647')[0]==404
    assert s.request(route+'/0')[0] in (400,404)
    for p in (s.site/'content').glob('*.md'):p.unlink()
    assert s.request(detail)[0]==404
