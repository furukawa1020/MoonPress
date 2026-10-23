import json,stat
from rest_fixture import NativeSite
with NativeSite() as site:
    _,_,post=site.request('/wp-json/wp/v2/posts','POST',{'title':'Discussion','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments';body={'post':post['id'],'content':'Hello <script>x</script>\nMoon','author_name':'Reader'}
    assert site.request(route,'POST',body)[0]==401
    for bad in [dict(body,author=1),dict(body,status='approved'),dict(body,email='x'),dict(body,content=''),dict(body,content='x'*8193),dict(body,post=0)]:assert site.request(route,'POST',bad,'subscriber')[0]==400
    assert not (site.site/'.moonpress-comments').exists()
    status,h,row=site.request(route,'POST',body,'subscriber')
    assert 'Location' not in h
    assert status==201 and row['status']=='hold' and row['author']==site.ids['subscriber'] and '&lt;script&gt;' in row['content']['rendered']
    vault=site.site/'.moonpress-comments';files=list(vault.glob('*.json'));assert len(files)==1
    assert stat.S_IMODE(vault.stat().st_mode)==0o700 and stat.S_IMODE(files[0].stat().st_mode)==0o600
    site.restart();assert site.request(route,'POST',body,'subscriber')[2]['id']==2
    first=sorted(vault.glob('*.json'))[0];raw=first.read_bytes();first.chmod(0o644)
    assert site.request(route,'POST',body,'subscriber')[0]==500 and len(list(vault.glob('*.json')))==2
    first.chmod(0o600);first.write_bytes(raw[:-2]);assert site.request(route,'POST',body,'subscriber')[0]==500
print('Native pending comments: bound identity, explicit public label, safe HTML, private durable log, restart IDs and corruption/mode refusal passed.')

from comment_capacity_fixture import fill_events
with NativeSite() as site:
    _,_,post=site.request('/wp-json/wp/v2/posts','POST',{'title':'Capacity','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments';body={'post':post['id'],'content':'Bounded','author_name':'Reader'}
    site.request(route,'POST',body,'subscriber');fill_events(site)
    assert site.request(route,'POST',body,'subscriber')[0]==409
    assert len(list((site.site/'.moonpress-comments').iterdir()))==4096
print('Native full comment log: explicit capacity conflict with no additional record passed.')
