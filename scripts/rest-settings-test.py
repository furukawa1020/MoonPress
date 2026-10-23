import json
from rest_fixture import NativeSite
with NativeSite() as site:
    (site.site/'site.json').unlink()
    route='/wp-json/moonpress/v1/settings'
    assert site.request(route)[0]==401
    for role in ['subscriber','contributor','author','editor']:assert site.request(route,role=role)[0]==403
    status,h,row=site.request(route+'/',role='administrator')
    assert status==200 and row['settings']=={} and not row['exists'] and h['ETag']=='"absent"'
    assert not (site.site/'site.json').exists()
    (site.site/'site.json').write_text(json.dumps({'base_url':'https://new.example/','tag_index':True})+'\n')
    status,h,row=site.request(route,role='administrator');assert status==200 and row['settings']['tag_index'] and h['ETag']=='"'+row['revision']+'"'
    assert site.request('/wp-json/')[2]['url']=='https://new.example/'
    assert site.request(route,'HEAD',role='administrator')[2] is None
    assert site.request(route+'?raw=true',role='administrator')[0]==400
    assert site.request(route,'OPTIONS')[2]['methods']==['GET','HEAD','POST','OPTIONS']
print('Native settings reads: administrator gate, absent/read-only semantics, validated values, version headers and fresh base URLs passed.')
