from wp_media_fixture import *
with MediaSite() as s:
    for path in [ROUTE,ROUTE+'/'+str(ident('alpha.png'))]:
        code,h,row=s.request(path,'OPTIONS')
        assert code==200 and row['methods']==['GET','HEAD','OPTIONS'] and row['moonpress']['public_files_only']
        assert row['schema']['properties']['source_url']['readonly']
    args=s.request(ROUTE,'OPTIONS')[2]['endpoints'][0]['args']
    assert {'include','exclude','slug','offset','orderby','search','mime_type','media_type'}<=set(args)
    assert args['orderby']['default']=='id'
    for index in ['/wp-json/','/wp-json/wp/v2']:
        assert '/wp/v2/media' in s.request(index)[2]['routes']
    assert s.request(ROUTE+'?bad=1','OPTIONS')[0]==400
