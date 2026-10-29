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
    rows=[create(label=n) for n in ['Z','Alpha','beta']]
    for r in rows:set_status(s,r['id'],'approved')
    assert [r['author_name'] for r in s.request(route+'?orderby=author_name')[2]]==['Alpha','beta','Z']
    assert [r['author_name'] for r in s.request(route+'?orderby=author_name&order=desc')[2]]==['Z','beta','Alpha']
