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
    for state in ['approve','hold','spam','hold']:
        code,h,data=s.request(url,'PATCH',{'status':state},'editor',tag);assert code==200 and data['content']['raw']=='Text';tag=h['ETag']
    assert s.request('/wp-json/wp/v2/comments','PATCH',{},'editor')[0]==405
    assert 'PATCH' in s.request(url,'OPTIONS')[2]['methods']
