"""Public universal search projection and visibility over native HTTP."""
import json,urllib.parse
from rest_fixture import NativeSite
with NativeSite() as site:
    for identifier,title,extra in [(101,'Needle post <safe>',{}),(102,'Needle page',{'kind':'page'}),(103,'Needle draft',{'draft':True}),(104,'Needle future',{'publish_at':'2099-01-01T00:00:00Z'}),(105,'Needle unlisted',{'listed':False}),(106,'Other public',{})]:
        fields={'wp_id':identifier,'title':title,'date':'2020-01-01',**extra}
        (site.site/'content'/f'article-{identifier}.md').write_text('---\n'+json.dumps(fields)+'\n---\nBody visible text')
    route='/wp-json/wp/v2/search'
    status,headers,rows=site.request(route+'?search=Needle')
    assert status==200 and headers['X-WP-Total']=='2' and {r['id'] for r in rows}=={101,102}
    assert all(set(r)=={'id','title','url','type','subtype'} and r['type']=='post' for r in rows)
    assert next(r for r in rows if r['id']==101)['title']=='Needle post &lt;safe&gt;'
    assert {r['subtype'] for r in rows}=={'post','page'}
    assert [r['id'] for r in site.request(route+'?search=Needle&subtype=page')[2]]==[102]
    assert {r['id'] for r in site.request(route+'?subtype=post,page&include=101,102,103,104,105')[2]}=={101,102}
    assert site.request(route+'?include=103,104,105',role='administrator')[2]==[]
    assert [r['id'] for r in site.request(route+'?include=101,102&exclude=102')[2]]==[101]
    assert site.request(route+'?context=embed&include=101')[2]==site.request(route+'?include=101')[2]
    assert set(site.request(route+'?include=101&_fields=id,title')[2][0])=={'id','title'}
    status,headers,rows=site.request(route+'?per_page=1&page=2')
    assert status==200 and headers['X-WP-Total']=='3' and headers['X-WP-TotalPages']=='3' and len(rows)==1
    status,head_headers,body=site.request(route+'?search=Needle','HEAD')
    assert status==200 and head_headers['X-WP-Total']=='2' and body is None
    for query in ['type=term','subtype=attachment','subtype=any,post','context=edit','page=0','per_page=101','page=100','search='+urllib.parse.quote('x '*17),'include=no','unknown=1','orderby=relevance']:
        assert site.request(route+'?'+query)[0]==400,query
    status,headers,value=site.request(route,'POST',data={})
    assert status==405 and headers['Allow']=='GET, HEAD, OPTIONS'
    assert site.request(route,'OPTIONS')[2]['methods']==['GET','HEAD','OPTIONS']
    assert '/wp/v2/search' in site.request('/wp-json/')[2]['routes']
print('REST universal search passed: public visibility before filtering/counts, post/page types, projection, pagination, HEAD and strict parameters.')
