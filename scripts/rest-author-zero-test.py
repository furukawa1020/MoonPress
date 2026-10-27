from rest_fixture import NativeSite
import json
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    (s.site/'content/legacy.md').write_text('---\n'+json.dumps({'wp_id':99,'title':'Legacy','date':'2020-01-01'})+'\n---\nBody')
    code,_,row=s.request(route,'POST',{'title':'Owned','status':'publish'},'author');assert code==201
    assert [r['id'] for r in s.request(route+'?author=0')[2]]==[99]
    assert [r['id'] for r in s.request(route+'?author_exclude=0')[2]]==[row['id']]
    assert len(s.request(route+'?author=0,'+str(s.ids['author']))[2])==2
    for value in ['-1','1.5','2147483648','x']:
        assert s.request(route+'?author='+value)[0]==400
    assert s.request(route+'?include=0')[0]==400
print('Author zero filters select legacy ownership without relaxing positive article identity rules.')
