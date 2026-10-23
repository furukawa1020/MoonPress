import hashlib,json
from operator_fixture import Operator
from rest_fixture import NativeSite,run
with NativeSite() as s:
    (s.site/'layout.html').write_text('<!doctype html><html><head><title>{{title}}</title></head><body><h1>{{title}}</h1>{{content}}</body></html>')
    post_route='/wp-json/wp/v2/posts';comments='/wp-json/moonpress/v1/comments'
    _,_,one=s.request(post_route,'POST',{'title':'One','slug':'one','status':'publish','content':'<p>Public one</p>'},'author')
    status,_,two=s.request(post_route,'POST',{'title':'Two','slug':'two','status':'publish','content':'<p>Public two</p>'},'author');assert status==201
    _,h,row=s.request(comments,'POST',{'post':one['id'],'author_name':'<Reader>','content':'<script>literal</script>\nSecond line'},'subscriber')
    out=s.root/'out';run('build',s.site,out)
    assert 'comment-author' not in (out/'one.html').read_text()
    settings=s.site/'site.json';version=hashlib.sha256(settings.read_bytes()).hexdigest()
    with Operator(s.site) as operator:
        _,form=operator.request('/site-settings');token=operator.token(form)
        fields={'token':token,'version':version,'enabled':'true'}
        assert operator.request('/comment-display','POST',{**fields,'token':'bad'})[0]==400
        status,body=operator.request('/comment-display','POST',fields)
        assert status==200 and 'Comments in article pages: enabled' in body
        assert operator.request('/comment-display','POST',{**fields,'enabled':'false'})[0]==400
    config=json.loads(settings.read_text());assert config['comments'] is True
    run('build',s.site,out);assert 'comment-author' not in (out/'one.html').read_text()
    _,approved,_=s.request(comments+'/'+str(row['id']),'POST',{'status':'approved'},'editor',h['ETag'])
    before={p.name:p.read_bytes() for p in out.iterdir() if p.is_file() and not p.name.startswith('.')}
    report=run('build',s.site,out);assert report['written']==1,report
    text=(out/'one.html').read_text();assert '&lt;Reader&gt;' in text and '&lt;script&gt;literal&lt;/script&gt;<br>\nSecond line' in text and '<script>' not in text
    assert (out/'two.html').read_bytes()==before['two.html'] and 'comment-author' not in (out/'two.html').read_text()
    assert run('build',s.site,out)['written']==0
    clean=s.root/'clean';run('build',s.site,clean)
    assert {p.name:p.read_bytes() for p in out.iterdir() if not p.name.startswith('.')}=={p.name:p.read_bytes() for p in clean.iterdir() if not p.name.startswith('.')}
    assert s.request(comments,'POST',{'post':two['id'],'author_name':'Reader','content':'PRIVATE PENDING'},'subscriber')[0]==201
    assert run('build',s.site,out)['written']==0 and 'PRIVATE PENDING' not in (out/'two.html').read_text()
    article=post_route+'/'+str(one['id'])
    source_tag=s.request(article+'?context=edit',role='author')[1]['ETag']
    _,draft,_=s.request(article,'POST',{'status':'draft'},'author',source_tag)
    run('build',s.site,out);assert not (out/'one.html').exists()
    preview=s.root/'preview';run('build',s.site,preview,'--include-drafts')
    assert 'comment-author' not in (preview/'one.html').read_text()
    assert s.request(article,'POST',{'status':'publish'},'author',draft['ETag'])[0]==200
    source=(s.site/'content'/'one.md').read_text();raw,body=source[4:].split('\n---\n',1);metadata=json.loads(raw)
    for key,value in [('listed',False),('publish_at','2099-01-01T00:00:00Z')]:
        altered={**metadata,key:value};(s.site/'content'/'one.md').write_text('---\n'+json.dumps(altered)+'\n---\n'+body)
        run('build',s.site,out);run('build',s.site,preview,'--include-drafts')
        assert all('comment-author' not in p.read_text() for p in out.glob('*.html'))
        assert 'comment-author' not in (preview/'one.html').read_text()
        (s.site/'content'/'one.md').write_text(source)
    run('build',s.site,out)
    assert s.request(comments+'/'+str(row['id']),'DELETE',role='editor',etag=approved['ETag'])[0]==200
    assert run('build',s.site,out)['written']==1 and 'comment-author' not in (out/'one.html').read_text()
    # Duplicate IDs, even in a draft, cannot accidentally attach discussion to another article.
    original=(s.site/'content'/'one.md').read_text();(s.site/'content'/'duplicate.md').write_text(original.replace('"draft":false','"draft":true').replace('"slug":"one"','"slug":"duplicate"'))
    run('build',s.site,out,ok=False);(s.site/'content'/'duplicate.md').unlink()
    bad=s.site/'.moonpress-comments'/'00000001.json';bad.write_bytes(bad.read_bytes()+b' ')
    run('build',s.site,out,ok=False)
    config['comments']=False;(s.site/'site.json').write_text(json.dumps(config));run('build',s.site,out)
    assert 'comment-author' not in (out/'one.html').read_text()
print('Static comments: explicit opt-in, approved escaped output, isolated article dependencies, no-op/clean parity, trash removal and corrupt/duplicate identity refusal passed.')
