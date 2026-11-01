from user_read_fixture import *
with NativeSite() as s:
    post(s,'author')
    row=s.request(U+'/'+str(s.ids['author']))[2]
    assert row['_links']['self'][0]['href'].endswith(U+'/'+str(s.ids['author']))
    assert row['_links']['collection'][0]['href'].endswith(U)
    assert s.request(U+'/me?context=edit',role='subscriber')[2]['_links']['self'][0]['href'].endswith('/'+str(s.ids['subscriber']))
    assert '_links' in s.request(U+'?context=embed')[2][0]
