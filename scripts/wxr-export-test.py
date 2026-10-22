#!/usr/bin/env python3
import json, pathlib, subprocess, tempfile, xml.etree.ElementTree as ET
CLI=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
NS={'wp':'http://wordpress.org/export/1.2/','content':'http://purl.org/rss/1.0/modules/content/','excerpt':'http://wordpress.org/export/1.2/excerpt/'}
with tempfile.TemporaryDirectory() as temporary:
    site=pathlib.Path(temporary)/'site'
    subprocess.run([CLI,'init',site],check=True,stdout=subprocess.DEVNULL)
    cases=[('published',{}),('draft',{'draft':True}),('unlisted',{'listed':False}),('scheduled',{'publish_at':'9999-12-31T23:59:59Z'}),('page',{'kind':'page'})]
    originals={}
    for name,fields in cases:
        source='---\r\n'+json.dumps({'title':'月 <&> '+name,'description':'Excerpt <&>','tags':['日本語','A&B'],'categories':['Science'],'date':'2020-01-01',**fields},ensure_ascii=False)+'\r\n---\r\n# Heading\r\n\r\nText ]]> & <script>alert(1)</script>\r\n'
        originals[name+'.md']=source
        (site/'content'/f'{name}.md').write_bytes(source.encode())
    def export():
        return subprocess.run([CLI,'wxr-export',site,'https://example.test/blog/','--json'],capture_output=True,text=True)
    before={p.name:p.read_bytes() for p in (site/'content').iterdir()}
    result=export();assert result.returncode==0,result.stderr
    data=json.loads(result.stdout)['report']
    channel=ET.fromstring(data['xml']).find('channel')
    assert channel.findtext('wp:wxr_version',namespaces=NS)=='1.2'
    posts={p.findtext('wp:post_name',namespaces=NS):p for p in channel.findall('item')}
    assert data['posts']==len(posts)==7
    for name,status in [('published','publish'),('draft','draft'),('unlisted','draft'),('scheduled','future'),('page','publish')]:
        post=posts[name]
        assert post.findtext('wp:status',namespaces=NS)==status
        assert post.findtext('wp:post_type',namespaces=NS)==('page' if name=='page' else 'post')
        meta={m.findtext('wp:meta_key',namespaces=NS):m.findtext('wp:meta_value',namespaces=NS) for m in post.findall('wp:postmeta',NS)}
        assert meta['_moonpress_source_v1']==originals[name+'.md']
        assert meta['_moonpress_filename_v1']==name+'.md'
        html=post.findtext('content:encoded',namespaces=NS)
        assert '<script>' not in html and '&lt;script&gt;' in html
        assert {t.text for t in post.findall('category') if t.attrib['domain']=='post_tag'}=={'日本語','A&B'}
    assert {p.name:p.read_bytes() for p in (site/'content').iterdir()}==before
    assert data['xml']==json.loads(export().stdout)['report']['xml']
    (site/'content/invalid.md').write_text('# Bad\x01')
    assert export().returncode!=0
print('WXR export passed: XML namespaces, statuses/types/taxonomy, CRLF source fidelity, escaping, deterministic read-only output and invalid XML refusal.')
