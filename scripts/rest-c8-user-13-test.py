from user_read_fixture import *
with NativeSite() as s:
    wanted=['editor','subscriber','administrator'];ids=','.join(str(s.ids[r]) for r in wanted)
    for direction in ['asc','desc']:
        rows=s.request(U+'?include='+ids+'&orderby=include&order='+direction,role='administrator')[2]
        assert [r['slug'] for r in rows]==(wanted if direction=='asc' else list(reversed(wanted)))
    assert s.request(U+'?orderby=include',role='administrator')[0]==400
    assert s.request(U+'?include='+str(s.ids['subscriber'])+'&exclude='+str(s.ids['subscriber']),role='administrator')[2][0]['slug']=='subscriber'
