from rest_fixture import NativeSite
with NativeSite() as s:
    assets=s.site/'public';assets.mkdir()
    (assets/'alpha.png').write_bytes(b'\x89PNG\r\n\x1a\nA')
    (assets/'beta.gif').write_bytes(b'GIF89a'+b'B'*20)
    (assets/'fake.png').write_bytes(b'text')
    route='/wp-json/moonpress/v1/media'
    assert s.request(route)[0]==401 and s.request(route,role='subscriber')[0]==403
    status,h,rows=s.request(route+'?search=ALPHA',role='author')
    assert status==200 and [r['name'] for r in rows]==['alpha.png'] and h['X-WP-Total']=='1'
    assert s.request(route+'?search=missing',role='author')[2]==[]
    assert s.request(route+'?search='+('x'*257),role='author')[0]==400
    assert s.request(route+'/alpha.png?search=alpha',role='author')[0]==400
    assert [r['name'] for r in s.request(route+'?mime_type=image%2Fpng',role='author')[2]]==['alpha.png']
    assert [r['name'] for r in s.request(route+'?media_type=file',role='author')[2]]==['fake.png']
    assert len(s.request(route+'?media_type=image',role='author')[2])==2
    assert s.request(route+'?media_type=image&mime_type=application%2Foctet-stream',role='author')[2]==[]
    assert s.request(route+'?mime_type=text%2Fhtml',role='author')[0]==400
    assert s.request(route+'?media_type=video',role='author')[0]==400
    assert [r['name'] for r in s.request(route+'?orderby=bytes&order=desc',role='author')[2]]==['beta.gif','alpha.png','fake.png']
    assert s.request(route+'?orderby=bytes&order=desc&per_page=1',role='author')[2][0]['name']=='beta.gif'
    assert s.request(route+'?orderby=bytes&order=asc',role='author')[2][0]['name']=='fake.png'
    assert s.request(route+'?order=bad',role='author')[0]==400
    assert s.request(route+'?orderby=date',role='author')[0]==400
print('Native media queries preserve authorization, validate filters, and count selected results before pagination.')
