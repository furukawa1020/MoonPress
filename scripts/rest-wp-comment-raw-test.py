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
    code,h,row=s.request(wp,'POST',{'post':a['id'],'content':{'raw':'<p>Line &amp; one<br>Two</p><p>Three</p>'}},'subscriber')
    assert code==201 and row['author_name']=='subscriber' and row['content']['raw']=='Line & one\nTwo\n\nThree' and '<script>' not in row['content']['rendered']
    for unsafe in ['<script>x</script>','<a href="https://example.com">x</a>','<p class="x">y</p>']:
        assert s.request(wp,'POST',{'post':a['id'],'content':unsafe},'subscriber')[0]==400
    for field,value in [('author',1),('author_email','a@example.com'),('author_ip','1.2.3.4'),('author_url','https://example.com'),('status','approved')]:
        assert s.request(wp,'POST',{'post':a['id'],'content':'Spoof',field:value},'subscriber')[0]==400
    assert s.request(wp,'POST',{'post':a['id'],'content':{'raw':'x','rendered':'y'}},'subscriber')[0]==400
    assert s.request(wp+'?context=edit','POST',{'post':a['id'],'content':'Context'},'subscriber')[0]==201
    root=create();set_status(s,root['id'],'approved')
    assert s.request(wp,'POST',{'post':a['id'],'parent':root['id'],'content':'Reply'},'subscriber')[2]['parent']==root['id']
