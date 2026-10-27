from rest_fixture import NativeSite,run
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,_,row=s.request(route,'POST',{'title':'Assigned','author':s.ids['author']},'administrator')
    assert code==201 and row['author']==s.ids['author']
    assert s.request(route,'POST',{'title':'Self','author':s.ids['author']},'author')[0]==201
    assert s.request(route,'POST',{'title':'Denied','author':s.ids['administrator']},'author')[0]==403
    for value in [0,999,False,'2',-1,2.5]:assert s.request(route,'POST',{'title':'Invalid','author':value},'administrator')[0]==400
    run('access-change',s.site,s.revision,'revoke','contributor','-')
    assert s.request(route,'POST',{'title':'Revoked','author':s.ids['contributor']},'administrator')[0]==400
print('REST creation author assignment: active identities, self/other capabilities, types and revoked targets passed.')
