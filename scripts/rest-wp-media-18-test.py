from wp_media_fixture import *
with MediaSite() as s:
    url=ROUTE+'/'+str(ident('alpha.png'))
    code,h,row=s.request(url)
    assert row['filename']=='alpha.png' and row['filesize']==len(FILES['alpha.png'])
    assert 'filename' not in s.request(url+'?context=embed')[2] and 'filesize' not in s.request(url+'?context=embed')[2]
    assert s.request(url,headers={'If-None-Match':h['ETag']})[0]==304
    (s.site/'public/alpha.png').write_bytes(FILES['alpha.png']+b'changed')
    code,new,row=s.request(url,headers={'If-None-Match':h['ETag']})
    assert code==200 and new['ETag']!=h['ETag'] and row['filesize']>len(FILES['alpha.png'])
    assert s.request(url+'?_fields=id,filesize')[2]=={'id':ident('alpha.png'),'filesize':row['filesize']}
    env=s.request(url+'?_envelope=1')[2];assert env['status']==200 and env['body']['filesize']==row['filesize']
