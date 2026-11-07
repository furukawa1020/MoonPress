"""Real no-JavaScript operator moderation journey, reusing W3C WebDriver helpers."""
import json,pathlib,runpy,subprocess,tempfile,zipfile
from rest_fixture import NativeSite
from operator_fixture import Operator
helpers=runpy.run_path('scripts/browser-test.py',run_name='browser_helpers')
Browser=helpers['Browser'];wait=helpers['wait_until'];http=helpers['HTTP'];driver_path=helpers['DRIVER']
assert helpers['CHROME'] and driver_path,'Chrome and ChromeDriver are required'
with NativeSite() as site,tempfile.TemporaryDirectory() as temporary:
    _,_,post=site.request('/wp-json/wp/v2/posts','POST',{'title':'Browser moderation','slug':'browser-moderation','status':'publish'},'author')
    # The shared REST fixture removes starter pages; the layout still links home.
    for title,slug in [('Home','index'),('Guide','guide')]:
        assert site.request('/wp-json/wp/v2/posts','POST',{'title':title,'slug':slug,'status':'publish'},'author')[0]==201
    route='/wp-json/moonpress/v1/comments'
    _,_,row=site.request(route,'POST',{'post':post['id'],'content':'\n\n<script>literal text</script>','author_name':'Reader'},'subscriber')
    with Operator(site.site) as operator:
        driver_port=helpers['port_pair']();browser=None;tmp=pathlib.Path(temporary);download=tmp/'downloads';download.mkdir()
        driver=subprocess.Popen([driver_path,f'--port={driver_port}','--allowed-ips=127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            wait(lambda:http.open(f'http://127.0.0.1:{driver_port}/status',timeout=1).status==200)
            browser=Browser(driver_port,download,tmp/'profile')
            browser.go(f'http://127.0.0.1:{operator.port}/comments')
            browser.expect_text('<script>literal text</script>')
            assert browser.call('POST','/elements',{'using':'css selector','value':'script'})==[]
            browser.click('a[href="/comment?id='+str(row['id'])+'"]')
            browser.expect_text('Inspect comment')
            initial_editor=browser.element('form[action="/comment-edit"] textarea[name="content"]')
            assert browser.call('GET',f'/element/{initial_editor}/property/value')=='\n\n<script>literal text</script>'
            before_tag=site.request(route+'/'+str(row['id'])+'?context=edit',role='editor')[1]['ETag']
            before_events=len(list((site.site/'.moonpress-comments').glob('*.json')))
            browser.click('form[action="/comment-edit"] button')
            browser.expect_text('Comment saved.')
            assert site.request(route+'/'+str(row['id'])+'?context=edit',role='editor')[1]['ETag']==before_tag
            assert len(list((site.site/'.moonpress-comments').glob('*.json')))==before_events
            browser.fill('form[action="/comment-edit"] textarea[name="content"]', 'Edited through the browser.')
            browser.fill('form[action="/comment-edit"] input[name="author_name"]', 'Browser reader')
            browser.click('form[action="/comment-edit"] button')
            browser.expect_text('Comment saved.')
            browser.go(f'http://127.0.0.1:{operator.port}/comment?id='+str(row['id']))
            editor=browser.element('form[action="/comment-edit"] textarea[name="content"]')
            assert browser.call('GET',f'/element/{editor}/property/value')=='Edited through the browser.'
            edited=site.request(route+'/'+str(row['id'])+'?context=edit',role='editor')[2]
            assert edited['content']['raw']=='Edited through the browser.' and edited['author_name']=='Browser reader'
            browser.screenshot('comments-edited')
            browser.click('button[value="approved"]');browser.expect_text('Status: approved')
            assert len(site.request(route)[2])==1
            browser.click('button[value="trash"]');browser.expect_text('Status: trash')
            assert site.request(route)[2]==[]
            browser.click('button[value="hold"]');browser.expect_text('Status: hold')
            assert site.request(route)[2]==[]
            browser.screenshot('comments-restored-to-hold')
            browser.go(f'http://127.0.0.1:{operator.port}/site-settings')
            browser.click('form[action="/comment-display"] button[value="true"]')
            browser.expect_text('Comments in article pages: enabled')
            assert json.loads((site.site/'site.json').read_text())['comments'] is True
            browser.go(f'http://127.0.0.1:{operator.port}/comment?id='+str(row['id']))
            browser.click('button[value="approved"]')
            browser.go(f'http://127.0.0.1:{operator.port}/rooms/build')
            browser.click('form[action="/plan-production"] button')
            browser.click('form[action="/build-production"] button')
            browser.expect_text('Production files built')
            article=site.site/'.moonpress-build/browser-moderation.html'
            assert 'Edited through the browser.' in article.read_text() and 'Browser reader' in article.read_text()
            browser.go(f'http://127.0.0.1:{operator.port}/rooms/publish')
            browser.click('form[action="/export-production"] button')
            archive=download/'moonpress-site.zip'
            wait(lambda:archive.exists() and not list(download.glob('*.crdownload')))
            with zipfile.ZipFile(archive) as zipped:
                assert zipped.read('browser-moderation.html')==article.read_bytes()
            print('Real Chrome comment journey passed: escaped literal text, no script, approval, trash and hold-only restoration with JavaScript disabled.')
        finally:
            if browser:browser.quit()
            driver.terminate();driver.wait(timeout=8)
