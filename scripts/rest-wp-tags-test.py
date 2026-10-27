from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    route='/wp-json/wp/v2/tags'
    code,h,rows=s.request(route)
    assert code==200 and {r['name']:r['count'] for r in rows}=={'one':1,'shared':2}
    assert all(r['taxonomy']=='post_tag' and 'parent' not in r for r in rows)
    cats={r['name']:r['id'] for r in s.request('/wp-json/wp/v2/categories')[2]}
    assert all(r['id']!=cats[r['name']] for r in rows)
    assert s.request(route+'?_fields=name')[2]==[{'name':'one'},{'name':'shared'}]
    assert s.request(route,role='administrator')[2]==rows
