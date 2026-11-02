from rest_fixture import NativeSite,run
from comment_fixture import set_status
P='/wp-json/wp/v2/posts';C='/wp-json/wp/v2/comments'
def post(s,title='Article',kind='posts',role='author',**extra):
    code,h,row=s.request('/wp-json/wp/v2/'+kind,'POST',dict(title=title,status='publish',**extra),role)
    assert code==201,(code,row)
    return row
def comment(s,p,parent=0,role='subscriber',status='approved'):
    target=post(s,title='Trusted page comment seed')['id'] if p.get('type')=='page' else p['id']
    code,h,row=s.request('/wp-json/moonpress/v1/comments','POST',dict(post=target,parent=parent,content='Comment',author_name='Reader'),role)
    assert code==201,(code,row)
    if target!=p['id']:
        import json
        f=sorted((s.site/'.moonpress-comments').glob('*.json'))[-1];data=json.loads(f.read_text());data['comment']['post']=p['id'];f.write_text(json.dumps(data)+'\n');f.chmod(0o600);row['post']=p['id']
    if status!='hold':set_status(s,row['id'],status)
    return row
