from user_read_fixture import *
with NativeSite() as s:
    ident=str(s.ids['subscriber'])
    assert [r['slug'] for r in s.request(U+'?search='+ident+'&search_columns=id',role='administrator')[2]]==['subscriber']
    assert s.request(U+'?search='+ident+'&search_columns=name',role='administrator')[2]==[]
    assert [r['slug'] for r in s.request(U+'?search=AUTH&search_columns[]=name&search_columns[]=slug',role='administrator')[2]]==['author']
    assert s.request(U+'?search=author&search_columns=email',role='administrator')[0]==400
