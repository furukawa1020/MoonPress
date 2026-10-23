from rest_fixture import NativeSite
from operator_fixture import Operator
with NativeSite() as s:
    _,_,post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Operator comments','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments'
    _,h,row=s.request(route,'POST',{'post':post['id'],'content':'<script>never execute</script>','author_name':'<Reader>'},'subscriber')
    before={p.name:p.read_bytes() for p in (s.site/'.moonpress-comments').iterdir()}
    with Operator(s.site) as operator:
        status,body=operator.request('/comments')
        assert status==200 and '&lt;script&gt;never execute&lt;/script&gt;' in body and '&lt;Reader&gt;' in body and '<script>' not in body
        assert 'class="table-scroll" role="region" aria-label="Comments" tabindex="0"' in body
        assert 'hold (1)' in body and 'approved (0)' in body and 'href="/comments"' in body
        assert operator.request('/comments?status=approved')[0]==200
        for suffix in ['status=bad','page=0','private=true','search='+('x'*257)]:assert operator.request('/comments?'+suffix)[0]==400
        status,detail=operator.request('/comment?id='+str(row['id']))
        assert status==200 and 'Inspect comment' in detail and '&lt;script&gt;never execute&lt;/script&gt;' in detail and h['ETag'].strip('"') in detail
        assert '/comment?id='+str(row['id']) in body
        assert operator.request('/comment?id=999')[0]==404
        assert operator.request('/comment?id=0')[0]==400
        assert operator.request('/comment?id=1&raw=true')[0]==400
    # Inspection itself leaves the log unchanged.
    assert before=={p.name:p.read_bytes() for p in (s.site/'.moonpress-comments').iterdir()}
    with Operator(s.site) as operator:
        _,detail=operator.request('/comment?id='+str(row['id']))
        token=operator.token(detail);revision=h['ETag'].strip('"')
        fields={'token':token,'id':str(row['id']),'revision':revision,'status':'approved'}
        assert operator.request('/comment-status','POST',{**fields,'token':'bad'})[0]==400
        assert operator.request('/comment-status','POST',fields,{'Origin':'https://evil.example'})[0]==400
        assert before=={p.name:p.read_bytes() for p in (s.site/'.moonpress-comments').iterdir()}
        status,changed=operator.request('/comment-status','POST',fields)
        assert status==200 and 'Status: approved' in changed and len(s.request(route)[2])==1
        assert operator.request('/comment-status','POST',{**fields,'status':'spam'})[0]==412
        current=s.request(route+'/'+str(row['id'])+'?context=edit',role='editor')[1]['ETag'].strip('"')
        assert operator.request('/comment-status','POST',{**fields,'revision':current,'status':'spam'})[0]==200
        assert s.request(route)[2]==[]

print('Operator comment inventory: escaped text, pending default, status navigation, strict queries and read-only GET passed.')
