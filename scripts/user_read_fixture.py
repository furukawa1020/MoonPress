from rest_fixture import NativeSite,run
U='/wp-json/wp/v2/users'
def post(s,role,kind='posts',status='publish'):
    result=s.request('/wp-json/wp/v2/'+kind,'POST',{'title':role,'status':status},role)
    assert result[0]==201,result
    return result[2]
