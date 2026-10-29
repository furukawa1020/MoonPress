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
    from operator_fixture import Operator
    root=create();set_status(s,root['id'],'approved');child=create(parent=root['id'])
    with Operator(s.site) as op:
        code,html=op.request('/comment?id='+str(child['id']));assert code==200 and 'Parent:' in html and '/comment?id='+str(root['id']) in html
        code,html=op.request('/comments?status=any&parent='+str(root['id']));assert code==200 and '1 comments' in html and '<th>Parent</th>' in html
        assert op.request('/comments?parent=-1')[0]==400
