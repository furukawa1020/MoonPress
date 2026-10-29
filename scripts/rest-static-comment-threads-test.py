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
    from rest_fixture import run
    import json
    config=s.site/'site.json';data=json.loads(config.read_text());data['comments']=True;config.write_text(json.dumps(data))
    (s.site/'layout.html').write_text('<!doctype html><html><head><title>{{title}}</title></head><body>{{content}}</body></html>')
    root=create(label='<R>');set_status(s,root['id'],'approved');child=create(parent=root['id'],text='<script>reply</script>');set_status(s,child['id'],'approved')
    out=s.root/'out';run('build',s.site,out)
    html=(out/'one.html').read_text();assert '<ol class="comment-replies">' in html and '&lt;script&gt;reply&lt;/script&gt;' in html and '<script>' not in html
    assert run('build',s.site,out)['written']==0
    set_status(s,root['id'],'hold');assert run('build',s.site,out)['written']==1
    assert 'comment-author' not in (out/'one.html').read_text()
    set_status(s,root['id'],'approved');run('build',s.site,out)
    clean=s.root/'clean';run('build',s.site,clean)
    assert {p.name:p.read_bytes() for p in out.iterdir() if not p.name.startswith('.')}=={p.name:p.read_bytes() for p in clean.iterdir() if not p.name.startswith('.')}
