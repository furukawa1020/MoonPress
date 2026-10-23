from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    for title,status,role in [('Public','publish','author'),('Draft','draft','author'),('Foreign','draft','editor')]:
        assert s.request(route,'POST',{'title':title,'status':status,'moonpress_categories':['News'],'moonpress_tags':['native']},role)[0]==201
    assert len(s.request(route+'?moonpress_category=News&moonpress_tag=native')[2])==1
    assert s.request(route+'?moonpress_category=Missing')[1]['X-WP-Total']=='0'
    assert s.request(route+'?moonpress_category=News&moonpress_tag=other')[2]==[]
    assert len(s.request(route+'?context=edit&status=any&moonpress_tag=native',role='author')[2])==2
    assert len(s.request(route+'?context=edit&status=any&moonpress_category=News',role='editor')[2])==3
    assert s.request(route+'?moonpress_tag=')[0]==400
    assert s.request(route+'?moonpress_category='+('a'*97))[0]==400
print('Native article term filters: exact names, combined filters, public and authorized ownership scopes, counts and bounds passed.')
