from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    route='/wp-json/wp/v2/search?type=term'
    code,h,rows=s.request(route)
    assert code==200 and len(rows)==4 and h['X-WP-Total']=='4'
    assert all(set(r)=={'id','title','url','type','subtype'} and r['type']=='term' for r in rows)
    assert len(s.request(route+'&subtype=category')[2])==2
    assert len(s.request(route+'&subtype[]=category&subtype[]=post_tag&search=SHARED')[2])==2
    assert s.request(route+'&search=secret')[2]==[]
    selected=rows[0]['id'];assert s.request(route+'&include='+str(selected))[2]==[rows[0]]
    assert len(s.request(route+'&exclude='+str(selected))[2])==3
    assert s.request(route+'&include='+str(selected)+'&exclude='+str(selected))[2]==[rows[0]]
    assert s.request(route+'&per_page=1&page=2')[1]['X-WP-TotalPages']=='4'
    assert 'rel="next"' in s.request(route+'&per_page=1')[1]['Link']
    assert s.request(route+'&subtype=page')[0]==400
    assert s.request(route+'&context=edit')[0]==400
    assert s.request(route+'&search='+('x'*257))[0]==400
    assert len(s.request('/wp-json/wp/v2/search?type=post&subtype=post')[2])==2
