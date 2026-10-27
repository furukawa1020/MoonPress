from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for row in s.request(posts)[2]:
        for plural,field in [('categories','moonpress_categories'),('tags','moonpress_tags')]:
            expected={r['id'] for r in s.request('/wp-json/wp/v2/'+plural)[2] if r['name'] in row[field]}
            assert set(row[plural])==expected
        detail=posts+'/'+str(row['id'])
        assert 'categories' not in s.request(detail+'?context=embed')[2] and 'tags' not in s.request(detail+'?context=embed')[2]
        assert s.request(detail+'?context=edit',role='author')[2]['tags']==row['tags']
    assert 'categories' not in s.request('/wp-json/wp/v2/pages')[2][0]
    assert s.request(posts,'POST',{'title':'Refused','categories':[1]},'author')[0]==400
    assert s.request(posts+'?_fields=id,categories')[2][0].keys()=={'id','categories'}
