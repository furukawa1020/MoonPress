from rest_fixture import NativeSite
with NativeSite() as s:
    root='/wp-json/wp/v2/users';author=str(s.ids['author'])
    assert s.request(root+'/'+author)[0]==404
    assert s.request('/wp-json/wp/v2/posts','POST',{'title':'Public','status':'publish'},'author')[0]==201
    code,_,row=s.request(root+'/'+author)
    assert code==200 and row==s.request(root)[2][0]
    assert s.request(root+'/'+author+'?_fields=id')[2]=={'id':int(author)}
    assert s.request(root+'/'+str(s.ids['subscriber']),role='administrator')[0]==404
    assert s.request(root+'/'+author,'OPTIONS')[2]['methods']==['GET','HEAD','OPTIONS']
    assert s.request(root+'/'+author,'DELETE')[0]==405
    assert s.request(root+'/me?context=edit',role='author')[2]['roles']==['author']
print('Public author detail: publication visibility, collection parity, projection and separate private users/me identity passed.')
