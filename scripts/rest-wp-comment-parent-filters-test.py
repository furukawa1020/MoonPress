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
    root=create();set_status(s,root['id'],'approved');child=create(parent=root['id']);set_status(s,child['id'],'approved')
    wp='/wp-json/wp/v2/comments'
    assert [r['id'] for r in s.request(wp+'?parent=0')[2]]==[root['id']]
    assert [r['id'] for r in s.request(wp+'?parent_exclude[]=0')[2]]==[child['id']]
    assert [r['id'] for r in s.request(wp+'?parent[]='+str(root['id']))[2]]==[child['id']]
    assert s.request(wp+'?parent=-1')[0]==400
    assert s.request(wp+'?parent='+str(root['id'])+'&parent_exclude='+str(root['id']))[2]==[]
    args=s.request(wp,'OPTIONS')[2]['endpoints'][0]['args'];assert args['parent']['items']['type']=='integer' and 'parent_exclude' in args
