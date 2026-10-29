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
    root=create();set_status(s,root['id'],'approved');child=create(parent=root['id']);set_status(s,child['id'],'approved');grand=create(parent=child['id']);set_status(s,grand['id'],'approved')
    assert len(s.request(route)[2])==3
    for hidden in ['hold','spam','trash']:
        set_status(s,root['id'],hidden)
        assert s.request(route)[2]==[] and s.request(route)[1]['X-WP-Total']=='0'
        assert s.request(route+'/'+str(grand['id']))[0]==404
        assert len(s.request(route+'?context=edit',role='editor')[2])==3
        # Trusted fixture restores via hold, respecting the journal transition rules.
        if hidden=='trash':set_status(s,root['id'],'hold')
        set_status(s,root['id'],'approved')
        assert len(s.request(route)[2])==3
    set_status(s,child['id'],'hold');assert [c['id'] for c in s.request(route)[2]]==[root['id']]
    assert s.request(route+'?context=edit',role='subscriber')[2][1]['id']==child['id']
