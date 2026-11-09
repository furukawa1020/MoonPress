"""Exercise the real native unified editor, including atomic writes and retained inputs."""
import base64,hashlib,html,json,pathlib,re,sys
from html.parser import HTMLParser
from operator_fixture import Operator
from rest_fixture import NativeSite
stage=int(sys.argv[1]) if len(sys.argv)>1 else 20
class Fields(HTMLParser):
    def __init__(self,page):
        super().__init__(convert_charrefs=True);self.active=False;self.values={};self.text=None;self.select=None;self.option=None;self.feed(page)
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='form':self.active=a.get('action')=='/compose-save'
        if not self.active:return
        if tag=='input' and 'name' in a:self.values[a['name']]=a.get('value','')
        if tag=='textarea':self.text=[a.get('name'),[]]
        if tag=='select':self.select=a['name'];self.values[self.select]=None
        if tag=='option' and self.select:
            if self.values[self.select] is None or 'selected' in a:self.values[self.select]=a.get('value','')
    def handle_data(self,data):
        if self.active and self.text:self.text[1].append(data)
    def handle_endtag(self,tag):
        if tag=='textarea' and self.text:
            key,parts=self.text;text=''.join(parts);self.values[key]=text[1:] if text.startswith('\n') else text;self.text=None
        if tag=='select':self.select=None
        if tag=='form':self.active=False
    def fields(self):return {**self.values,'intent':'save'}
def values(page):
    fields=Fields(page).fields();assert 'body' in fields,page[-1000:];return fields
with NativeSite() as site:
    article=site.site/'content/article.md'
    meta={'title':'Original','description':'Original excerpt','date':'2026-01-01','tags':['initial','release\tnotes'],'categories':['One'],'slug':'original','listed':False,'layout':'alt.html','kind':'post','draft':False,'wp_id':77,'author':site.ids['author']}
    original='---\n'+json.dumps(meta)+'\n---\n\n\n# Starting\n'
    article.write_text(original)
    for name in ['index','guide']:(site.site/'content'/f'{name}.md').write_text('# '+name)
    (site.site/'layouts').mkdir(exist_ok=True);(site.site/'layouts/alt.html').write_bytes((site.site/'layout.html').read_bytes())
    def saved():
        text=article.read_text();return json.loads(text.split('---\n',2)[1]),text.split('---\n',2)[2]
    def digest():return hashlib.sha256(article.read_bytes()).hexdigest()
    with Operator(site.site) as o:
        def get():
            code,page=o.request('/compose?name=article.md');assert code==200,(code,page[-1500:]);return page
        def send(f,expected=200):
            code,page=o.request('/compose-save','POST',f);assert code==expected,(code,expected,page[-2500:]);return page
        initial=article.read_bytes();page=get();f=values(page)
        assert f['body']=='\n\n# Starting\n' and f['version']==digest()
        assert '<textarea name="body"' in page and '>\n\n\n# Starting' in page
        assert article.read_bytes()==initial
        for query in ['/compose?name=../secret.md','/compose?name=article.md&extra=x']:assert o.request(query)[0]==400
        for bad in [{**f,'token':'invalid'},{**f,'unexpected':'x'},{**f,'intent':'unknown'}]:
            assert o.request('/compose-save','POST',bad)[0]==400
            assert article.read_bytes()==initial
        assert o.request('/compose-save','POST',f,headers={'Origin':'http://evil.invalid'})[0]==400
        assert o.request('/history-enable','POST',{'token':f['token'],'name':'article.md'})[0]==200
        assert not list((site.site/'.moonpress-history').glob('*.json'))
        f.update(title='Changed <script>&',body='\n\n## Updated\n<script>literal text</script>\n')
        if stage>=2:f['description']='New excerpt & details'
        if stage>=3:f['date']='2026-02-28'
        if stage>=4:f['tags']='New\n日本語'
        if stage>=5:f['categories']='Two\nOne\nTwo'
        if stage>=6:f['slug']='changed'
        if stage>=7:f['listed']='yes'
        if stage>=8:f['layout']=''
        if stage>=9:f['kind']='page'
        if stage>=10:f['publish_at']='2099-12-01T09:00:00Z'
        page=send(f);assert 'Post saved.' in page and '<script>' not in page
        records=list((site.site/'.moonpress-history').glob('*.json'));assert len(records)==1 and json.loads(records[0].read_text())['content']==original
        data,body=saved();assert data['title']=='Changed <script>&' and body==f['body'];assert data['wp_id']==77 and data['author']==site.ids['author']
        assert data['description']==('New excerpt & details' if stage>=2 else meta['description'])
        assert data['date']==('2026-02-28' if stage>=3 else meta['date'])
        if stage<4:assert data['tags']==meta['tags']
        if stage>=5:assert data['categories']==['One','Two']
        if stage>=6:assert data['slug']=='changed'
        if stage>=7:assert data['listed'] is True
        if stage>=8:assert 'layout' not in data
        if stage>=9:assert data['kind']=='page'
        if stage>=10:assert data['publish_at']=='2099-12-01T09:00:00Z'
        fresh=values(get());before=article.read_bytes();tag=digest();send(fresh);assert article.read_bytes()==before and digest()==tag and len(list((site.site/'.moonpress-history').glob('*.json')))==1
        invalid=[]
        if stage>=3:invalid += [{'date':'2026-02-30'}]
        if stage>=5:invalid += [{'categories':'\n'.join(str(i) for i in range(65))}]
        if stage>=6:invalid += [{'slug':'../outside'}]
        if stage>=7:invalid += [{'listed':'secret'}]
        if stage>=8:invalid += [{'layout':'../layout.html'}]
        if stage>=9:invalid += [{'kind':'attachment'}]
        if stage>=10:invalid += [{'publish_at':'bad clock'}]
        for bad in invalid:
            send({**fresh,**bad,'title':'Must not partially save'},400);assert article.read_bytes()==before
        if stage>=11:
            page=send({**fresh,'intent':'draft','body':'Draft and settings saved together.'});assert saved()[0]['draft'] is True and saved()[1]=='Draft and settings saved together.'
            fresh=values(get())
        if stage>=12:
            send({**fresh,'intent':'ready','body':'Ready text saved together.'});assert saved()[0]['draft'] is False and saved()[1]=='Ready text saved together.'
            assert 'action="/plan-production"' in send(values(get()) | {'intent':'ready'})
            fresh=values(get())
        if stage>=13:
            before=article.read_bytes();preview=send({**fresh,'intent':'preview','body':'# Unsaved heading\n\n<script>not executable</script>'})
            assert re.search(r'<h1[^>]*>Unsaved heading</h1>',preview) and '<script>' not in preview and values(preview)['version']==fresh['version'];assert article.read_bytes()==before
        if stage>=14:
            old=values(get());article.write_text(article.read_text()+'\nExternal writer\n');before=article.read_bytes()
            page=send({**old,'body':'\n\nRecovered text','title':'Retained title','intent':'save'},400)
            kept=values(page);assert kept['body']=='\n\nRecovered text' and kept['title']=='Retained title' and kept['version']==old['version'] and kept['version']!=digest();assert article.read_bytes()==before
            assert 'Open current article' in page
            fresh=values(get());backup=article.read_bytes();article.write_text('---\n{bad}\n---\nBroken')
            broken=article.read_bytes();page=send({**fresh,'title':'All fields retained','body':'Body retained'},400)
            kept=values(page);assert kept['title']=='All fields retained' and kept['body']=='Body retained' and kept['version']==fresh['version']
            for key in ['description','date','tags','categories','slug','listed','layout','kind','publish_at']:
                assert kept[key]==fresh[key]
            assert article.read_bytes()==broken;article.write_bytes(backup);fresh=values(get())
        if stage>=15:
            before=article.read_bytes();page=send({**fresh,'intent':'block','block_kind':'heading','block_text':'New heading'})
            added=values(page);assert added['body'].endswith('## New heading\n') and added['version']==fresh['version'];assert article.read_bytes()==before
            page=send({**fresh,'intent':'block','block_kind':'paragraph','block_text':'A paragraph.'});assert 'A paragraph.' in values(page)['body']
            send({**fresh,'intent':'block','block_kind':'heading','block_text':'Two\nlines'},400);assert article.read_bytes()==before
        if stage>=16:
            for kind,text,marker in [('list','one\ntwo','- one\n- two'),('quote','quoted','> quoted'),('code','<literal>','```\n<literal>\n```')]:
                page=send({**fresh,'intent':'block','block_kind':kind,'block_text':text});assert marker in values(page)['body'];assert article.read_bytes()==before
            send({**fresh,'intent':'block','block_kind':'code','block_text':'```'},400)
        if stage>=17:
            (site.site/'public').mkdir(exist_ok=True)
            png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=')
            (site.site/'public/moon.png').write_bytes(png)
            fresh=values(get());page=send({**fresh,'intent':'media','media':'public/moon.png','alt':'月の画像 & description'})
            added=values(page);assert '![月の画像 & description](moon.png)' in added['body'] and article.read_bytes()==before
            for bad in [{'media':'../secret.png','alt':'desc'},{'media':'public/moon.png','alt':'bad]alt'}]:send({**fresh,'intent':'media',**bad},400)
            fresh=added
        if stage>=18:
            page=send({**fresh,'intent':'preview_saved','publish_at':''});assert 'Saved and built themed preview' in page
            assert (site.site/'.moonpress-preview/changed.html').exists()
            fresh=values(get());(site.site/'content/broken.md').write_text('---\n{bad}\n---\nBroken')
            page=send({**fresh,'intent':'preview_saved','body':'Saved despite preview error.'});assert 'Article saved, but preview generation failed.' in page and saved()[1]=='Saved despite preview error.' and values(page)['version']==digest()
            (site.site/'content/broken.md').unlink();fresh=values(get())
        if stage>=19:
            before=article.read_bytes();(site.site/'public/new.png').write_bytes(png)
            page=send({**fresh,'intent':'media_refresh','body':'Retain unsaved text during media refresh.'});assert 'public/new.png' in page and values(page)['body']=='Retain unsaved text during media refresh.' and values(page)['version']==fresh['version'];assert article.read_bytes()==before
            assert 'target="_blank"' in page and 'Refresh library' in page
        if stage>=20:
            assert 'href="/compose?name=article.md"' in o.request('/')[1]
        final=article.read_bytes()
    with Operator(site.site) as restarted:assert 'Edit post' in restarted.request('/compose?name=article.md')[1] and article.read_bytes()==final
print('Unified editor passed: atomic fields, original revisions, guarded actions, retained errors, no-op and restart, unsaved blocks/media and truthful preview results.')
