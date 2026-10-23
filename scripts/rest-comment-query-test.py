from rest_fixture import NativeSite
with NativeSite() as s:
    _,_,post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Discussion filters','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments'
    ids=[]
    for role,text,label,approved in [('subscriber','Alpha text','Reader',True),('contributor','Beta native','Other',True),('subscriber','secret pending','Reader',False)]:
        status,h,row=s.request(route,'POST',{'post':post['id'],'content':text,'author_name':label},role)
        assert status==201;ids.append(row['id'])
        if approved:assert s.request(route+'/'+str(row['id']),'POST',{'status':'approved'},'editor',h['ETag'])[0]==200
    assert [r['id'] for r in s.request(route+'?search=ALPHA')[2]]==ids[:1]
    assert s.request(route+'?search=Reader')[1]['X-WP-Total']=='1'
    assert s.request(route+'?search=secret')[2]==[]
    assert len(s.request(route+'?context=edit&search=secret',role='subscriber')[2])==1
    assert s.request(route+'?context=edit&search=secret',role='contributor')[2]==[]
    assert s.request(route+'?search='+('x'*257))[0]==400
    assert s.request(route+'/'+str(ids[0])+'?search=Alpha')[0]==400
    assert [r['id'] for r in s.request(route+'?orderby=id&order=desc')[2]]==list(reversed(ids[:2]))
    assert s.request(route+'?orderby=id&order=desc&per_page=1')[2][0]['id']==ids[1]
    assert s.request(route+'?orderby=date&order=asc')[2][0]['id']==ids[0]
    assert s.request(route+'?order=bad')[0]==400 and s.request(route+'?orderby=private')[0]==400
print('Native comment query filters preserve approved/parent visibility, ownership scope, counts and strict bounds.')
