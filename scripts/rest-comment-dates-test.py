from rest_fixture import NativeSite
from comment_fixture import set_status
from datetime import datetime,timezone
from urllib.parse import urlencode
with NativeSite() as s:
    root='/wp-json/moonpress/v1/comments';post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Dates','status':'publish'},'author')[2]
    row=s.request(root,'POST',{'post':post['id'],'content':'Text','author_name':'Reader'},'author')[2];set_status(s,row['id'],'approved');created=int(row['created'])
    def stamp(n):return datetime.fromtimestamp(n,timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    assert s.request(root+'?'+urlencode({'after':stamp(created)}))[2]==[]
    assert s.request(root+'?'+urlencode({'before':stamp(created)}))[2]==[]
    code,h,rows=s.request(root+'?'+urlencode({'after':stamp(created-1),'before':stamp(created+1)}))
    assert code==200 and len(rows)==1 and h['X-WP-Total']=='1'
    assert s.request(root+'?after=invalid')[0]==400
print('Native comment date filters: exclusive UTC boundaries, combined intervals, counts and invalid date refusal passed.')
