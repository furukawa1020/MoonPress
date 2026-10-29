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
    assert s.request(url,'POST',{'status':'approve'})[0]==401
    assert s.request(url,'POST',{'status':'approve'},'subscriber',tag)[0]==403
    assert s.request(url,'POST',{'status':'approve'},'editor')[0]==428
    code,h,data=s.request(url,'POST',{'status':'approve'},'editor',tag);assert code==200 and data['status']=='approved' and data['content']['raw']=='Text' and data['parent']==0
    assert s.request(url,'POST',{'status':'hold'},'editor',tag)[0]==412
    assert s.request(url,'POST',{'status':'spam'},'editor',h['ETag'])[2]['status']=='spam'
    assert s.request(url)[0]==404
