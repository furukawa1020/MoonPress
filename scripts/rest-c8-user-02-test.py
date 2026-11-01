from user_read_fixture import *
with NativeSite() as s:
    assert s.request(U)[2]==[]
    code,h,rows=s.request(U,role='administrator')
    assert code==200 and {r['id'] for r in rows}==set(s.ids.values()) and h['X-WP-Total']=='5'
    assert all(set(r)=={'id','name','slug','_links'} for r in rows)
    assert s.request(U,role='editor')[2]==[]
    run('access-change',s.site,s.revision,'revoke','subscriber','-')
    assert len(s.request(U,role='administrator')[2])==4
