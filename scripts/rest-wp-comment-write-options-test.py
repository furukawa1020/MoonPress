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
    wp='/wp-json/wp/v2/comments';schema=s.request(wp,'OPTIONS')[2]
    assert set(schema['methods'])=={'GET','HEAD','POST','OPTIONS'}
    write=next(e for e in schema['endpoints'] if e['methods']==['POST'])['args'];assert write['post']['required'] and write['content']['required'] and 'author' not in write
    assert schema['moonpress']['creation_status']=='hold'
    assert 'POST' in s.request(wp+'/1','OPTIONS')[2]['methods']
    assert 'POST' in s.request('/wp-json/')[2]['routes']['/wp/v2/comments']['methods']
    assert s.request(wp+'?context=edit',role='editor')[0]==200
