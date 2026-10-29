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
    root=create();set_status(s,root['id'],'approved');child=create(parent=root['id']);set_status(s,child['id'],'approved');other=create(post=b['id']);set_status(s,other['id'],'approved')
    assert {c['id'] for c in s.request(route+'?parent=0')[2]}=={root['id'],other['id']}
    assert [c['id'] for c in s.request(route+'?parent='+str(root['id']))[2]]==[child['id']]
    assert s.request(route+'?parent[]=0&parent[]='+str(root['id']))[1]['X-WP-Total']=='3'
    assert [c['id'] for c in s.request(route+'?parent_exclude=0')[2]]==[child['id']]
    assert s.request(route+'?parent=-1')[0]==400
    assert s.request(route+'?parent[1]=0')[0]==400
    assert s.request(route+'?parent=0&parent_exclude=0')[2]==[]
