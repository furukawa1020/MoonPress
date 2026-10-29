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
    code,h,pending=s.request(wp,'POST',{'post':a['id'],'content':{'raw':'Held'}},'subscriber');assert code==201
    assert s.request(h['Location'])[0]==404
    set_status(s,pending['id'],'approved')
    assert s.request(h['Location'])[2]['content']['rendered']=='<p>Held</p>\n'
    assert 'raw' not in s.request(h['Location'])[2]['content']
    child=s.request(wp,'POST',{'post':a['id'],'parent':pending['id'],'content':'Reply'},'subscriber')[2];set_status(s,child['id'],'approved')
    set_status(s,pending['id'],'spam');assert s.request(wp)[2]==[]
    assert s.request(wp+'?context=edit',role='editor')[0]==400
