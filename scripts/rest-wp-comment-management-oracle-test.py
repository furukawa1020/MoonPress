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
    wp='/wp-json/wp/v2/comments'
    row=create();url=wp+'/'+str(row['id']);tag=s.request(url+'?context=edit',role='editor')[1]['ETag']
    body={'content':{'raw':'Reviewed'},'author_name':'Public','status':'approve'}
    code,h,data=s.request(url,'PATCH',body,'editor',tag);assert code==200 and data['status']=='approved'
    assert s.request(url)[2]['author_name']=='Public'
    count=len(list((s.site/'.moonpress-comments').glob('*.json')))
    assert s.request(url,'PATCH',body,'editor',h['ETag'])[1]['ETag']==h['ETag']
    assert len(list((s.site/'.moonpress-comments').glob('*.json')))==count
    assert s.request(url+'?context=edit',role='subscriber')[0]==403
    assert s.request(wp+'?context=edit&status=all',role='editor')[1]['X-WP-Total']=='1'
    assert 'author_email' not in data and 'author_ip' not in data
    from comment_capacity_fixture import fill_events
    fill_events(s)
    _,full,current=s.request(url+'?context=edit',role='editor')
    assert s.request(url,'PATCH',{'content':'No room'},'editor',full['ETag'])[0]==409
    assert s.request(url,'PATCH',{'content':current['content']['raw']},'editor',full['ETag'])[0]==200
    assert len(list((s.site/'.moonpress-comments').glob('*.json')))==4096
