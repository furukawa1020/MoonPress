from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural;rows=s.request(route)[2];a,b=[r['slug'] for r in rows]
        assert s.request(route+'?slug='+a)[2]==[rows[0]]
        assert s.request(route+'?slug[]='+b+'&slug[]='+a+'&orderby=include_slugs')[2]==rows[::-1]
        assert s.request(route+'?slug=absent')[2]==[]
        assert s.request(route+'?slug=')[0]==400
        assert s.request(route+'?orderby=include_slugs')[0]==400
        assert s.request(route+'?slug='+a+',,'+b)[0]==400
    assert s.request(posts,'POST',{'title':'Unicode','status':'publish','moonpress_tags':['月','Moon','moon']},'author')[0]==201
    rows=s.request('/wp-json/wp/v2/tags')[2];assert len({r['slug'] for r in rows})==len(rows)
