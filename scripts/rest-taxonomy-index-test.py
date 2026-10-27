from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/taxonomies'
    code,h,rows=s.request(route)
    assert code==200 and set(rows)=={'category','post_tag'}
    assert rows['category']['rest_base']=='categories' and rows['post_tag']['types']==['post']
    assert s.request(route+'?type=page')[2]=={}
    assert s.request(route+'?type=post')[2]==rows
    assert s.request(route+'?_fields=slug')[2]=={'category':{'slug':'category'},'post_tag':{'slug':'post_tag'}}
    assert 'types' not in s.request(route+'?context=embed')[2]['category']
    assert s.request(route+'?context=edit')[0]==400
    assert s.request(route+'?type=attachment')[0]==400
    assert s.request(route,'HEAD')[2] is None
    assert s.request(route,'POST',{})[0]==405
