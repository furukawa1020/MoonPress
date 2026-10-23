from rest_fixture import NativeSite
with NativeSite() as site:
    status,h,row=site.request('/wp-json/wp/v2/posts','POST',{'title':'Slug post','status':'publish'},'author');assert status==201
    path='/wp-json/wp/v2/posts/'+str(row['id']);version=h['ETag'];source=site.site/'content/slug-post.md'
    assert site.request(path,'POST',{'slug':'slug-post'},'author',version)[1]['ETag']==version
    site.request('/wp-json/wp/v2/pages','POST',{'title':'Occupied','slug':'occupied'},'editor')
    assert site.request(path,'POST',{'slug':'occupied'},'author',version)[0]==409
    for slug in ['../escape','','a/b','x'*231]:assert site.request(path,'POST',{'slug':slug},'author',version)[0]==400
    before=source.read_bytes()
    assert site.request(path,'POST',{'slug':'renamed'},'subscriber',version)[0]==403 and source.read_bytes()==before
    status,h,row=site.request(path,'POST',{'slug':'renamed'},'author',version)
    assert status==200 and row['slug']=='renamed' and row['link'].endswith('renamed.html') and source.exists()
    assert not (site.site/'content/renamed.md').exists()
    assert site.request(path,'POST',{'slug':'another'},'author',version)[0]==412
    assert site.request(path,'POST',{'slug':'renamed'},'author',h['ETag'])[1]['ETag']==h['ETag']
print('Native slug update: same-source identity, atomic no-op, conflicts, authorization and stale-version guards passed.')
