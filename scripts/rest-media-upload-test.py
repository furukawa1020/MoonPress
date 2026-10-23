import base64,hashlib
from rest_fixture import NativeSite
PNG=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jSioAAAAASUVORK5CYII=')
with NativeSite() as site:
    route='/wp-json/moonpress/v1/media';body={'name':'image.png','data':base64.b64encode(PNG).decode()}
    assert site.request(route,'POST',body)[0]==401
    assert site.request(route,'POST',body,'contributor')[0]==403 and not (site.site/'public').exists()
    for bad in [dict(body,name='../x.png'),dict(body,name='x.svg'),dict(body,data='AB=='),dict(body,data='!!!!'),dict(body,data=base64.b64encode(b'not png').decode()),dict(body,author=1)]:assert site.request(route,'POST',bad,'author')[0]==400
    assert not (site.site/'public').exists()
    status,h,row=site.request(route,'POST',body,'author')
    assert status==201 and row['digest']==hashlib.sha256(PNG).hexdigest() and (site.site/'public/image.png').read_bytes()==PNG
    assert h['Location'].endswith('/image.png') and site.request(route,'POST',body,'author')[0]==409
    # Native upload JSON alone has the larger bounded body allowance.
    larger=PNG+b'\x00'*(300*1024)
    status,_,_=site.request(route,'POST',{'name':'larger.png','data':base64.b64encode(larger).decode()},'author');assert status==201
    assert site.request(route+'?_fields=name','POST',{'name':'projected.png','data':base64.b64encode(larger).decode()},'author')[2]=={'name':'projected.png'}
    assert site.request(route+'/nested/file.png','POST',{'data':base64.b64encode(larger).decode()},'author')[0]==400
    assert site.request('/wp-json/wp/v2/posts','POST',{'title':'X','content':'a'*(300*1024)},'author')[0]==400
print('Native media upload: roles, strict names/encoding/signatures, first-use folder, exclusive publication and separate body bounds passed.')
