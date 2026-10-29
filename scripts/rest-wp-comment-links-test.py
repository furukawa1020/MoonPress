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
    wp='/wp-json/wp/v2/comments';row=s.request(wp+'/'+str(child['id']))[2];links=row['_links']
    assert links['up'][0]['href'].endswith('/comments/'+str(root['id']))
    assert links['in-reply-to'][0]['href'].endswith('/posts/'+str(a['id']))
    assert links['children'][0]['href'].endswith('?parent='+str(child['id']))
    assert 'up' not in s.request(wp+'/'+str(root['id']))[2]['_links']
    assert s.request(posts+'/'+str(a['id']))[2]['_links']['replies'][0]['href'].endswith('?post='+str(a['id']))
    assert s.request(wp+'?_fields=id,_links.up')[2][0]['_links']['up']==links['up']
