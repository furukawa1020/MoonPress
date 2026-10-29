from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    root='/wp-json/wp/v2/comments';native='/wp-json/moonpress/v1/comments'
    code,post_h,post=s.request('/wp-json/wp/v2/posts','POST',{'title':'Discussion','status':'publish'},'author');assert code==201
    c=s.request(native,'POST',{'post':post['id'],'content':'Safe <tag>','author_name':'Reader'},'author')[2]
    assert s.request(root)[2]==[];set_status(s,c['id'],'approved')
    code,h,rows=s.request(root)
    assert code==200 and len(rows)==1 and h['X-WP-Total']=='1'
    row=rows[0];assert row['author']==s.ids['author'] and row['post']==post['id'] and row['status']=='approved' and row['parent']==0 and row['type']=='comment'
    assert row['date']==row['date_gmt'] and row['link'].endswith('#comment-'+str(c['id'])) and '&lt;tag&gt;' in row['content']['rendered']
    detail=root+'/'+str(c['id']);assert s.request(detail)[2]==row
    embedded=s.request(detail+'?context=embed')[2];assert 'post' not in embedded and 'status' not in embedded and 'date_gmt' not in embedded
    assert s.request(root+'?_fields=id')[2]==[{'id':c['id']}]
    assert s.request(detail,'HEAD')[2] is None
    assert s.request(root,'POST',{},'administrator')[0]==400
    for q in ['status=hold','type=pingback','orderby=unsupported']:assert s.request(root+'?'+q,role='administrator')[0]==400
    s.request('/wp-json/wp/v2/posts/'+str(post['id']),'PATCH',{'status':'draft'},'author',post_h['ETag'])
    assert s.request(detail)[0]==404 and s.request(root,role='administrator')[2]==[]
print('WordPress-shaped public comments: approved/public-parent visibility, ISO dates, schemas, embed, HEAD and write refusal passed.')
