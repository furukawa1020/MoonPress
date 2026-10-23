"""Generate a native export and verify it through the official WP importer."""
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET
wordpress, plugin, work = map(Path,sys.argv[1:])
cli=Path('_build/native/release/build/cmd/main/main.exe').resolve()
site=work/'wxr-site'
subprocess.run([cli,'init',site],check=True,stdout=subprocess.DEVNULL)
expected=[]
for slug,extra,status in [('oracle-post',{},'publish'),('oracle-draft',{'draft':True},'draft'),('oracle-unlisted',{'listed':False},'draft'),('oracle-future',{'publish_at':'2099-01-01T00:00:00Z'},'future'),('oracle-page',{'kind':'page'},'publish')]:
    fields={'title':'MoonPress WXR '+slug+' 日本語 & text','description':'Oracle excerpt','date':'2020-01-01','tags':['WXR tag'], 'categories':['WXR category'],**extra}
    if fields.get('kind')=='page': fields.update(tags=[],categories=[])
    source='---\n'+json.dumps(fields,ensure_ascii=False)+'\n---\n# Oracle\n\nExact text & <escaped> data.\n'
    (site/'content'/f'{slug}.md').write_text(source,encoding='utf-8')
    expected.append(dict(slug=slug,source=source,title=fields['title'],kind=fields.get('kind','post'),status=status,tags=fields['tags'],categories=fields['categories']))
result=json.loads(subprocess.check_output([cli,'wxr-export',site,'https://example.test/','--json'],text=True))['report']
xml=work/'oracle.xml';xml.write_text(result['xml'],encoding='utf-8')
ns={'wp':'http://wordpress.org/export/1.2/','content':'http://purl.org/rss/1.0/modules/content/'}
items={item.findtext('wp:post_name',namespaces=ns):item for item in ET.fromstring(result['xml']).findall('./channel/item')}
for row in expected:row['html']=items[row['slug']].findtext('content:encoded',namespaces=ns)
metadata=work/'oracle.json';metadata.write_text(json.dumps(expected,ensure_ascii=False),encoding='utf-8')
subprocess.run(['php','benchmarks/wordpress/wxr-oracle.php',wordpress,plugin,xml,metadata],check=True)
core_xml=work/'wordpress-export.xml'
plan=json.loads(subprocess.check_output([cli,'wxr-inspect',core_xml,'--json'],text=True))['report']
plain=next(item for item in plan['items'] if item['title']=='WordPress native intake oracle')
if not plain.get('source') or plain.get('error'): raise ValueError('Core export candidate rejected: '+str(plain))
subprocess.run([cli,'wxr-import',site,core_xml,plan['digest'],plain['id'],'from-wordpress','--json'],check=True,stdout=subprocess.DEVNULL)
source=(site/'content/from-wordpress.md').read_text(encoding='utf-8')
if 'Native intake text' not in source or json.loads(source.split('\n---\n')[0][4:])['draft'] is not True: raise ValueError('Core export intake differs')
for title,name,fragments in [('WordPress table and strike oracle','table-core',['~~old~~','| Name | Value |','| One | **two** |']),('WordPress extended blocks oracle','extended-core',['> Quoted **bold** end','  x < y','---','https://example.test/image.png']),('WordPress block intake oracle','block-core',['### Block heading','Block **bold** end','- Block item']),('WordPress inline intake oracle','inline-core',['Before **bold** after *soft*','https://example.test/','`x < y`']),('WordPress list intake oracle','list-core',['- First **bold** end','- Second','3. Third','3. Fourth'])]:
    candidate=next(item for item in plan['items'] if item['title']==title)
    assert candidate.get('source') and not candidate.get('error'),candidate
    subprocess.run([cli,'wxr-import',site,core_xml,plan['digest'],candidate['id'],name,'--json'],check=True,stdout=subprocess.DEVNULL)
    source=(site/'content'/f'{name}.md').read_text()
    assert all(fragment in source for fragment in fragments),source
print('WXR actual core export -> native inspection -> private draft import passed, including ordered inline and flat list content.')

# Verify every advertised native capability against actual installed core roles.
roles=[json.loads(subprocess.check_output([cli,'access-role',role,'--json'],text=True))['report'] for role in ['subscriber','contributor','author','editor','administrator']]
roles_path=work/'roles.json';roles_path.write_text(json.dumps(roles),encoding='utf-8')
subprocess.run(['php','benchmarks/wordpress/access-oracle.php',wordpress,roles_path],check=True)

subprocess.run([sys.executable,'benchmarks/wordpress/rest-oracle.py',wordpress,work],check=True)
