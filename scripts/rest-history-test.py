from rest_fixture import NativeSite,run
with NativeSite() as site:
    run('history-enable',site.site)
    _,h,row=site.request('/wp-json/wp/v2/posts','POST',{'title':'Version one','content':'<p>Original</p>'},'author')
    path='/wp-json/wp/v2/posts/'+str(row['id']);native='/wp-json/moonpress/v1/posts/'+str(row['id'])+'/history'
    assert site.request(native)[0]==401 and site.request(native,role='subscriber')[0]==403
    assert site.request(native,role='author')[2]==[]
    _,new,row=site.request(path,'POST',{'title':'Version two'},'author',h['ETag'])
    status,headers,rows=site.request(native+'/?per_page=1',role='author')
    assert status==200 and headers['X-WP-Total']=='1' and len(rows)==1
    record=rows[0]['id']
    missing=record[:65]+'0'*64+'.json'
    assert site.request(native+'/'+missing,role='author')[0]==404
    assert any('/moonpress/v1/posts/' in key for key in site.request('/wp-json/')[2]['routes'])
    status,_,saved=site.request(native+'/'+record,role='author')
    assert status==200 and saved['article']['title']['raw']=='Version one' and saved['article']['content']['rendered']=='<p>Original</p>\n'
    assert 'source' not in str(saved) and 'frontmatter' not in str(saved)
    assert site.request(native,role='contributor')[0]==403
    assert site.request(native+'?page=0',role='author')[0]==400
    assert site.request(native,'HEAD',role='author')[2] is None
    assert site.request(native,'OPTIONS')[2]['methods']==['GET','HEAD','OPTIONS']
    _,other,second=site.request('/wp-json/wp/v2/posts','POST',{'title':'Other'},'author')
    otherroute='/wp-json/moonpress/v1/posts/'+str(second['id'])+'/history/'+record
    assert site.request(otherroute,role='author')[0]==404
    assert site.request(path,'DELETE',role='author',etag=new['ETag'])[0]==200
    status,_,replacement=site.request('/wp-json/wp/v2/posts','POST',{'title':'Version one'},'contributor')
    assert status==201 and replacement['id']!=row['id']
    replacement_route='/wp-json/moonpress/v1/posts/'+str(replacement['id'])+'/history'
    assert site.request(replacement_route,role='contributor')[2]==[]
    assert site.request(replacement_route+'/'+record,role='contributor')[0]==404
print('Native history: fresh authorization, per-article record isolation, generated historical content, pagination and no source paths passed.')
