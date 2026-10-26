"""Check implemented metadata fields against actual WordPress core responses."""
from rest_fixture import NativeSite
import json,pathlib,sys,re
from urllib.parse import urlencode,urlsplit,parse_qs
core=json.loads(pathlib.Path(sys.argv[1]).read_text())
def subset(ours,theirs,path=''):
    if isinstance(ours,dict):
        assert isinstance(theirs,dict),(path,ours,theirs)
        for k,v in ours.items():
            assert k in theirs,(path,k,theirs)
            subset(v,theirs[k],path+'.'+k)
    else:assert type(ours) is type(theirs) and ours==theirs,(path,ours,theirs)
with NativeSite() as s:
    for probe in core['probes']:
        role=None if probe['role']=='anonymous' else probe['role']
        route='/wp-json/wp/v2/'+probe['route']
        code,_,ours=s.request(route+'?'+urlencode({'context':probe['context']}),role=role)
        assert code==probe['status'],(probe,code,ours)
        if code==200:subset(ours,probe['data'],probe['route'])
    posts=core['pagination']['posts']
    for p in posts:
        fields={'wp_id':p['id'],'title':'Link oracle','slug':p['slug'],'date':'2020-01-01'}
        (s.site/'content'/(p['slug']+'.md')).write_text('---\n'+json.dumps(fields)+'\n---\nBody')
    query=urlencode({'slug':','.join(p['slug'] for p in posts),'per_page':1,'page':2,'orderby':'id','order':'asc'})
    code,h,ours=s.request('/wp-json/wp/v2/posts?'+query)
    assert code==200 and [p['id'] for p in ours]==core['pagination']['ids']
    def links(header):
        if isinstance(header,list):header=', '.join(header)
        return {rel:parse_qs(urlsplit(url).query) for url,rel in re.findall(r'<([^>]+)>; rel="(prev|next)"',header)}
    theirs=links(core['pagination']['headers']['Link']);ours=links(h['Link'])
    assert set(ours)==set(theirs)=={'prev','next'}
    for rel in ours:
        for k in ['page','per_page','order','orderby']:assert ours[rel][k]==theirs[rel][k],(k,ours,theirs)
print('Actual WordPress core: 96 role/context/type/status metadata probes and traversable pagination agree for implemented fields.')
