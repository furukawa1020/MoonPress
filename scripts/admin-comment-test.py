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
        assert 'hold (1)' in body and 'approved (0)' in body and 'href="/comments"' in body
        assert operator.request('/comments?status=approved')[0]==200
        for suffix in ['status=bad','page=0','private=true','search='+('x'*257)]:assert operator.request('/comments?'+suffix)[0]==400
    assert before=={p.name:p.read_bytes() for p in (s.site/'.moonpress-comments').iterdir()}
print('Operator comment inventory: escaped text, pending default, status navigation, strict queries and read-only GET passed.')
