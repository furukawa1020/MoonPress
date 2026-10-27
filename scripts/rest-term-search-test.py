from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural
        assert [r['name'] for r in s.request(route+'?search=SHAR')[2]]==['shared']
        assert s.request(route+'?search=secret')[2]==[]
        assert s.request(route+'?search=page-only')[2]==[]
        assert s.request(route+'?search=%25')[2]==[]
        assert s.request(route+'?search='+('x'*257))[0]==400
        assert s.request(route+'?search=%00')[0]==400
    assert s.request(posts,'POST',{'title':'Escaped','status':'publish','moonpress_categories':['A & B']},'author')[0]==201
    assert s.request('/wp-json/wp/v2/categories?search=%26')[2][0]['name']=='A &amp; B'
