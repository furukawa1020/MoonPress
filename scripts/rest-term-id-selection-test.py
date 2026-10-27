from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural;rows=s.request(route)[2];a,b=[r['id'] for r in rows]
        assert s.request(route+'?include='+str(a))[2]==[rows[0]]
        assert s.request(route+'?include[]='+str(a)+'&include[]='+str(b)+'&exclude='+str(b))[2]==rows
        assert s.request(route+'?exclude='+str(a)+','+str(b))[2]==[]
        assert s.request(route+'?include=2147483647')[2]==[]
        assert s.request(route+'?include=0')[0]==400
        assert s.request(route+'?include[1]='+str(a))[0]==400
        assert s.request(route+'/'+str(a)+'?include='+str(a))[0]==400
