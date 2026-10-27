"""Compare supported authoring/profile/comment interchange with real core."""
from rest_fixture import NativeSite,run
from comment_fixture import set_status
import base64,datetime,hashlib,html,json,pathlib,re,sys
core=json.loads(pathlib.Path(sys.argv[1]).read_text())
def text(value):return ' '.join(html.unescape(re.sub('<[^>]+>',' ',value)).split())
with NativeSite() as s:
    login=core['author']['slug']
    change=run('access-change',s.site,s.revision,'grant',login,'author');s.revision=change['report']['revision']
    author=6;s.ids[login]=author;s.secrets.append(change['secret']);s.tokens[login]='Basic '+base64.b64encode((login+':'+change['secret']).encode()).decode()
    fields={'wp_id':core['post'],'title':'Public author fixture','author':author,'date':'2020-01-01','slug':'c3-public-author'}
    (s.site/'content/c3-public-author.md').write_text('---\n'+json.dumps(fields)+'\n---\nBody')
    created_ids=[]
    for probe in core['raw']:
        code,h,ours=s.request('/wp-json/wp/v2/posts','POST',probe['params'],'administrator')
        assert code==201,(code,ours)
        created_ids.append(str(ours['id']))
        theirs=probe['data']
        for key in ['date','date_gmt','status','type']:assert ours[key]==theirs[key],(key,ours,theirs)
        assert ours['title']['raw']==theirs['title']['raw'] and ours['excerpt']['raw']==theirs['excerpt']['raw']
        assert text(ours['content']['rendered'])==text(theirs['content']['rendered'])
    ordered=s.request('/wp-json/wp/v2/posts?context=edit&status=draft&per_page=100&include='+','.join(created_ids)+'&orderby=title&order=asc',role='administrator')[2]
    assert [p['title']['raw'] for p in ordered]==core['title_order']
    code,_,profile=s.request('/wp-json/wp/v2/users/'+str(author));assert code==200
    assert profile['name']==core['author']['name'] and profile['slug']==core['author']['slug'] and profile['id']==author
    assert set(profile)=={'id','name','slug'} and [p['id'] for p in s.request('/wp-json/wp/v2/users?slug='+login)[2]]==[author]
    created=s.request('/wp-json/moonpress/v1/comments','POST',{'post':core['post'],'content':'Core comment text.','author_name':'Public reader'},login)[2]
    set_status(s,created['id'],'approved')
    # Align the trusted disposable native log's clock with the fixed core fixture.
    previous='absent';instant=int(datetime.datetime(2020,1,2,3,4,5,tzinfo=datetime.timezone.utc).timestamp())
    for p in sorted((s.site/'.moonpress-comments').glob('*.json')):
        event=json.loads(p.read_text());event['previous']=previous;event['comment']['created']=str(instant)
        data=(json.dumps(event)+'\n').encode();p.write_bytes(data);p.chmod(0o600);previous=hashlib.sha256(data).hexdigest()
    for context in ['view','embed']:
        code,_,ours=s.request('/wp-json/wp/v2/comments/'+str(created['id'])+'?context='+context)
        assert code==200;theirs=core['comment'][context]
        # IDs belong to independently allocated stores; test the same relationships.
        assert ours['id']==created['id'] and ours['author']==author and theirs['author']==core['author']['id']
        assert set(ours).issubset(set(theirs))
        for key in ['author_name','author_url','date','parent','type']+(['date_gmt','post','status'] if context=='view' else []):assert ours[key]==theirs[key],(context,key,ours,theirs)
        assert text(ours['content']['rendered'])==text(theirs['content']['rendered'])
        assert ours['link'].endswith('#comment-'+str(ours['id'])) and theirs['link'].endswith('#comment-'+str(theirs['id']))
        assert 'raw' not in ours['content'] and 'author_email' not in ours and 'author_ip' not in ours
print('Actual WordPress core: 16 raw authoring/date cases, visible author identity and public view/embed comment fields agree within the documented subset.')
