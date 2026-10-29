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
    row=create();set_status(s,row['id'],'approved');url='/wp-json/wp/v2/comments/'+str(row['id'])
    tag=s.request(url,role='author')[1]['ETag'];assert tag==s.request(url+'?context=edit',role='editor')[1]['ETag']
    assert s.request(url+'?context=edit',role='author')[0]==403
    assert s.request(url,'PATCH',{'content':'Post owner'},'author',tag)[0]==200
    other=s.request(posts,'POST',{'title':'Other','status':'publish'},'editor')[2]
    foreign=create(post=other['id']);url2='/wp-json/wp/v2/comments/'+str(foreign['id']);tag2=s.request(url2+'?context=edit',role='editor')[1]['ETag']
    assert s.request(url2,'PATCH',{'status':'approve'},'author',tag2)[0]==403
    assert s.request(url2,'PATCH',{'status':'approve'},'contributor',tag2)[0]==403
    assert s.request(url2,'PATCH',{'status':'approve'},'editor',tag2)[0]==200
    assert s.request(url,'PATCH',{'content':'Spoof'},'subscriber',tag)[0]==403
