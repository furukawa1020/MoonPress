from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    import hashlib,json
    posts='/wp-json/wp/v2/posts';route='/wp-json/moonpress/v1/comments'
    a=s.request(posts,'POST',{'title':'Legacy','status':'publish'},'author')[2]
    row=s.request(route,'POST',{'post':a['id'],'author_name':'Reader','content':'Legacy'},'subscriber')[2]
    assert row['parent']==0
    set_status(s,row['id'],'approved')
    # Recreate the old schema=1 shape without parent, maintaining the trusted fixture hash chain.
    previous='absent'
    for p in sorted((s.site/'.moonpress-comments').glob('*.json')):
        event=json.loads(p.read_text());event['comment'].pop('parent',None);event['previous']=previous
        data=(json.dumps(event)+'\n').encode();p.write_bytes(data);p.chmod(0o600);previous=hashlib.sha256(data).hexdigest()
    before={p.name:p.read_bytes() for p in (s.site/'.moonpress-comments').glob('*.json')}
    assert s.request(route)[2][0]['parent']==0
    assert s.request(route+'?context=embed')[2][0]['parent']==0
    s.restart();assert s.request(route)[2][0]['parent']==0
    assert before=={p.name:p.read_bytes() for p in (s.site/'.moonpress-comments').glob('*.json')}
