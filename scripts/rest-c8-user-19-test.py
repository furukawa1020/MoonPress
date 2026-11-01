from user_read_fixture import *
with NativeSite() as s:
    for path in [U,U+'/me',U+'/'+str(s.ids['subscriber'])]:
        row=s.request(path,'OPTIONS')[2];assert row['methods']==['GET','HEAD','OPTIONS']
        assert row['schema']['properties']['roles']['context']==['edit']
        assert row['schema']['properties']['username']['readonly']
        assert row['endpoints'][0]['args']['context']['enum']==['view','embed','edit']
    args=s.request(U,'OPTIONS')[2]['endpoints'][0]['args']
    assert {'roles','capabilities','who','has_published_posts','offset','search_columns'}<=set(args)
    assert args['roles']['type']=='array' and 'include_slugs' in args['orderby']['enum']
    assert s.request(U+'?bad=1','OPTIONS')[0]==400
