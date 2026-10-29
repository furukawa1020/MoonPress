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
    rows=[create(text=str(i)) for i in range(4)]
    for row,status in zip(rows,['hold','approved','spam','trash']):
        if status!='hold':set_status(s,row['id'],status)
    wp='/wp-json/wp/v2/comments'
    for status,total in [('hold',1),('approve',1),('spam',1),('trash',1),('all',4)]:
        code,h,data=s.request(wp+'?context=edit&status='+status,role='editor');assert code==200 and h['X-WP-Total']==str(total)
    for status in ['hold','spam','trash','all']:assert s.request(wp+'?status='+status,role='editor')[0]==400
    assert s.request(wp+'?context=edit&status=bad',role='editor')[0]==400
    assert s.request(wp+'?context=edit&status=all&per_page=2&page=99',role='editor')[2]==[]
