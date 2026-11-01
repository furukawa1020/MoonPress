from user_read_fixture import *
with NativeSite() as s:
    assert s.request(U+'?context=edit')[0]==401
    assert s.request(U+'?context=edit',role='editor')[0]==403
    code,h,rows=s.request(U+'?context=edit&per_page=2',role='administrator')
    assert code==200 and len(rows)==2 and h['X-WP-Total']=='5'
    assert all('username' in r and 'roles' in r for r in rows)
    row=s.request(U+'?context=edit&include='+str(s.ids['subscriber']),role='administrator')[2][0]
    assert row['roles']==['subscriber']
