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
    url='/wp-json/wp/v2/comments/'+str(root['id']);tag=s.request(url+'?context=edit',role='editor')[1]['ETag']
    assert s.request(url+'?force=true','DELETE',role='editor',etag=tag)[0]==501
    assert s.request(url,'DELETE',role='editor')[0]==428
    code,h,data=s.request(url+'?force=false','DELETE',role='editor',etag=tag);assert code==200 and data['status']=='trash' and data['content']['raw']=='Text'
    assert s.request('/wp-json/wp/v2/comments')[2]==[]
    assert s.request(url,'DELETE',role='editor',etag=h['ETag'])[0]==410
    assert s.request('/wp-json/wp/v2/comments','DELETE',role='editor')[0]==405
