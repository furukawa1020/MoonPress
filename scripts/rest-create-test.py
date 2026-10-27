#!/usr/bin/env python3
import json,pathlib
from rest_fixture import NativeSite,run
with NativeSite() as fixture:
    posts='/wp-json/wp/v2/posts';pages='/wp-json/wp/v2/pages'
    assert fixture.request(posts,'POST',{'title':'Anonymous'})[0]==401
    assert fixture.request(posts,'POST',{'title':'Denied'},'subscriber')[0]==403
    assert fixture.request(pages,'POST',{'title':'Denied'},'author')[0]==403
    assert not (fixture.site/'.moonpress-identities').exists()
    for data in [{'title':''},{'title':'No','content':'<script>x</script>'},{'title':'No','slug':'../escape'},{'title':'No','date_gmt':'bad'},{'title':'No','status':'future'}]:
        assert fixture.request(posts,'POST',data,'author')[0]==400,data
    assert not (fixture.site/'.moonpress-identities').exists()
    assert fixture.request(posts,'POST',{'title':'No','author':1},'author')[0]==403
    assert fixture.request(posts,'POST',{'title':'No','status':'publish'},'contributor')[0]==403
    created=fixture.request(posts,'POST',{'title':'First post','content':'<p>Safe &amp; text</p>'},'contributor')
    assert created[0]==201 and created[2]['status']=='draft' and created[2]['author']==fixture.ids['contributor']
    identifier=created[2]['id'];etag=created[1]['ETag'];assert created[1]['Location']==posts+'/'+str(identifier)
    path=fixture.site/'content/first-post.md';assert path.stat().st_mode&0o777==0o600
    assert fixture.request(posts+'/'+str(identifier))[0]==404
    assert fixture.request(posts+'/'+str(identifier)+'?context=edit',role='contributor')[1]['ETag']==etag
    clock=created[2]['date_gmt'];assert clock[:4]>'2020'
    more=fixture.request(posts,'POST',{'title':'First post','status':'publish'},'author');assert more[0]==201 and more[2]['slug']=='first-post-2'
    assert more[2]['id']>identifier and more[2]['author']==fixture.ids['author']
    future=fixture.request(pages,'POST',{'title':'Page','status':'future','date_gmt':'2099-01-01T00:00:00'},'editor');assert future[0]==201 and future[2]['status']=='future'
    projected=fixture.request(posts+'?_fields=id','POST',{'title':'Selected'},'author');assert projected[0]==201 and set(projected[2])=={'id'} and 'Location' in projected[1]
    # Reserved IDs survive source loss and process restart; gaps are never reused.
    latest=projected[2]['id'];(fixture.site/'content/selected.md').unlink()
    fixture.restart()
    again=fixture.request(posts,'POST',{'title':'After deletion'},'author');assert again[0]==201 and again[2]['id']>latest
    legacy=fixture.site/'content/legacy.md';legacy.write_text('---\n{\"wp_id\":100000,\"title\":\"Legacy\",\"draft\":true}\n---\nLegacy')
    snapshot=run('read',fixture.site,'legacy.md');run('trash-post',fixture.site,'legacy.md',snapshot['digest'])
    assert fixture.request(posts,'POST',{'title':'Beyond legacy trash'},'author')[2]['id']>100000
    vault=fixture.site/'.moonpress-identities';assert vault.stat().st_mode&0o777==0o700
    record=sorted(vault.iterdir())[0];original=record.read_bytes();record.chmod(0o644)
    before={p.name:p.read_bytes() for p in (fixture.site/'content').iterdir()}
    assert fixture.request(posts,'POST',{'title':'Bad log'},'author')[0]==500
    assert before=={p.name:p.read_bytes() for p in (fixture.site/'content').iterdir()};record.chmod(0o600)
    record.write_bytes(original.replace(b'"schema":1',b'"schema":9'));assert fixture.request(posts,'POST',{'title':'Bad log'},'author')[0]==500;record.write_bytes(original)
    run('access-change',fixture.site,fixture.revision,'revoke','author','-')
    assert fixture.request(posts,'POST',{'title':'Revoked'},'author')[0]==401
print('REST creation passed: roles, bound ownership, safe content, unique slugs, durable nonreused IDs, private mode, bad-log refusal and revocation.')
