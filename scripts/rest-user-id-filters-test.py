from rest_fixture import NativeSite
with NativeSite() as s:
    root='/wp-json/wp/v2/users'
    for role in ['author','editor']:assert s.request('/wp-json/wp/v2/posts','POST',{'title':role,'status':'publish'},role)[0]==201
    author=str(s.ids['author']);hidden=str(s.ids['subscriber'])
    assert [r['id'] for r in s.request(root+'?include='+author+','+hidden)[2]]==[int(author)]
    code,h,rows=s.request(root+'?exclude='+author);assert code==200 and h['X-WP-Total']=='1' and rows[0]['id']==s.ids['editor']
    assert s.request(root+'?include='+hidden,role='administrator')[2]==[]
    assert s.request(root+'?include[]=2&include[]=5')[0]==200
    assert s.request(root+'?include=0')[0]==400 and s.request(root+'/'+author+'?include='+author)[0]==400
print('Public user ID filters apply after visibility and before counts without exposing hidden principals.')
