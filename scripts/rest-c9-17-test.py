from embed_fixture import *
with NativeSite() as s:
    p=post(s);url=P+'/'+str(p['id'])+'?_embed=replies'
    code,h,row=s.request(url);tag=h['ETag']
    assert s.request(url,headers={'If-None-Match':tag})[0]==304
    comment(s,p)
    code,new,row=s.request(url,headers={'If-None-Match':tag});assert code==200 and new['ETag']!=tag and 'replies' in row['_embedded']
    assert s.request(url,'HEAD')[2] is None
    env=s.request(url+'&_envelope=1')[2];assert env['status']==200 and env['body']==row
    code,h,row=s.request(P+'/'+str(p['id'])+'?context=edit&_embed=author',role='author')
    assert code==200 and row['title']['raw']=='Article' and 'roles' not in row['_embedded']['author'][0]
    source=s.request(P+'/'+str(p['id'])+'?context=edit',role='author')[1]['ETag']
    represented=s.request(P+'/'+str(p['id'])+'?context=edit&_embed=author',role='author')[1]['ETag']
    assert source==represented
    assert s.request(P+'/'+str(p['id']),'PATCH',{'title':'Accepted'},'author',represented)[0]==200
