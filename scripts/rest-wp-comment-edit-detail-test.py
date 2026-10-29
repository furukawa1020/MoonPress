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
    row=create();wp='/wp-json/wp/v2/comments/'+str(row['id'])
    assert s.request(wp+'?context=edit')[0]==401
    assert s.request(wp+'?context=edit',role='subscriber')[0]==403
    for role in ['editor','administrator']:
        code,h,data=s.request(wp+'?context=edit',role=role);assert code==200 and data['content']['raw']=='Text' and data['status']=='hold' and 'ETag' in h
    assert s.request(wp)[0]==404
    assert s.request(wp+'?context=edit',headers={'Authorization':'Basic bad'})[0]==401
