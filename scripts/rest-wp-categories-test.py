from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    route='/wp-json/wp/v2/categories'
    code,h,rows=s.request(route)
    assert code==200 and {r['name']:r['count'] for r in rows}=={'one':1,'shared':2}
    assert all(type(r['id']) is int and r['id']>0 and r['taxonomy']=='category' and r['parent']==0 for r in rows)
    assert all(r['link'].endswith('.html') and r['description']=='' for r in rows)
    assert s.request(route,role='administrator')[2]==rows
    assert s.request(route+'?context=edit')[0]==400
    assert s.request(route,'POST',{})[0]==405
    assert s.request(route,headers={'Authorization':'Basic invalid'})[0]==401
    ids={r['name']:r['id'] for r in rows};s.restart()
    assert {r['name']:r['id'] for r in s.request(route)[2]}==ids
