from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    rows=s.request(posts+'?orderby=id&order=asc')[2];one,two=rows
    cat=next(r['id'] for r in s.request('/wp-json/wp/v2/categories')[2] if r['name']=='one')
    tag=next(r['id'] for r in s.request('/wp-json/wp/v2/tags')[2] if r['name']=='shared')
    query='?categories='+str(cat)+'&tags='+str(tag)
    assert s.request(posts+query+'&tax_relation=AND')[2]==[one]
    assert len(s.request(posts+query+'&tax_relation=OR')[2])==2
    assert s.request(posts+'?categories='+str(cat)+'&categories_exclude='+str(cat)+'&tax_relation=OR')[1]['X-WP-Total']=='2'
    assert len(s.request(posts+'?tax_relation=OR')[2])==2
    assert s.request(posts+query+'&tax_relation=and')[0]==400
    assert s.request(posts+'?tax_relation=X',role='administrator')[0]==400
