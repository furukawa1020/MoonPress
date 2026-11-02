from rest_fixture import NativeSite,run
from comment_fixture import set_status
P='/wp-json/wp/v2/posts';C='/wp-json/wp/v2/comments'
def post(s,title='Article',kind='posts',role='author',**extra):
    code,h,row=s.request('/wp-json/wp/v2/'+kind,'POST',dict(title=title,status='publish',**extra),role)
    assert code==201,(code,row)
    return row
def comment(s,p,parent=0,role='subscriber',status='approved'):
    code,h,row=s.request('/wp-json/moonpress/v1/comments','POST',dict(post=p['id'],parent=parent,content='Comment',author_name='Reader'),role)
    assert code==201,(code,row)
    if status!='hold':set_status(s,row['id'],status)
    return row
