from rest_fixture import NativeSite
from comment_fixture import set_status
with NativeSite() as s:
    posts='/wp-json/wp/v2/posts';route='/wp-json/moonpress/v1/comments'
    a=s.request(posts,'POST',{'title':'One','status':'publish','slug':'one'},'author')[2]
    b=s.request(posts,'POST',{'title':'Two','status':'publish','slug':'two'},'author')[2]
    def create(post=a['id'],parent=0,label='Reader',text='Text',role='subscriber'):
        code,h,row=s.request(route,'POST',{'post':post,'parent':parent,'author_name':label,'content':text},role)
        assert code==201,(code,row)
        return row
    import json,hashlib
    row=create();vault=s.site/'.moonpress-comments';first=(vault/'00000001.json').read_bytes();record=json.loads(first)['comment'];record['content']='Edited'
    event={'schema':1,'sequence':2,'previous':hashlib.sha256(first).hexdigest(),'action':'edit','comment':record};path=vault/'00000002.json';path.write_text(json.dumps(event)+'\n');path.chmod(0o600)
    assert s.request(route+'/'+str(row['id'])+'?context=edit',role='editor')[2]['content']['raw']=='Edited'
    s.restart();assert (vault/'00000001.json').read_bytes()==first
    record['post']=b['id'];path.write_text(json.dumps(event)+'\n');assert s.request(route)[0]==500
