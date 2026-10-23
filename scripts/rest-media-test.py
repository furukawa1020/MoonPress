import base64,urllib.parse
from rest_fixture import NativeSite
PNG=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jSioAAAAASUVORK5CYII=')
with NativeSite() as site:
    assert site.request('/wp-json/moonpress/v1/media',role='author')[2]==[]
    assert not (site.site/'public').exists()
    (site.site/'public').mkdir()
    (site.site/'public/画像+one.png').write_bytes(PNG)
    route='/wp-json/moonpress/v1/media';detail=route+'/'+urllib.parse.quote('画像+one.png')
    assert site.request(route)[0]==401 and site.request(route,role='subscriber')[0]==403
    status,h,row=site.request(detail,role='author')
    assert status==200 and row['name']=='画像+one.png' and row['mime_type']=='image/png' and row['bytes']==len(PNG) and h['ETag']=='"'+row['digest']+'"'
    assert 'source' not in row and 'content' not in row and row['source_url'].endswith('%E7%94%BB%E5%83%8F%2Bone.png')
    rows=site.request(route+'/?per_page=100',role='editor')[2];assert any(r['name']==row['name'] for r in rows)
    assert site.request(detail,'HEAD',role='author')[2] is None
    assert site.request(route+'/missing.png',role='author')[0]==404
    assert site.request(route+'/..%2Fsite.json',role='author')[0]==404
    assert site.request(route+'?per_page=101',role='author')[0]==400
    target=site.root/'private';target.write_bytes(b'private');(site.site/'public/link.png').symlink_to(target)
    assert site.request(route+'/link.png',role='author')[0]==500
print('Native media: credential/capability gate, filename routes, bounded metadata, Unicode URLs, HEAD and symlink refusal passed.')
