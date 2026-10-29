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
    import json
    row=create();url=route+'/'+str(row['id']);tag=s.request(url+'?context=edit',role='editor')[1]['ETag'];vault=s.site/'.moonpress-comments'
    count=len(list(vault.glob('*.json')))
    assert s.request(url,'POST',{'content':'No change','author_name':'','status':'approved'},'editor',tag)[0]==400
    assert len(list(vault.glob('*.json')))==count
    code,h,data=s.request(url,'POST',{'content':'Atomic','author_name':'New','status':'approved'},'editor',tag)
    assert code==200 and data['status']=='approved' and data['content']['raw']=='Atomic' and data['author_name']=='New'
    assert len(list(vault.glob('*.json')))==count+1 and json.loads(sorted(vault.glob('*.json'))[-1].read_text())['action']=='edit'
    assert s.request(url,'POST',{'content':'Wrong','status':'hold'},'editor',tag)[0]==412
    assert s.request(url)[2]['status']=='approved'
    s.restart();assert s.request(url)[2]['author_name']=='New'
