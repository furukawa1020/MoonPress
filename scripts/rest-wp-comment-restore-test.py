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
    row=create();url='/wp-json/wp/v2/comments/'+str(row['id']);tag=s.request(url+'?context=edit',role='editor')[1]['ETag']
    code,h,data=s.request(url,'DELETE',role='editor',etag=tag);assert code==200
    assert s.request(url,'POST',{'status':'approve'},'editor',h['ETag'])[0]==409
    assert s.request(url,'POST',{'status':'hold','content':'Wrong'},'editor',h['ETag'])[0]==409
    code,held,data=s.request(url,'POST',{'status':'hold'},'editor',h['ETag']);assert code==200 and data['status']=='hold' and s.request(url)[0]==404
    assert s.request(url,'PATCH',{'status':'approve'},'editor',held['ETag'])[2]['status']=='approved'
    assert s.request(url)[0]==200
