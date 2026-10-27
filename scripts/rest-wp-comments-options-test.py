from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    root='/wp-json/wp/v2/comments'
    code,h,meta=s.request(root,'OPTIONS')
    assert code==200 and meta['methods']==['GET','HEAD','OPTIONS'] and meta['schema']['properties']['date_gmt']['context']==['view']
    args=meta['endpoints'][0]['args'];assert args['context']['enum']==['view','embed'] and args['post']['type']=='array' and args['status']['enum']==['approve']
    assert '/wp/v2/comments' in s.request('/wp-json/')[2]['routes']
    post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Paging','status':'publish'},'author')[2]
    for n in range(2):
        c=s.request('/wp-json/moonpress/v1/comments','POST',{'post':post['id'],'content':'Text '+str(n),'author_name':'Reader'},'author')[2];set_status(s,c['id'],'approved')
    code,h,rows=s.request(root+'?per_page=1&post[]='+str(post['id']))
    assert code==200 and len(rows)==1 and h['X-WP-Total']=='2' and 'rel="next"' in h['Link']
    assert s.request(root+'?per_page=1&_envelope=1')[2]['headers']['X-WP-Total']==2
    assert s.request(root+'?unknown=1')[0]==400
    record=sorted((s.site/'.moonpress-comments').glob('*.json'))[0];record.chmod(0o644)
    assert s.request(root)[0]==500
print('WordPress comment discovery: accurate read-only schema, bounded filters, root discovery, pagination and envelopes passed.')
