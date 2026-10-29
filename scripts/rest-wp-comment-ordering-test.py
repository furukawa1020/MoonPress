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
    rows=[create(post=b['id'],label='Z'),create(label='Alpha'),create(label='Beta')]
    for r in rows:set_status(s,r['id'],'approved')
    wp='/wp-json/wp/v2/comments'
    assert [r['author_name'] for r in s.request(wp+'?orderby=author_name&order=asc')[2]]==['Alpha','Beta','Z']
    assert s.request(wp+'?orderby=post&order=asc')[2][0]['post']==a['id']
    ids=[r['id'] for r in reversed(rows)]
    for order in ['asc','desc']:
        assert [r['id'] for r in s.request(wp+'?orderby=include&order='+order+'&include='+','.join(map(str,ids)))[2]]==ids
    assert s.request(wp+'?orderby=include')[0]==400
