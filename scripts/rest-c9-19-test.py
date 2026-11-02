from embed_fixture import *
with NativeSite() as s:
    p=post(s);url=P+'/'+str(p['id']);tag=s.request(url+'?context=edit',role='author')[1]['ETag']
    assert s.request(url+'?_embed=author','PATCH',{'title':'Not changed'},'author',tag)[0]==400
    assert s.request(url)[2]['title']['rendered']=='Article'
    assert s.request(url+'?_embed=author','OPTIONS')[0]==200
    row=s.request(url+'?_embed[]=author&_embed[]=wp:term')[2];assert row['_embedded']['author'][0]['id']==s.ids['author']
    meta=s.request('/wp-json/')[2]['moonpress'];assert meta['embedding']['max_subrequests']==256 and 'embeds' not in meta['unsupported']
    args=s.request(url,'OPTIONS')[2]['endpoints'][0]['args'];assert '_embed' in args and args['_embed']['maxItems']==16
