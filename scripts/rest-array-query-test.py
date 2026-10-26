from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts';ids=[]
    for slug in ['alpha','beta']:
        code,_,r=s.request(route,'POST',dict(title=slug,slug=slug,status='publish'),'author')
        assert code==201;ids.append(str(r['id']))
    scalar=s.request(route+'?include='+','.join(ids)+'&orderby=include')[2]
    for query in ['include[]='+ids[0]+'&include[]='+ids[1], 'include%5B0%5D='+ids[0]+'&include%5B1%5D='+ids[1]]:
        assert s.request(route+'?'+query+'&orderby=include')[2]==scalar
    assert [r['slug'] for r in s.request(route+'?slug[]=beta&slug[]=alpha&orderby=include_slugs')[2]]==['beta','alpha']
    assert s.request(route+'?search=alpha&search_columns[]=post_title')[2][0]['slug']=='alpha'
    assert set(s.request(route+'?_fields[]=id&_fields[]=title.rendered')[2][0])=={'id','title'}
    for query in ['include=1&include[]=2','include[]=1&include=2','include[1]=1','include[0]=1&include[0]=2','include[x]=1','include[][]=1','include[]=','context[]=view','include=1&include=2']:
        assert s.request(route+'?'+query)[0]==400,query
print('REST bracket arrays: append/indexed/encoded forms, ordered selection, nested field projection and ambiguity rejection passed.')
