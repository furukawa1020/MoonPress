from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts';route='/wp-json/moonpress/v1/categories'
    assert s.request(route)[2]==[]
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only']},'editor')[0]==201
    status,h,rows=s.request(route);assert status==200 and {r['name']:r['count'] for r in rows}=={'one':1,'shared':2} and h['X-WP-Total']=='2'
    assert s.request(route+'?per_page=1')[1]['X-WP-TotalPages']=='2'
    assert s.request(route,'HEAD')[2] is None
    assert s.request(route,headers={'Authorization':'Basic invalid'})[0]==401
    assert s.request(route+'?page=0')[0]==400
    assert s.request(route+'?context=edit')[0]==400
print('Native taxonomy counts exclude drafts and pages; bounded reads and invalid credential refusal passed.')
