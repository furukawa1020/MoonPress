#!/usr/bin/env python3
import json,pathlib,sys
from rest_fixture import NativeSite,run
oracle=json.loads(pathlib.Path(sys.argv[1]).read_text()) if len(sys.argv)>1 else None
with NativeSite() as fixture:
    rows=[]
    for role in ['administrator','subscriber','contributor','author','editor']:
        for kind in ['post','page']:
            for published in [False,True]:
                for own in [True,False]:
                    identifier=1000+len(rows);name=f'article-{identifier}.md';path=fixture.site/'content'/name
                    metadata={'wp_id':identifier,'author':fixture.ids[role] if own else 100,'kind':kind,'draft':not published,'title':'Trash oracle'}
                    path.write_text('---\n'+json.dumps(metadata)+'\n---\nBody\n')
                    allowed=role in ['administrator','editor'] or (own and kind=='post' and (role=='author' or (role=='contributor' and not published)))
                    rows.append(dict(role=role,kind=kind,published=published,own=own,allowed=allowed,id=identifier,name=name))
    if oracle:
        for row,expected in zip(rows,oracle):
            assert row['allowed']==expected['delete_allowed'] and all(row[key]==expected[key] for key in ['role','kind','published','own'])
    for row in rows:
        resource='/wp-json/wp/v2/'+('pages' if row['kind']=='page' else 'posts')+'/'+str(row['id'])
        path=fixture.site/'content'/row['name'];before=path.read_bytes();version=run('read',fixture.site,row['name'])['digest'];etag='"'+version+'"'
        assert fixture.request(resource,'DELETE',role=None,etag=etag)[0]==401
        if not row['allowed']:
            assert fixture.request(resource,'DELETE',role=row['role'],etag=etag)[0]==403
            assert path.read_bytes()==before;continue
        assert fixture.request(resource,'DELETE',role=row['role'])[0]==428
        assert fixture.request(resource,'DELETE',role=row['role'],etag='"'+'0'*64+'"')[0]==412
        assert fixture.request(resource+'?force=true','DELETE',role=row['role'],etag=etag)[0]==400
        assert path.read_bytes()==before
        trashed=fixture.request(resource+'?force=false','DELETE',role=row['role'],etag=etag)
        assert trashed[0]==200 and trashed[2]['status']=='trash' and trashed[2]['id']==row['id'] and not path.exists()
        assert fixture.request(resource)[0]==404
        record=run('trash-read',fixture.site,trashed[2]['moonpress_trash_id'])
        assert record['content'].encode()==before
    # The local owner can restore the exact private record with its version guard.
    records=run('trash-list',fixture.site);record=records[0]
    run('trash-restore',fixture.site,record['id'],record['record_digest'])
    assert (fixture.site/'content'/record['name']).stat().st_mode&0o777==0o600
print('REST trash passed: 40 role/type/ownership/status cases, preconditions, private backup fidelity, no permanent purge and local guarded restoration.')
