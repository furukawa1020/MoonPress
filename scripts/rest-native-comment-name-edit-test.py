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
    code,h,data=s.request(url,'POST',{'author_name':'  <Renamed>  '},'editor',tag);assert code==200 and data['author_name']=='<Renamed>' and data['author']==s.ids['subscriber'] and data['content']['raw']=='Text'
    for name in ['', 'x'*81, 'Bad'+chr(10)+'name']:
        assert s.request(url,'POST',{'author_name':name},'editor',h['ETag'])[0]==400
    set_status(s,row['id'],'approved');assert s.request(url)[2]['author_name']=='<Renamed>'
    s.restart();assert s.request(url+'?context=edit',role='editor')[2]['author']==s.ids['subscriber']
