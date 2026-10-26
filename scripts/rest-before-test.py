from rest_fixture import NativeSite
from urllib.parse import urlencode
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    ids=[]
    for day in ['2020-01-01','2020-01-02','2020-01-03']:
        status,_,row=s.request(route,'POST',{'title':day,'status':'publish','date_gmt':day+'T00:00:00'},'author')
        assert status==201;ids.append(row['id'])
    def select(**params):return s.request(route+'?'+urlencode(params))
    status,h,rows=select(before='2020-01-02T09:00:00+09:00')
    assert status==200 and [r['id'] for r in rows]==ids[:1] and h['X-WP-Total']=='1'
    assert [r['id'] for r in select(after='2020-01-01T00:00:00Z',before='2020-01-03T00:00:00Z')[2]]==ids[1:2]
    assert select(after='2020-01-03T00:00:00Z',before='2020-01-01T00:00:00Z')[2]==[]
    assert select(before='invalid')[0]==400
    assert 'before' in s.request(route,'OPTIONS')[2]['endpoints'][0]['args']
print('REST before: exclusive date bounds, combined intervals and empty intersections passed.')
