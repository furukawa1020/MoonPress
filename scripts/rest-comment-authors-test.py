from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    root='/wp-json/moonpress/v1/comments';post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Authors','status':'publish'},'author')[2]
    for role in ['author','subscriber']:
        c=s.request(root,'POST',{'post':post['id'],'content':role,'author_name':role},role)[2];set_status(s,c['id'],'approved')
    held=s.request(root,'POST',{'post':post['id'],'content':'Pending','author_name':'Hidden'},'subscriber')[2]
    code,h,rows=s.request(root+'?author='+str(s.ids['subscriber']))
    assert code==200 and len(rows)==1 and h['X-WP-Total']=='1' and rows[0]['id']!=held['id']
    assert len(s.request(root+'?author_exclude='+str(s.ids['subscriber']))[2])==1
    assert s.request(root+'?context=edit&author='+str(s.ids['subscriber']),role='author')[2]==[]
    assert s.request(root+'?author=0')[2]==[] and s.request(root+'?author=-1')[0]==400
print('Native comment author filters preserve approved visibility and per-owner edit scope before counts.')
