"""Read-only media subset compared against real WordPress in a disposable runner."""
import pathlib,json,subprocess,sys,base64,urllib.parse,html,hashlib
sys.path.insert(0,str(pathlib.Path('scripts').resolve()))
from rest_fixture import NativeSite
wordpress,work=map(pathlib.Path,sys.argv[1:]);manifest=work/'c7-media-manifest.json';output=work/'c7-media-core.json'
def ident(name):return (int(hashlib.sha256(('media\n'+name).encode()).hexdigest()[:8],16)&0x7fffffff) or 1
def slug(name):return 'media-'+name.encode().hex()
files=[{'name':'c7-alpha.png','mime':'image/png','base64':'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jSioAAAAASUVORK5CYII='},{'name':'c7-beta.gif','mime':'image/gif','base64':'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'},{'name':'c7-fake.png','mime':'application/octet-stream','base64':base64.b64encode(b'plain data').decode()}]
files.sort(key=lambda f:ident(f['name']))
queries=[]
def case(**args):
    params={'search':'c7-','orderby':'id','order':'asc','per_page':100};params.update(args);queries.append({'params':params})
case();case(order='desc');case(orderby='title');case(orderby='title',order='desc');case(search='C7-ALPHA');case(search='c7-missing')
for mime in ['image/png','image/gif','application/octet-stream','image/jpeg']:case(mime_type=[mime])
for kind in ['image','application','audio','video','text']:case(media_type=[kind])
case(media_type=['image'],mime_type=['application/octet-stream']);case(media_type=['application'],mime_type=['image/png']);case(media_type=['image','application']);case(mime_type=['image/png','image/gif'])
case(include=[0]);case(include=[2,0]);case(exclude=[1]);case(include=[1],exclude=[1]);case(include=[2,0,1],orderby='include',order='asc');case(include=[2,0,1],orderby='include',order='desc')
case(slug=[0]);case(slug=[0,2]);case(slug=[0],search='c7-missing')
case(per_page=1,page=2);case(per_page=1,page=2,offset=0);case(per_page=2,offset=1);case(offset=3);case(offset=3,page=9);case(per_page=1,page=9,offset=0);case(search='c7-missing',page=9)
manifest.write_text(json.dumps({'files':files,'queries':queries}));subprocess.run(['php','benchmarks/wordpress/media-oracle.php',wordpress,manifest,output],check=True)
core=json.loads(output.read_text());cmap={value:i for i,value in enumerate(core['ids'])};failures=[]
with NativeSite() as s:
    public=s.site/'public';public.mkdir()
    for f in files:(public/f['name']).write_bytes(base64.b64decode(f['base64']))
    route='/wp-json/wp/v2/media'
    for probe in core['queries']:
        params=dict(probe['query']['params'])
        for key in ['include','exclude']:
            if key in params:params[key]=[ident(files[i]['name']) for i in params[key]]
        if 'slug' in params:params['slug']=[slug(files[i]['name']) for i in params['slug']]
        # Exercise actual indexed-array URI parsing, not a Python-only query path.
        pairs=[]
        for key,value in params.items():
            if isinstance(value,list):pairs.extend((f'{key}[{i}]',part) for i,part in enumerate(value))
            else:pairs.append((key,value))
        code,h,rows=s.request(route+'?'+urllib.parse.urlencode(pairs));expected=probe['result']
        try:
            assert code==expected['code'],(code,expected['code'])
            if code==200:
                assert [r['id'] for r in rows]==[ident(files[cmap[r['id']]]['name']) for r in expected['data']]
                for key in ['X-WP-Total','X-WP-TotalPages']:assert int(h[key])==int(expected['headers'][key]),(key,h,expected['headers'])
        except (AssertionError,KeyError,TypeError) as e:failures.append(('query',params,str(e),rows,expected))
    for probe in core['details']:
        f=files[cmap[probe['id']]];code,h,row=s.request(route+'/'+str(ident(f['name']))+'?context='+probe['context']);theirs=probe['result']['data']
        try:
            assert code==probe['result']['code']==200
            assert row['slug']==slug(f['name']) # Native stable identity is intentionally independent.
            for key in ['mime_type','media_type']:assert row[key]==theirs[key]
            assert row['title']['rendered']==theirs['title']['rendered']
            assert urllib.parse.unquote(urllib.parse.urlsplit(row['source_url']).path).split('/')[-1]==urllib.parse.unquote(urllib.parse.urlsplit(theirs['source_url']).path).split('/')[-1]==f['name']
            for key in ['filename','filesize']:
                assert (key in row)==(key in theirs),(key,row,theirs)
                if key in row:assert row[key]==theirs[key],(key,row,theirs)
            assert not {'date','date_gmt','author','post','media_details','alt_text','caption','description','guid','status'}&set(row)
        except (AssertionError,KeyError,TypeError) as e:failures.append(('detail',f['name'],probe['context'],str(e),row,theirs))
assert not failures,json.dumps(failures,indent=2)
print(f'Actual WordPress core media: {len(queries)} collection queries and {len(core["details"])} view/embed details passed; ID/slug namespaces mapped independently.')
