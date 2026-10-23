import base64,stat
from rest_fixture import NativeSite
PNG=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jSioAAAAASUVORK5CYII=')
with NativeSite() as site:
    route='/wp-json/moonpress/v1/media'
    _,old,_=site.request(route,'POST',{'name':'image.png','data':base64.b64encode(PNG).decode()},'author')
    path=route+'/image.png';source=site.site/'public/image.png';source.chmod(0o640);before=source.read_bytes()
    body={'data':base64.b64encode(PNG+b'changed').decode()}
    assert site.request(path,'POST',body,'author',old['ETag'])[0]==403
    assert site.request(path,'POST',body,'editor')[0]==428
    assert site.request(path,'POST',body,'editor','"'+'0'*64+'"')[0]==412
    assert site.request(path,'POST',{'data':'AB=='},'editor',old['ETag'])[0]==400 and source.read_bytes()==before
    status,h,row=site.request(path,'POST',body,'editor',old['ETag']);assert status==200 and row['changed']
    assert source.read_bytes()==PNG+b'changed' and stat.S_IMODE(source.stat().st_mode)==0o640
    assert site.request(path,'POST',body,'editor',h['ETag'])[2]['changed'] is False
    assert site.request(path,'POST',body,'editor',old['ETag'])[0]==412
    assert not (site.site/'public/.moonpress-media-edit').exists()
print('Native media replacement: editor policy, conditional versions, preserved modes, same URL, exact no-op and no staging remnant passed.')
