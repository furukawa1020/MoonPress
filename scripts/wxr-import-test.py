#!/usr/bin/env python3
import json,pathlib,subprocess,tempfile,os
CLI=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
def run(*args,ok=True):
    result=subprocess.run([CLI,*map(str,args),'--json'],capture_output=True,text=True)
    assert (result.returncode==0)==ok,result.stderr+result.stdout
    return json.loads(result.stdout)['report'] if ok else None
with tempfile.TemporaryDirectory() as temporary:
    root=pathlib.Path(temporary);source=root/'source';target=root/'target';xml=root/'migration.xml'
    run('init',source);run('init',target)
    (source/'content/original.md').write_text('---\n{"title":"Native 月", "kind":"page","listed":false,"slug":"old-route"}\n---\n# Heading\n\n**Native** text & data.\n',encoding='utf-8')
    xml.write_text(run('wxr-export',source,'https://example.test/')['xml'],encoding='utf-8')
    plan=run('wxr-inspect',xml)
    item=next(item for item in plan['items'] if item['title']=='Native 月')
    assert item['source'] and not item.get('error'),item
    imported=run('wxr-import',target,xml,plan['digest'],item['id'],'migrated')
    path=target/'content/migrated.md';data=path.read_text(encoding='utf-8');meta=json.loads(data.split('\n---\n')[0][4:])
    assert meta['draft'] and meta['kind']=='page' and meta['listed'] is False and 'slug' not in meta
    assert '**Native** text & data.' in data and (path.stat().st_mode & 0o777)==0o600
    before=path.read_bytes()
    run('wxr-import',target,xml,plan['digest'],item['id'],'migrated',ok=False)
    run('wxr-import',target,xml,'0'*64,item['id'],'newname',ok=False)
    run('wxr-import',target,xml,plan['digest'],item['id'],'../escape',ok=False)
    assert path.read_bytes()==before and not (target/'content/newname.md').exists()
    header='<rss version="2.0" xmlns:wp="http://wordpress.org/export/1.2/" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/"><channel><wp:wxr_version>1.2</wp:wxr_version>'
    def fixture(body,status='publish',extra=''):
        return header+'<item><title>WP &amp; 月</title><wp:post_id>123</wp:post_id><wp:post_type>post</wp:post_type><wp:status>'+status+'</wp:status><content:encoded><![CDATA['+body+']]></content:encoded><wp:post_date_gmt>2020-01-01 00:00:00</wp:post_date_gmt>'+extra+'</item></channel></rss>'
    for body in ('Plain *literal* [text] without shortcode syntax','<h2>Heading</h2><p>Text &amp; data</p>'):
        # Bracket-bearing external content is conservatively refused because it
        # may be a shortcode. Supported literal body uses ordinary text instead.
        if '[' in body: body='Plain *literal* text'
        xml.write_text(fixture(body),encoding='utf-8');plan=run('wxr-inspect',xml)
        assert plan['items'][0]['source'] and not plan['items'][0].get('error'),plan
    for body,status,extra in [('<script>alert(1)</script>','publish',''),('<p><strong>inline</strong></p>','publish',''),('secret','private',''),('text','publish','<wp:post_password>password</wp:post_password>'),('text','publish','<wp:comment/>'),('text','publish','<wp:postmeta><wp:meta_key>unknown</wp:meta_key></wp:postmeta>')]:
        xml.write_text(fixture(body,status,extra),encoding='utf-8');plan=run('wxr-inspect',xml)
        assert plan['items'][0].get('source') is None and plan['items'][0]['error'],plan
        run('wxr-import',target,xml,plan['digest'],'123','unsupported',ok=False)
    xml.write_text(fixture('text').replace('<item>','<item xmlns:wp="evil">'),encoding='utf-8');run('wxr-inspect',xml,ok=False)
    xml.write_text('<!DOCTYPE rss [<!ENTITY x SYSTEM "file:///etc/passwd">]>'+fixture('&x;'),encoding='utf-8');run('wxr-inspect',xml,ok=False)
    xml.write_text(fixture('text'),encoding='utf-8');plan=run('wxr-inspect',xml)
    outside=root/'outside';outside.write_bytes(b'keep')
    (target/'content/link.md').symlink_to(outside)
    run('wxr-import',target,xml,plan['digest'],'123','link',ok=False)
    assert outside.read_bytes()==b'keep'
    with xml.open('wb') as oversized: oversized.truncate(16777217)
    run('wxr-inspect',xml,ok=False)
    assert not (target/'content/unsupported.md').exists()
print('WXR intake passed: native and external candidates, private draft creation, stale/collision/traversal refusal, unsupported-content errors, namespace/DTD safety.')
