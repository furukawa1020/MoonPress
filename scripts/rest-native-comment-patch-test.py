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
    code,h,data=s.request(url,'PATCH',{'content':'PATCH'},'editor',tag);assert code==200 and data['author_name']=='Reader' and data['status']=='hold' and data['parent']==0 and data['author']==s.ids['subscriber']
    assert s.request(url,'PATCH',{'author_name':'Name'},'editor',h['ETag'])[2]['content']['raw']=='PATCH'
    assert s.request(route,'PATCH',{},'editor')[0]==405
    assert 'PATCH' in s.request(url,'OPTIONS')[2]['methods']
