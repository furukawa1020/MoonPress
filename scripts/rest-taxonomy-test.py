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
    tags='/wp-json/moonpress/v1/tags'
    assert s.request(tags)[2]==[]
    assert s.request(posts,'POST',{'title':'Tag one','status':'publish','moonpress_tags':['native','fast']},'author')[0]==201
    assert s.request(posts,'POST',{'title':'Tag draft','moonpress_tags':['hidden']},'author')[0]==201
    assert {r['name']:r['count'] for r in s.request(tags)[2]}=={'native':1,'fast':1}
    assert s.request(tags+'?_fields=name')[2]==[{'name':'fast'},{'name':'native'}]
    assert s.request(route+'?search=SHARED')[2][0]['count']==2
    assert s.request(route+'?name=one')[2][0]['name']=='one'
    assert s.request(tags+'?search=FAST')[1]['X-WP-Total']=='1'
    assert s.request(route+'?search=secret')[2]==[]
    assert s.request(route+'?search='+('a'*257))[0]==400
    assert s.request(route+'?name=')[0]==400
    assert [r['name'] for r in s.request(route+'?orderby=count&order=desc')[2]]==['shared','one']
    assert s.request(route+'?orderby=count&order=desc&per_page=1')[2][0]['count']==2
    assert s.request(route+'?order=sideways')[0]==400
    assert s.request(route+'?orderby=private')[0]==400
print('Native taxonomy counts exclude drafts and pages; bounded reads and invalid credential refusal passed.')
