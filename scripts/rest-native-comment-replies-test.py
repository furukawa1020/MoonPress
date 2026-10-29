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
    root=create();assert root['parent']==0
    assert s.request(route,'POST',{'post':a['id'],'parent':root['id'],'content':'Hidden','author_name':'R'},'subscriber')[0]==400
    set_status(s,root['id'],'approved');child=create(parent=root['id']);assert child['parent']==root['id'] and child['status']=='hold'
    assert s.request(route,'POST',{'post':b['id'],'parent':root['id'],'content':'Cross','author_name':'R'},'subscriber')[0]==400
    assert s.request(route,'POST',{'post':a['id'],'parent':999,'content':'Missing','author_name':'R'},'subscriber')[0]==400
    assert s.request(route,'POST',{'post':a['id'],'parent':-1,'content':'Invalid','author_name':'R'},'subscriber')[0]==400
    cursor=root
    # Eight ancestors are allowed; a ninth reply level is refused without a write.
    for level in range(8):
        cursor=create(parent=cursor['id']);set_status(s,cursor['id'],'approved')
    before=len(list((s.site/'.moonpress-comments').glob('*.json')))
    assert s.request(route,'POST',{'post':a['id'],'parent':cursor['id'],'content':'Too deep','author_name':'R'},'subscriber')[0]==400
    assert len(list((s.site/'.moonpress-comments').glob('*.json')))==before
    s.restart();assert s.request(route+'/'+str(child['id'])+'?context=edit',role='subscriber')[2]['parent']==root['id']
