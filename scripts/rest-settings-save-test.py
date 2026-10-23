import json
from rest_fixture import NativeSite,run
with NativeSite() as site:
    path=site.site/'site.json';path.unlink();route='/wp-json/moonpress/v1/settings'
    value={'base_url':'https://saved.example/','tag_index':True,'page_size':7}
    def save(data,**kw):return site.request(route,'POST',data,**kw)
    assert save({'settings':value})[0]==401
    for role in ['subscriber','contributor','author','editor']:assert save({'settings':value},role=role,etag='"absent"')[0]==403
    assert not path.exists()
    assert save({'settings':value},role='administrator')[0]==428
    for invalid in [{'settings':{'unknown':1}},{'settings':[]},{'settings':{'page_size':1001}},{'settings':value,'force':True},{}]:
        assert save(invalid,role='administrator',etag='"absent"')[0]==400
    assert save({'settings':value},role='administrator',etag='"'+'0'*64+'"')[0]==412
    assert not path.exists()
    status,h,row=save({'settings':value},role='administrator',etag='"absent"')
    assert status==200 and row['changed'] and row['exists'] and row['settings']==value
    assert site.request('/wp-json/')[2]['url']==value['base_url']
    before=path.read_bytes();stamp=path.stat().st_mtime_ns
    assert save({'settings':value},role='administrator',etag='"absent"')[0]==412
    status,h2,row=save({'settings':value},role='administrator',etag=h['ETag'])
    assert status==200 and not row['changed'] and h2['ETag']==h['ETag'] and path.read_bytes()==before and path.stat().st_mtime_ns==stamp
    # Semantic no-op preserves manually formatted source exactly.
    path.write_text(json.dumps(value,indent=4)+'\n');tag=site.request(route,role='administrator')[1]['ETag'];before=path.read_bytes()
    assert not save({'settings':value},role='administrator',etag=tag)[2]['changed'] and path.read_bytes()==before
    stage=site.site/'.moonpress-settings-edit';stage.write_text('retain me')
    assert save({'settings':{'tag_index':False}},role='administrator',etag=tag)[0]==500
    assert stage.read_text()=='retain me' and path.read_bytes()==before;stage.unlink()
    status,h,row=save({'settings':{}},role='administrator',etag=tag);assert status==200 and row['changed']
    assert site.request('/wp-json/')[2]['url']==f'http://127.0.0.1:{site.port}/'
    site.restart();assert site.request(route,role='administrator')[2]['settings']=={}
    backup=run('access-change',site.site,site.revision,'grant','backup','administrator')
    change=run('access-change',site.site,backup['report']['revision'],'revoke','administrator','-')
    assert save({'settings':value},role='administrator',etag=h['ETag'])[0]==401
print('Native settings updates: fresh admin gate, validated guarded writes, byte-preserving no-op, retained staging, restart and revocation passed.')
