"""Real native operator inventory queries, links and immutable source snapshots."""
import functools,html,json,re,sys,urllib.parse
from rest_fixture import NativeSite
from operator_fixture import Operator
stage=int(sys.argv[1]) if len(sys.argv)>1 else 20
rows=[]
for i in range(24):
    row={'name':f'p{i:02}.md','title':(['Needle <script>&','Same','Same','Zebra'][i] if i<4 else f'Title {i:02}'),
         'kind':'page' if i%7==0 else 'post','draft':i%3==0,'listed':i%5!=0,
         'tags':['月 & "','needle'] if i%2==0 else ['other'],'slug':f'output-{i:02}'}
    if i%4:row['date']=f'2026-01-{i%3+1:02}'
    if i==0:row['tags']+=['release\tnotes','line\nbreak']
    rows.append(row)
def names(page):
    table=re.search(r'<tbody>(.*?)</tbody>',page,re.S)[1]
    return [urllib.parse.unquote(n) for n in re.findall(r'<tr><td><a href="/edit\?name=([^"]+)"',table)]
def expected(selected,sort='source',size=20,page=1):
    def compare(a,b):
        if sort.startswith('date'):
            x,y=a.get('date'),b.get('date')
            result=(x is None)-(y is None)
            if not result and x and y:result=((x>y)-(x<y))*(-1 if sort=='date_desc' else 1)
        elif sort.startswith('title'):
            x,y=a['title'].lower(),b['title'].lower();result=((x>y)-(x<y))*(-1 if sort=='title_desc' else 1)
        else:result=0
        if not result:result=(a['name']>b['name'])-(a['name']<b['name'])
        if sort=='source_desc':result=-result
        return result
    return [r['name'] for r in sorted(selected,key=functools.cmp_to_key(compare))[(page-1)*size:page*size]]
with NativeSite() as site:
    for row in rows:
        metadata={k:v for k,v in row.items() if k!='name'}
        (site.site/'content'/row['name']).write_text('---\n'+json.dumps(metadata,ensure_ascii=False)+'\n---\n# Body\n')
    (site.site/'content/broken.md').write_text('---\n{bad}\n---\nBroken')
    before={p.name:p.read_bytes() for p in (site.site/'content').iterdir()}
    with Operator(site.site) as o:
        def get(query=None,lang='en'):
            code,page=o.request('/?'+urllib.parse.urlencode(query or {}),headers={'Accept-Language':lang})
            assert code==200,(query,code,page[-1500:])
            return page
        assert names(get())==expected(rows)
        assert 'Repair source' in get() and 'broken.md' in get()
        assert '&lt;script&gt;&amp;' in get() and '<script>' not in get()
        for order in ['date_desc','date_asc']:
            assert names(get({'sort':order}))==expected(rows,order),(order,names(get({'sort':order})),expected(rows,order))
        for q in [{'sort':'unknown'},{'extra':'x'},{'page':'0'},{'page':'99999999'}]:assert o.request('/?'+urllib.parse.urlencode(q))[0]==400,q
        if stage>=2:
            for order in ['title','title_desc']:assert names(get({'sort':order}))==expected(rows,order),(order,names(get({'sort':order})),expected(rows,order))
        if stage>=3:assert names(get({'sort':'source_desc'}))==expected(rows,'source_desc')
        if stage>=4:
            fields={'q':'title','sort':'date_desc','per_page':'3','page':'2'}
            selected=[r for r in rows if 'title' in r['title'].lower()]
            page=get(fields);assert names(page)==expected(selected,'date_desc',3,2)
            links=[html.unescape(a) for a in re.findall(r'<a rel="(?:prev|next)" href="([^"]+)"',page)]
            assert len(links)==2
            for link in links:
                params=urllib.parse.parse_qs(urllib.parse.urlsplit(link).query)
                assert params['q']==['title'] and params['sort']==['date_desc'] and params['per_page']==['3']
            for value in ['0','101','-1','1.5','bad']:assert o.request('/?per_page='+value)[0]==400
            assert o.request('/?per_page=3&page=9')[0]==400
            assert len(names(get({'per_page':100})))==24
        if stage>=5:
            assert names(get({'tag':'月 & "'}))==expected([r for r in rows if '月 & "' in r['tags']])
            assert names(get({'tag':'月'}))==[] and names(get({'tag':''}))==expected(rows)
            for tag in ['x'*97]:assert o.request('/?'+urllib.parse.urlencode({'tag':tag}))[0]==400
            for tag in ['release\tnotes','line\nbreak']:
                assert names(get({'tag':tag}))==['p00.md']
        if stage>=6:
            assert names(get({'visibility':'unlisted','state':'draft'}))==expected([r for r in rows if not r['listed'] and r['draft']])
            assert o.request('/?visibility=secret')[0]==400
        if stage>=7:
            assert names(get({'after':'2026-01-02'}))==expected([r for r in rows if r.get('date','')>='2026-01-02'])
            for value in ['2026-02-29','0000-01-01','2026-1-1']:assert o.request('/?after='+value)[0]==400
        if stage>=8:
            assert names(get({'before':'2026-01-02','after':'2026-01-02'}))==expected([r for r in rows if r.get('date')=='2026-01-02'])
            assert o.request('/?before=2026-02-30')[0]==400 and o.request('/?after=2026-02-01&before=2026-01-01')[0]==400
        if stage>=9:
            assert names(get({'dated':'undated'}))==expected([r for r in rows if 'date' not in r])
            assert names(get({'dated':'undated','after':'2026-01-01'}))==[]
            assert o.request('/?dated=bad')[0]==400
        if stage>=10:
            assert names(get({'q':'needle','scope':'title'}))==['p00.md']
            assert names(get({'q':'needle','scope':'tags'}))==expected([r for r in rows if 'needle' in r['tags']])
            assert names(get({'q':'p01.md','scope':'source'}))==['p01.md']
            assert names(get({'q':'p01.md','scope':'title'}))==[]
            for q in [{'scope':'body'},{'q':'あ'*86},{'q':'\n'}]:assert o.request('/?'+urllib.parse.urlencode(q))[0]==400
        if stage>=11:
            page=get({'tag':'needle','kind':'post','per_page':3,'page':2})
            navigation=re.search(r'<nav aria-label="Post states">(.*?)</nav>',page,re.S)[1]
            assert 'Drafts (3)' in navigation and 'Ready (7)' in navigation,navigation
            for href in re.findall('href="([^"]+)"',navigation):
                q=urllib.parse.parse_qs(urllib.parse.urlsplit(html.unescape(href)).query)
                assert q['tag']==['needle'] and q['kind']==['post'] and q['page']==['1']
        if stage>=12:
            page=get({'state':'draft','q':'title'})
            nav=re.search(r'<nav aria-label="Post types">(.*?)</nav>',page,re.S)[1]
            assert 'Pages (1)' in nav and 'Posts (5)' in nav,nav
            assert 'aria-current="page"' in nav
        if stage>=13:
            page=get();table=re.search('<tbody>(.*?)</tbody>',page,re.S)[1]
            assert '月 &amp; &quot;' in table
            assert 'tag=release%09notes' in table and 'tag=line%0Abreak' in table
            href=html.unescape(re.search(r'href="([^\"]*tag=%E6%9C%88[^\"]*)"',table)[1])
            assert names(o.request(href)[1])==expected([r for r in rows if '月 & "' in r['tags']])
        if stage>=14:assert '<time datetime="2026-01-02">2026-01-02</time>' in get() and 'Undated' in get()
        if stage>=15:assert '<code>output-00.html</code>' in get() and 'Planned output' in get()
        if stage>=16:assert 'href="/history?name=p00.md"' in get()
        if stage>=17:assert 'href="/references?name=p00.md"' in get()
        if stage>=18:
            page=get({'q':'unmatched'});assert 'Show all posts' in page and 'href="#new-draft"' in page and 'Range: 0–0 / 0' in page
            assert 'Range: 4–6 / 24' in get({'per_page':3,'page':2})
        if stage>=19:
            page=get({},'ja');assert '<summary>絞り込み・並び順</summary>' in page and '<th>記事の日付</th>' in page and '検索対象' in page and '日付なし' in page
            assert 'Search in' not in page and 'Previous posts' not in page
    assert before=={p.name:p.read_bytes() for p in (site.site/'content').iterdir()}
print('Operator article inventory passed: stable ordering, bounded queries, retained navigation, metadata and unchanged sources.')
