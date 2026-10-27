from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural;rows=s.request(route)[2]
        assert [r['name'] for r in s.request(route+'?orderby=count&order=desc')[2]]==['shared','one']
        assert s.request(route+'?orderby=name&order=desc')[2]==rows[::-1]
        assert [r['id'] for r in s.request(route+'?orderby=id')[2]]==sorted(r['id'] for r in rows)
        ids=[r['id'] for r in rows[::-1]]
        assert s.request(route+'?include='+','.join(map(str,ids))+'&orderby=include&order=desc')[2]==rows
        assert s.request(route+'?include='+','.join(map(str,ids))+'&orderby=include&order=asc')[2]==rows[::-1]
        slugs=[r['slug'] for r in rows[::-1]]
        assert s.request(route+'?slug='+','.join(slugs)+'&orderby=include_slugs&order=desc')[2]==rows
        assert s.request(route+'?orderby=include')[0]==400
        assert s.request(route+'?orderby=private')[0]==400
        assert s.request(route+'?order=sideways')[0]==400
    assert s.request(posts,'POST',{'title':'Lexical','status':'publish','moonpress_tags':['a','aa','z']},'author')[0]==201
    assert [r['name'] for r in s.request('/wp-json/wp/v2/tags')[2]]==['a','aa','one','shared','z']
