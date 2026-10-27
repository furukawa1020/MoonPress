from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for path in ['/wp-json/wp/v2/taxonomies','/wp-json/wp/v2/taxonomies/category','/wp-json/wp/v2/categories','/wp-json/wp/v2/tags']:
        code,h,options=s.request(path,'OPTIONS')
        assert code==200 and options['methods']==['GET','HEAD','OPTIONS']
        assert set(h['Allow'].split(', '))=={'GET','HEAD','OPTIONS'}
        args=options['endpoints'][0]['args'];assert args['context']['enum']==['view','embed']
        assert options['moonpress']['flat_terms'] and options['moonpress']['public_terms_only']
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural;row=s.request(route)[2][0]
        options=s.request(route,'OPTIONS')[2];args=options['endpoints'][0]['args'];props=options['schema']['properties']
        assert args['include']['items']['type']=='integer' and args['per_page']['maximum']==100
        assert props['count']['context']==['view'] and props['id']['type']=='integer'
        assert ('parent' in props)==(plural=='categories')
        assert 'post' not in s.request(route+'/'+str(row['id']),'OPTIONS')[2]['endpoints'][0]['args']
        assert s.request(route+'?page=1','OPTIONS')[0]==400
    routes=s.request('/wp-json/wp/v2')[2]['routes']
    for p in ['/wp/v2/categories','/wp/v2/tags','/wp/v2/taxonomies']:
        assert routes[p]['methods']==['GET','HEAD','OPTIONS']
    options=s.request(posts,'OPTIONS')[2]
    assert options['schema']['properties']['categories']['readonly']
    assert options['endpoints'][0]['args']['tax_relation']['enum']==['AND','OR']
    search=s.request('/wp-json/wp/v2/search','OPTIONS')[2]
    assert search['endpoints'][0]['args']['type']['enum']==['post','term']
