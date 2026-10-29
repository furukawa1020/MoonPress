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
    wp='/wp-json/wp/v2/comments';item=s.request(wp+'/1','OPTIONS')[2];collection=s.request(wp,'OPTIONS')[2]
    assert set(item['methods'])=={'GET','HEAD','POST','PUT','PATCH','DELETE','OPTIONS'}
    assert set(collection['methods'])=={'GET','HEAD','POST','OPTIONS'}
    assert set(item['endpoints'][0]['args']['context']['enum'])=={'view','embed','edit'}
    properties=item['schema']['properties'];assert properties['content']['properties']['raw']['context']==['edit']
    assert not properties['author_name']['readonly'] and properties['author']['readonly']
    for verb in ['POST','PUT','PATCH']:
        fields=next(e['args'] for e in item['endpoints'] if e['methods']==[verb]);assert set(fields)=={'context','status','author_name','content'}
    assert s.request('/wp-json/')[2]['routes']['/moonpress/v1/comments/(?P<id>[0-9]+)']['methods']==s.request(route+'/1','OPTIONS')[2]['methods']
    assert item['moonpress']['item_writes_require_if_match'] and not item['moonpress']['permanent_delete']
    assert s.request('/wp-json/')[2]['routes']['/wp/v2/comments/(?P<id>[0-9]+)']['methods']==item['methods']
