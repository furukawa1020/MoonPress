from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    root='/wp-json/moonpress/v1/comments';post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Embed','status':'publish'},'author')[2]
    row=s.request(root,'POST',{'post':post['id'],'content':'Safe <tag>','author_name':'Reader'},'author')[2];set_status(s,row['id'],'approved')
    code,h,rows=s.request(root+'?context=embed')
    assert code==200 and len(rows)==1 and set(rows[0])=={'id','author_name','parent','created','content'}
    assert 'raw' not in rows[0]['content'] and 'author' not in rows[0] and '&lt;tag&gt;' in rows[0]['content']['rendered']
    assert s.request(root+'/'+str(row['id'])+'?context=embed')[2]==rows[0]
    assert s.request(root+'?context=embed&_fields=content.raw')[2]==[{'content':{}}]
    assert s.request(root+'?context=embed','HEAD')[2] is None
print('Native comment embed context: minimal public fields, safe HTML, detail parity and raw/identity omission passed.')
