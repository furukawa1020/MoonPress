from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    root='/wp-json/moonpress/v1/comments';posts=[]
    for n in range(2):
        code,h,p=s.request('/wp-json/wp/v2/posts','POST',{'title':'Post '+str(n),'status':'publish'},'author');assert code==201;posts.append(p['id'])
        code,_,c=s.request(root,'POST',{'post':p['id'],'content':'Body','author_name':'Reader'},'author');assert code==201;set_status(s,c['id'],'approved')
    code,h,rows=s.request(root+'?post='+','.join(map(str,posts)))
    assert code==200 and len(rows)==2 and h['X-WP-Total']=='2'
    assert len(s.request(root+'?post[]='+str(posts[0])+'&post[]='+str(posts[1]))[2])==2
    assert len(s.request(root+'?post='+str(posts[0]))[2])==1
    for value in ['0','-1','x','1,0']:assert s.request(root+'?post='+value)[0]==400
print('Native comment post selection: bounded scalar/comma/bracket forms, correct counts and invalid ID refusal passed.')
