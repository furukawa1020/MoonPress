from rest_fixture import NativeSite,run
with NativeSite() as site:
    run('history-enable',site.site)
    _,initial,row=site.request('/wp-json/wp/v2/posts','POST',{'title':'Original','content':'<p>Saved body</p>','status':'publish'},'author')
    path='/wp-json/wp/v2/posts/'+str(row['id']);history='/wp-json/moonpress/v1/posts/'+str(row['id'])+'/history'
    _,current,_=site.request(path,'POST',{'title':'Changed','status':'draft'},'author',initial['ETag'])
    record=site.request(history,role='author')[2][0]['id'];restore=history+'/'+record+'/restore'
    assert site.request(restore,'POST',{},'author')[0]==428
    assert site.request(restore,'POST',{},'author',initial['ETag'])[0]==412
    assert site.request(restore,'POST',{},'subscriber',current['ETag'])[0]==403
    assert site.request(restore,'POST',{'author':1},'author',current['ETag'])[0]==400
    status,h,restored=site.request(restore,'POST',{},'author',current['ETag'])
    assert status==200 and restored['title']['raw']=='Original' and restored['id']==row['id'] and restored['author']==row['author']
    assert restored['content']['rendered']=='<p>Saved body</p>\n'
    assert site.request(restore,'POST',{},'author',h['ETag'])[1]['ETag']==h['ETag']
    assert len(site.request(history,role='author')[2])==2
    assert site.request(restore,'OPTIONS')[2]['methods']==['POST','OPTIONS']
    assert site.request(restore,role='author')[0]==405
    _,draft,_=site.request(path,'POST',{'status':'draft'},'author',h['ETag'])
    run('access-change',site.site,site.revision,'role','author','contributor')
    assert site.request(restore,'POST',{},'author',draft['ETag'])[0]==403
    assert site.request(path+'?context=edit',role='author')[2]['status']=='draft'
print('Native restore: current If-Match, ownership/publication identity, exact content/no-op and preserved reverse history passed.')
