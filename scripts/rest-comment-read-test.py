from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as site:
    _,h,post=site.request('/wp-json/wp/v2/posts','POST',{'title':'Discussion','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments';data={'post':post['id'],'content':'<script>not executed</script>','author_name':'Reader'}
    _,_,one=site.request(route,'POST',data,'subscriber');site.request(route,'POST',data,'contributor')
    assert site.request(route)[2]==[] and site.request(route+'/'+str(one['id']))[0]==404
    assert len(site.request(route+'?context=edit',role='subscriber')[2])==1
    assert site.request(route+'/'+str(one['id'])+'?context=edit',role='contributor')[0]==404
    set_status(site,one['id'],'approved')
    status,headers,rows=site.request(route+'?post='+str(post['id']))
    assert status==200 and headers['X-WP-Total']=='1' and len(rows)==1 and rows[0]['id']==one['id']
    assert 'raw' not in rows[0]['content'] and 'author' not in rows[0] and '&lt;script&gt;' in rows[0]['content']['rendered']
    assert site.request(route,'HEAD')[2] is None
    assert site.request(route+'?status=hold')[0]==400 and site.request(route+'?context=edit')[0]==401
    assert site.request(route,headers={'Authorization':'Basic invalid'})[0]==401
    assert site.request(route+'?per_page=101')[0]==400
    site.request('/wp-json/wp/v2/posts/'+str(post['id']),'POST',{'status':'draft'},'author',h['ETag'])
    assert site.request(route)[2]==[] and site.request(route+'/'+str(one['id']))[0]==404
print('Native comment reads: approval and parent visibility before counts, own edit scope, safe public fields, HEAD and bad-credential refusal passed.')
