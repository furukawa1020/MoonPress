from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    rows=s.request(posts+'?orderby=id&order=asc')[2];one,two=rows
    category=one['categories'];shared=next(r['id'] for r in s.request('/wp-json/wp/v2/categories')[2] if r['name']=='shared')
    only=next(i for i in category if i!=shared)
    assert s.request(posts+'?categories='+str(only))[2]==[one]
    assert len(s.request(posts+'?categories='+','.join(map(str,category)))[2])==2
    assert s.request(posts+'?categories_exclude='+str(only))[2]==[two]
    assert s.request(posts+'?categories='+str(shared)+'&categories_exclude='+str(shared))[2]==[]
    assert s.request(posts+'?categories[]='+str(only)+'&tags[]='+str(two['tags'][0]))[2]==[one]
    assert s.request(posts+'?tags=2147483647')[2]==[]
    assert s.request(posts+'?categories=0')[0]==400
    assert s.request(posts+'?categories=bad&context=edit',role='author')[0]==400
    assert len(s.request(posts+'?categories='+str(shared)+'&context=edit&status=any',role='author')[2])==2
