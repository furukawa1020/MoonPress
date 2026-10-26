from rest_fixture import NativeSite
with NativeSite() as s:
    for kind in ['posts','pages']:
        route='/wp-json/wp/v2/'+kind
        code,_,r=s.request(route,'POST',dict(title='Visible',content='<p>Body</p>',status='publish'),'administrator')
        assert code==201;id=str(r['id'])
        normal=s.request(route+'/'+id)[2]
        code,h,rows=s.request(route+'?context=embed')
        expected={k:normal[k] for k in ['id','date','slug','type','link','title','excerpt','author','_links']}
        assert code==200 and rows==[expected] and h['X-WP-Total']=='1'
        assert s.request(route+'/'+id+'?context=embed')[2]==expected
        assert s.request(route+'/'+id+'?context=embed&_fields=id,content.raw')[2]=={'id':r['id']}
        assert s.request(route+'?context=embed','HEAD')[2] is None
        assert s.request(route,'POST',dict(title='Hidden'),'administrator')[0]==201
        assert len(s.request(route+'?context=embed',role='administrator')[2])==1
        assert 'embed' in s.request(route,'OPTIONS')[2]['endpoints'][0]['args']['context']['enum']
print('REST embed context: public schema subset, detail/list parity, projection, HEAD and hidden content passed.')
