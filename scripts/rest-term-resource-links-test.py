from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    from urllib.parse import urlsplit
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural
        for row in s.request(route)[2]:
            for rel in ['self','collection','about','wp:post_type']:
                target=urlsplit(row['_links'][rel][0]['href'])
                assert s.request(target.path+('?' + target.query if target.query else ''))[0]==200
            assert s.request(route+'/'+str(row['id'])+'?context=embed')[2]['_links']==row['_links']
    for row in s.request(posts)[2]:
        assert {link['taxonomy'] for link in row['_links']['wp:term']}=={'category','post_tag'}
        for link in row['_links']['wp:term']:
            target=urlsplit(link['href']);terms=s.request(target.path+'?'+target.query)[2]
            plural='categories' if link['taxonomy']=='category' else 'tags'
            assert {r['id'] for r in terms}==set(row[plural])
    assert 'wp:term' not in s.request('/wp-json/wp/v2/pages')[2][0]['_links']
