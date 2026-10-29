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
    row=create();url='/wp-json/wp/v2/comments/'+str(row['id']);tag=s.request(url+'?context=edit',role='editor')[1]['ETag']
    code,h,data=s.request(url,'POST',{'author_name':' <Public> ','content':{'raw':'New'},'status':'approve'},'editor',tag);assert code==200 and data['author_name']=='<Public>' and data['author']==s.ids['subscriber'] and data['content']['raw']=='New'
    for key,value in [('author',1),('post',b['id']),('parent',1),('date','2020-01-01'),('author_email','x@example.invalid'),('author_ip','127.0.0.1'),('author_url','https://example.com')]:
        assert s.request(url,'PATCH',{key:value},'editor',h['ETag'])[0]==400
    assert s.request(url,'POST',{'author_name':''},'editor',h['ETag'])[0]==400
