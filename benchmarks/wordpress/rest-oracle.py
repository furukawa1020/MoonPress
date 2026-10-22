"""Compare native wire JSON with actual core REST handler fixture responses."""
import html, http.client, json, pathlib, re, socket, subprocess, sys, time
wordpress, work=map(pathlib.Path,sys.argv[1:])
cli=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
oracle=work/'rest-core.json'
subprocess.run(['php','benchmarks/wordpress/rest-oracle.php',wordpress,oracle],check=True)
core=json.loads(oracle.read_text());expected=json.loads((work/'oracle.json').read_text())
site=work/'rest-site';subprocess.run([cli,'init',site],check=True,stdout=subprocess.DEVNULL)
for source in (site/'content').glob('*.md'):source.unlink()
for row in expected:
    metadata,body=row['source'][4:].split('\n---\n',1)
    fields=json.loads(metadata);fields['wp_id']=core['ids'][row['slug']]['id'];fields['author']=core['ids'][row['slug']]['author']
    (site/'content'/f"{row['slug']}.md").write_text('---\n'+json.dumps(fields,ensure_ascii=False)+'\n---\n'+body)
listener=socket.socket();listener.bind(('127.0.0.1',0));port=listener.getsockname()[1];listener.close()
process=subprocess.Popen([cli,'rest',site,str(port)],stdout=subprocess.DEVNULL)
def request(path):
    connection=http.client.HTTPConnection('127.0.0.1',port,timeout=6);connection.request('GET',path)
    response=connection.getresponse();data=response.read();connection.close()
    if response.status!=200:raise ValueError(f'Native REST failed {response.status}: {data!r}')
    return json.loads(data)
def text(value):return ' '.join(html.unescape(re.sub('<[^>]+>',' ',value)).split())
try:
    for attempt in range(100):
        try:request('/wp-json/');break
        except OSError:time.sleep(.03)
    else:raise ValueError('Native REST listener unavailable')
    for row in expected:
        collection='pages' if row['kind']=='page' else 'posts'
        native=request('/wp-json/wp/v2/'+collection+'?slug='+row['slug'])
        actual=core['responses'][row['slug']]
        if len(native)!=len(actual):raise ValueError('REST visibility differs: '+row['slug'])
        for ours,theirs in zip(native,actual):
            for field in ['id','date','date_gmt','slug','status','type','author']:
                if ours[field]!=theirs[field]:raise ValueError(f'REST {field} differs for '+row['slug'])
            for field in ['title','content','excerpt']:
                if text(ours[field]['rendered'])!=text(theirs[field]['rendered']):raise ValueError(f'REST rendered {field} text differs for '+row['slug'])
            if request('/wp-json/wp/v2/'+collection+'/'+str(ours['id']))!=ours:raise ValueError('Native detail differs from collection')
finally:
    process.terminate();process.wait(timeout=8)
print('Native REST wire responses match actual WordPress core: IDs/dates/slug/type/status/author and rendered title/content/excerpt text; draft/future/unlisted excluded.')
