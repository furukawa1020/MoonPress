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
    code,h,row=s.request(route,'POST',{'post':a['id'],'author_name':'R','content':'Pending'},'subscriber')
    assert code==201 and h['Location']==route+'/'+str(row['id'])+'?context=edit'
    assert s.request(h['Location'],role='subscriber')[2]==row
    assert s.request(h['Location'])[0]==401 and s.request(route+'/'+str(row['id']))[0]==404
    code,h,envelope=s.request(route+'?_envelope=1','POST',{'post':a['id'],'author_name':'R','content':'Next'},'subscriber');assert envelope['status']==201 and 'Location' in envelope['headers']
