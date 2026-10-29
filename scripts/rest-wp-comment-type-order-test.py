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
    rows=[create() for _ in range(3)]
    for row in rows:set_status(s,row['id'],'approved')
    wp='/wp-json/wp/v2/comments'
    for order in ['asc','desc']:
        assert [r['id'] for r in s.request(wp+'?orderby=type&order='+order)[2]]==[r['id'] for r in reversed(rows)]
    assert s.request(wp+'?type=pingback&orderby=type')[0]==400
    assert 'type' in s.request(wp,'OPTIONS')[2]['endpoints'][0]['args']['orderby']['enum']
