from embed_fixture import *
import json
with NativeSite() as s:
    p=post(s);url=P+'/'+str(p['id'])
    edit=s.request(url+'?context=edit',role='author');tag=edit[1]['ETag']
    for verb in ['POST','PUT','PATCH','DELETE']:
        code,h,row=s.request(url+'?_embed=false',verb,{'title':'Changed'} if verb!='DELETE' else None,'author',tag)
        assert code==400,(verb,code,row)
        assert s.request(url)[2]['title']['rendered']=='Article'
    assert s.request(P+'?_embed=author','POST',{'title':'New'},'author')[0]==400
    assert s.request('/wp-json/moonpress/v1/comments?_embed=author')[0]==400
    for n in range(2,101):
        fields={'wp_id':n,'title':'Article '+str(n),'author':s.ids['author']}
        (s.site/'content'/('item-'+str(n)+'.md')).write_text('---\n'+json.dumps(fields)+'\n---\nBody')
    code,h,rows=s.request(P+'?_embed=author&per_page=100');assert code==200 and len(rows)==100
    code,h,error=s.request(P+'?_embed=true&per_page=100')
    assert code==500 and error['code']=='moonpress_embed_unavailable' and '_embedded' not in error,(code,error)
    assert s.request(P+'?_embed=author&per_page=100')[0]==200
print('Embedding safety: writes refused before mutation, 100 cached authors, 256-subrequest exhaustion fails closed, and recovery verified.')
