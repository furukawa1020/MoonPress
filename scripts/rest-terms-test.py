from rest_fixture import NativeSite
with NativeSite() as site:
    status,headers,row=site.request('/wp-json/wp/v2/posts','POST',{'title':'Named terms','moonpress_categories':[' 月 ','News','月'],'moonpress_tags':['native','safe']},'author')
    assert status==201 and set(row['moonpress_categories'])=={'News','月'} and set(row['moonpress_tags'])=={'native','safe'}
    path='/wp-json/wp/v2/posts/'+str(row['id']);etag=headers['ETag']
    assert site.request(path,'POST',{'moonpress_categories':['月','News']},'author',etag)[1]['ETag']==etag
    before={p.name:p.read_bytes() for p in (site.site/'content').glob('*.md')}
    for value in ['CSV',123,[1],[''],['a\nb'],['x'*97],['x']*65]:
        assert site.request(path,'POST',{'moonpress_tags':value},'author',etag)[0]==400
        assert site.request('/wp-json/wp/v2/posts','POST',{'title':'Bad terms','moonpress_tags':value},'author')[0]==400
    assert before=={p.name:p.read_bytes() for p in (site.site/'content').glob('*.md')}
    status,headers,row=site.request(path,'POST',{'status':'publish','moonpress_tags':['new']},'author',etag)
    assert status==200 and row['moonpress_tags']==['new']
    assert set(site.request(path)[2]['moonpress_categories'])=={'News','月'}
    assert site.request(path,'POST',{'moonpress_tags':[]},'author',etag)[0]==412
    assert site.request(path,'POST',{'moonpress_tags':[]},'subscriber',headers['ETag'])[0]==403
print('Native named terms: normalized creation/update, exact no-op, bounds, roles and stale versions passed.')
