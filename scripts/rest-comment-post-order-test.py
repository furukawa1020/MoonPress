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
    rows=[create(post=b['id']),create(post=a['id']),create(post=b['id'])]
    for r in rows:set_status(s,r['id'],'approved')
    assert [r['post'] for r in s.request(route+'?orderby=post')[2]]==[a['id'],b['id'],b['id']]
    assert [r['post'] for r in s.request(route+'?orderby=post&order=desc')[2]]==[b['id'],b['id'],a['id']]
