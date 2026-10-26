from rest_fixture import NativeSite
import json,pathlib,sys
from html.parser import HTMLParser
class Cells(HTMLParser):
    def __init__(self):super().__init__();self.rows=[];self.cell=None
    def handle_starttag(self,tag,attrs):
        if tag in ['th','td']:
            a=dict(attrs);align=a.get('data-align','')
            if a.get('class','').startswith('has-text-align-'):align=a['class'][15:]
            if 'text-align:' in a.get('style','').replace(' ',''):align=a['style'].replace(' ','').split('text-align:')[1].rstrip(';')
            self.cell=[tag,align,'']
    def handle_data(self,text):
        if self.cell is not None:self.cell[2]+=text
    def handle_endtag(self,tag):
        if tag in ['td','th'] and self.cell is not None:self.rows.append(self.cell);self.cell=None
samples=[]
for align in ['left','center','right']:
    for attr in [f'style="text-align: {align};"',f'class="has-text-align-{align}" data-align="{align}"']:
        samples.append('<table><thead><tr><th '+attr+'>Name</th></tr></thead><tbody><tr><td '+attr+'>A &amp; 月</td></tr></tbody></table>')
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    pairs=[(source,source) for source in samples]
    if len(sys.argv)>1:pairs+=json.loads(pathlib.Path(sys.argv[1]).read_text())
    for source,expected in pairs:
        code,h,row=s.request(route,'POST',dict(title='Aligned',content=source),'author');assert code==201,(source,code,row)
        ours=Cells();ours.feed(row['content']['rendered']);theirs=Cells();theirs.feed(expected)
        assert ours.rows==theirs.rows,(ours.rows,theirs.rows)
    before={p.name:p.read_bytes() for p in (s.site/'content').glob('*.md')}
    for attr in ['style="text-align:left;color:red"','style="background:url(javascript:x)"','class="has-text-align-left" data-align="right"','onclick="bad"','data-align="justify"']:
        source='<table><tr><th '+attr+'>A</th></tr><tr><td>B</td></tr></table>'
        assert s.request(route,'POST',dict(title='Rejected',content=source),'author')[0]==400
    assert s.request(route,'POST',dict(title='Rejected',content='<table><tr><th style="text-align:center">A</th></tr><tr><td>B</td></tr></table>'),'author')[0]==400
    assert before=={p.name:p.read_bytes() for p in (s.site/'content').glob('*.md')}
print('Native table alignment: style/class/data forms preserve per-column cell semantics; conflicting, mixed and unsafe attributes refused.')
