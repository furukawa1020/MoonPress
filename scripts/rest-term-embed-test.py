from rest_fixture import NativeSite
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts'
    for title,status,terms in [('One','publish',['shared','one']),('Two','publish',['shared']),('Draft','draft',['secret'])]:
        assert s.request(posts,'POST',{'title':title,'status':status,'moonpress_categories':terms,'moonpress_tags':terms},'author')[0]==201
    assert s.request('/wp-json/wp/v2/pages','POST',{'title':'Page','status':'publish','moonpress_categories':['page-only'],'moonpress_tags':['page-only']},'editor')[0]==201
    for plural in ['categories','tags']:
        route='/wp-json/wp/v2/'+plural;rows=s.request(route)[2]
        code,h,embed=s.request(route+'?context=embed')
        assert code==200 and all(set(r)=={'id','name','slug','taxonomy','link'} for r in embed)
        assert s.request(route+'/'+str(rows[0]['id'])+'?context=embed')[2]==embed[0]
        assert s.request(route+'?context=edit',role='administrator')[0]==400
        assert s.request(route+'?context=embed&_fields=id')[2]==[{'id':r['id']} for r in rows]
        env=s.request(route+'?_envelope=1')[2];assert env['status']==200 and env['body']==rows
        assert s.request(route,headers={'If-None-Match':h['ETag']})[0]==200
        assert s.request(route+'?context=embed',headers={'If-None-Match':h['ETag']})[0]==304
