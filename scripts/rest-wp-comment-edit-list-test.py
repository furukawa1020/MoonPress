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
    rows=[create(text=str(i)) for i in range(3)]
    for row in rows[:2]:set_status(s,row['id'],'approved')
    wp='/wp-json/wp/v2/comments?context=edit'
    assert s.request(wp)[0]==401 and s.request(wp,role='author')[0]==403
    code,h,data=s.request(wp+'&per_page=1',role='editor');assert code==200 and h['X-WP-Total']=='2' and len(data)==1 and 'raw' in data[0]['content'] and 'Link' in h
    assert s.request(wp+'&_fields=id,content.raw',role='editor')[2][0].keys()=={'id','content'}
    assert 'raw' not in s.request('/wp-json/wp/v2/comments')[2][0]['content']
