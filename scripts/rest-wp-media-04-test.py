from wp_media_fixture import *
with MediaSite() as s:
    row=s.request(ROUTE+'/'+str(ident('alpha.png')))[2]
    assert row['title']=={'rendered':'alpha.png'} and row['slug']==slug('alpha.png')
    name='画像+A&B.png';(s.site/'public'/name).write_bytes(FILES['alpha.png'])
    code,h,row=s.request(ROUTE+'/'+str(ident(name)))
    assert code==200 and row['title']['rendered']=='画像+A&amp;B.png'
    assert row['slug']==slug(name) and row['source_url'].endswith(urllib.parse.quote(name,safe=''))
