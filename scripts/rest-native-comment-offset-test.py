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
    rows=[create(text=str(i)) for i in range(4)]
    for r in rows:set_status(s,r['id'],'approved')
    assert [r['id'] for r in s.request(route+'?offset=1&per_page=2')[2]]==[rows[1]['id'],rows[2]['id']]
    assert s.request(route+'?offset=0&page=2&per_page=2')[2][0]['id']==rows[0]['id']
    assert s.request(route+'?offset=100')[2]==[]
    code,h,body=s.request(route+'?offset=1&per_page=2');assert code==200 and 'offset=3' in h['Link'] and 'offset=0' in h['Link']
    head=s.request(route+'?offset=1&per_page=2','HEAD');assert head[2] is None and head[1]['X-WP-Total']==h['X-WP-Total'] and head[1]['Link']==h['Link']
    assert s.request(route+'?offset=-1')[0]==400
    code,h,body=s.request(route+'?per_page=2');assert code==200 and h['X-WP-Total']=='4' and 'rel="next"' in h['Link']
