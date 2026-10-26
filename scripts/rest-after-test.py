from rest_fixture import NativeSite
from urllib.parse import urlencode
import json
with NativeSite() as s:
    for i,day in [(11,'2020-01-01'),(12,'2020-01-02'),(13,'2020-01-03')]:
        for kind in ['post','page']:
            f={'title':'Dated','wp_id':i+(100 if kind=='page' else 0),'date':day,'kind':kind}
            (s.site/'content'/f'{kind}-{i}.md').write_text('---\n'+json.dumps(f)+'\n---\nBody')
    (s.site/'content/draft.md').write_text('---\n'+json.dumps({'title':'Hidden','wp_id':99,'date':'2020-01-04','draft':True})+'\n---\nBody')
    for kind,base in [('posts',0),('pages',100)]:
        route='/wp-json/wp/v2/'+kind
        for bound in ['2020-01-02T00:00:00Z','2020-01-02T00:00:00','2020-01-02T09:00:00+09:00','2020-01-01T19:00:00-05:00']:
            status,h,rows=s.request(route+'?'+urlencode({'after':bound}))
            assert status==200 and [r['id'] for r in rows]==[13+base],(bound,status,rows)
            assert h['X-WP-Total']=='1' and h['X-WP-TotalPages']=='1'
        assert s.request(route+'?after=2020-01-03T00:00:00Z')[2]==[]
        for bound in ['bad','2020-02-30T00:00:00Z','2020-01-01T25:00:00Z','2020-01-01T00:00:00+24:00']:
            assert s.request(route+'?'+urlencode({'after':bound}))[0]==400
        args=s.request(route,'OPTIONS')[2]['endpoints'][0]['args']
        assert args['after']['format']=='date-time'
print('REST after: exclusive boundaries, offsets, pages/posts, counts and hidden drafts passed.')
