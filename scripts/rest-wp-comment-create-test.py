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
    wp='/wp-json/wp/v2/comments'
    code,h,row=s.request(wp,'POST',{'post':a['id'],'author_name':'Reader','content':'Pending'},'subscriber')
    assert code==201 and row['status']=='hold' and row['content']['raw']=='Pending' and h['Location']==wp+'/'+str(row['id'])
    assert s.request(wp)[2]==[] and s.request(h['Location'])[0]==404
    assert s.request(wp,'POST',{'post':a['id'],'content':'Anon'})[0]==401
    assert s.request(wp+'/'+str(row['id']),'POST',{},'editor')[0]==405
    assert s.request(wp,'DELETE',role='editor')[0]==405
