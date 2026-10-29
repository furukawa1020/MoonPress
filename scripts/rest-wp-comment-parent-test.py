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
    for context in ['view','embed']:
        rows=s.request(wp+'?context='+context+'&orderby=id&order=asc')[2]
        assert [r['parent'] for r in rows]==[0,root['id']]
        assert s.request(wp+'/'+str(child['id'])+'?context='+context)[2]==rows[1]
    set_status(s,root['id'],'hold');assert s.request(wp)[2]==[] and s.request(wp+'/'+str(child['id']))[0]==404
