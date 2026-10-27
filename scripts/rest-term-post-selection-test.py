from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    items=s.request(posts+'?orderby=id&order=asc')[2];one=next(p for p in items if p['title']['rendered']=='One')
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural
        assert {r['name'] for r in s.request(route+'?post='+str(one['id']))[2]}=={'one','shared'}
        assert s.request(route+'?post=2147483647')[2]==[]
        draft=s.request(posts+'?context=edit&status=draft',role='author')[2][0]
        assert s.request(route+'?post='+str(draft['id']),role='administrator')[2]==[]
        assert s.request(route+'?hide_empty=true')[2]==s.request(route+'?hide_empty=false')[2]
        assert s.request(route+'?hide_empty=invalid')[0]==400
        assert s.request(route+'?post=0')[0]==400
    assert s.request('/wp-json/wp/v2/categories?parent=0')[0]==200
    assert s.request('/wp-json/wp/v2/categories?parent=1')[2]==[]
    assert s.request('/wp-json/wp/v2/tags?parent=0')[0]==400
