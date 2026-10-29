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
    rows=[create() for i in range(3)]
    for r in rows:set_status(s,r['id'],'approved')
    ids=[rows[2]['id'],rows[0]['id'],rows[1]['id']]
    for order in ['asc','desc']:
        assert [r['id'] for r in s.request(route+'?orderby=include&order='+order+'&include='+','.join(map(str,ids)))[2]]==ids
    assert s.request(route+'?orderby=include')[0]==400
    assert [r['id'] for r in s.request(route+'?orderby=include&include='+','.join(map(str,ids))+'&exclude='+str(ids[1]))[2]]==[ids[0],ids[2]]
