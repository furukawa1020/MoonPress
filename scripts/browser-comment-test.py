"""Real no-JavaScript operator moderation journey, reusing W3C WebDriver helpers."""
import json,pathlib,runpy,subprocess,tempfile
from rest_fixture import NativeSite
from operator_fixture import Operator
helpers=runpy.run_path('scripts/browser-test.py',run_name='browser_helpers')
Browser=helpers['Browser'];wait=helpers['wait_until'];http=helpers['HTTP'];driver_path=helpers['DRIVER']
assert helpers['CHROME'] and driver_path,'Chrome and ChromeDriver are required'
with NativeSite() as site,tempfile.TemporaryDirectory() as temporary:
    _,_,post=site.request('/wp-json/wp/v2/posts','POST',{'title':'Browser moderation','status':'publish'},'author')
    route='/wp-json/moonpress/v1/comments'
    _,_,row=site.request(route,'POST',{'post':post['id'],'content':'<script>literal text</script>','author_name':'Reader'},'subscriber')
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
            print('Real Chrome comment journey passed: escaped literal text, no script, approval, trash and hold-only restoration with JavaScript disabled.')
        finally:
            if browser:browser.quit()
            driver.terminate();driver.wait(timeout=8)
