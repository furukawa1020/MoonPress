from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts';route='/wp-json/moonpress/v1/comments'
    a=s.request(posts,'POST',{'title':'One','status':'publish','slug':'one'},'author')[2]
    b=s.request(posts,'POST',{'title':'Two','status':'publish','slug':'two'},'author')[2]
    def create(post=a['id'],parent=0,label='Reader',text='Text',role='subscriber'):
        code,h,row=s.request(route,'POST',{'post':post,'parent':parent,'author_name':label,'content':text},role)
        assert code==201,(code,row)
        return row
    rows=[create() for i in range(4)]
    for r in rows:set_status(s,r['id'],'approved')
    wp='/wp-json/wp/v2/comments?orderby=id&order=asc&per_page=2'
    assert s.request(wp+'&offset=1')[2][0]['id']==rows[1]['id']
    assert s.request(wp+'&offset=0&page=2')[2][0]['id']==rows[2]['id']
    code,h,body=s.request(wp+'&page=99');assert code==200 and body==[] and h['X-WP-Total']=='4' and 'page=2' in h['Link']
    assert s.request(wp+'&offset=-1')[0]==400
    assert 'offset' in s.request('/wp-json/wp/v2/comments','OPTIONS')[2]['endpoints'][0]['args']
