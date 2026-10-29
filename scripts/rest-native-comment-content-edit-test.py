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
    row=create();url=route+'/'+str(row['id']);tag=s.request(url+'?context=edit',role='editor')[1]['ETag']
    assert s.request(url,'POST',{'content':'Changed'},'subscriber',tag)[0]==403
    assert s.request(url,'POST',{'content':'Changed'},'editor')[0]==428
    assert s.request(url,'POST',{'content':''},'editor',tag)[0]==400
    code,h,data=s.request(url,'POST',{'content':'Changed'},'editor',tag);assert code==200 and data['content']['raw']=='Changed' and data['status']=='hold'
    assert s.request(url,'POST',{'content':'Stale'},'editor',tag)[0]==412
    count=len(list((s.site/'.moonpress-comments').glob('*.json')))
    assert s.request(url,'POST',{'content':'Changed'},'editor',h['ETag'])[1]['ETag']==h['ETag']
    assert len(list((s.site/'.moonpress-comments').glob('*.json')))==count
    s.restart();assert s.request(url+'?context=edit',role='editor')[2]['content']['raw']=='Changed'
    set_status(s,row['id'],'approved');assert 'Changed' in s.request(url)[2]['content']['rendered']
