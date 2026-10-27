from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural;rows=s.request(route)[2]
        code,h,page=s.request(route+'?per_page=1')
        assert code==200 and page==rows[:1] and h['X-WP-Total']=='2' and h['X-WP-TotalPages']=='2'
        assert 'rel="next"' in h['Link'] and 'per_page=1' in h['Link']
        code,h,page=s.request(route+'?per_page=1&page=2')
        assert page==rows[1:] and 'rel="prev"' in h['Link']
        assert s.request(route+'?per_page=1&offset=1')[2]==rows[1:]
        assert s.request(route+'?per_page=1&page=2&offset=0')[2]==rows[1:]
        code,h,empty=s.request(route+'?per_page=1&offset=9')
        assert code==200 and empty==[] and 'rel="prev"' in h['Link'] and 'rel="next"' not in h['Link']
        assert s.request(route+'?offset=20')[2]==[]
        assert s.request(route+'?page=3&per_page=1')[2]==[]
        assert s.request(route+'?page=0')[0]==400 and s.request(route+'?per_page=101')[0]==400
        assert s.request(route+'?per_page=1','HEAD')[1]['X-WP-Total']=='2'
    for p in (s.site/'content').glob('*.md'):p.unlink()
    assert s.request(route)[1]['X-WP-TotalPages']=='0' and s.request(route)[2]==[]
    assert s.request(route+'?page=2')[2]==[]
