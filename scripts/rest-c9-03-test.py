from embed_fixture import *
with NativeSite() as s:
    p=post(s);row=comment(s,p)
    assert s.request(C+'/'+str(row['id']))[2]['_links']['author'][0]['href'].endswith('/users/'+str(s.ids['subscriber']))
