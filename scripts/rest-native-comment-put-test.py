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
    row=create();url=route+'/'+str(row['id']);tag=s.request(url+'?context=edit',role='editor')[1]['ETag']
    assert s.request(url,'PUT',{'content':'PUT'},'editor',tag)[2]['content']['raw']=='PUT'
    assert s.request(route,'PUT',{'content':'Wrong'},'editor')[0]==405
    assert s.request(url,'PUT',{'content':'No'},'author',tag)[0]==403
    assert 'PUT' in s.request(url,'OPTIONS')[2]['methods']
