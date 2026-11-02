from embed_fixture import *
with NativeSite() as s:
    p=post(s);row=comment(s,p);url=C+'/'+str(row['id'])+'?_embed=author'
    err=s.request(url)[2]['_embedded']['author'][0];assert err['data']['status']==404 and 'roles' not in err
    for role in ['subscriber','administrator']:
        value=s.request(url,role=role)[2]['_embedded']['author'][0]
        assert value['id']==s.ids['subscriber'] and 'roles' not in value
    assert s.request(url,headers={'Authorization':'Basic invalid'})[0]==401
