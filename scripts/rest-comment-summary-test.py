from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/moonpress/v1/comments';summary=route+'/summary'
    assert s.request(summary)[0]==401
    for role in ['subscriber','author','contributor']:assert s.request(summary,role=role)[0]==403
    assert s.request(summary,role='editor')[2]['total']==0
    assert not (s.site/'.moonpress-comments').exists()
    _,_,post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Summary','status':'publish'},'author')
    for state in ['hold','approved','spam','trash']:
        _,h,row=s.request(route,'POST',{'post':post['id'],'author_name':'Reader','content':'Private text'},'subscriber')
        if state!='hold':
            assert s.request(route+'/'+str(row['id']),'DELETE' if state=='trash' else 'POST',None if state=='trash' else {'status':state},'editor',h['ETag'])[0]==200
    row=s.request(summary,role='administrator')[2]
    assert row['counts']=={'hold':1,'approved':1,'spam':1,'trash':1} and row['total']==4 and row['events']==7
    assert row['bytes']>0 and row['event_limit']==4096 and 'Private text' not in str(row)
    assert s.request(summary,'HEAD',role='editor')[2] is None
    assert s.request(summary+'?raw=true',role='editor')[0]==400
    assert s.request(summary,'POST',{},'editor')[0]==405
print('Native comment summary: fresh moderator authority, private aggregate counts, bounded capacity metadata and read-only absence passed.')
