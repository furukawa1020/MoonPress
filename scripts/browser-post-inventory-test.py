"""Exercise article discovery, editing and packaged production ZIP without JavaScript."""
import json,pathlib,runpy,subprocess,tempfile,urllib.parse,zipfile
from rest_fixture import NativeSite
from operator_fixture import Operator
helpers=runpy.run_path('scripts/browser-test.py',run_name='browser_helpers')
Browser=helpers['Browser'];wait=helpers['wait_until'];http=helpers['HTTP'];driver_path=helpers['DRIVER']
assert helpers['CHROME'] and driver_path,'Chrome and ChromeDriver are required'
with NativeSite() as site,tempfile.TemporaryDirectory() as temporary:
    for name,title in [('index','Home'),('guide','Guide'),('find-a','Browser A'),('find-b','Browser B'),('find-c','Browser C')]:
        metadata={'title':title,'draft':False}
        if name.startswith('find-'):metadata.update(tags=['Browser'],date='2026-01-0'+str(ord(name[-1])-96))
        (site.site/'content'/f'{name}.md').write_text('---\n'+json.dumps(metadata)+'\n---\n# '+title+'\n')
    with Operator(site.site) as operator:
        driver_port=helpers['port_pair']();browser=None;tmp=pathlib.Path(temporary);download=tmp/'downloads';download.mkdir()
        driver=subprocess.Popen([driver_path,f'--port={driver_port}','--allowed-ips=127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            wait(lambda:http.open(f'http://127.0.0.1:{driver_port}/status',timeout=1).status==200)
            browser=Browser(driver_port,download,tmp/'profile');base=f'http://127.0.0.1:{operator.port}'
            browser.go(base+'/?tag=Browser&sort=date_desc&per_page=1')
            browser.expect_text('Browser C');assert 'Browser B' not in browser.text('tbody')
            browser.call('POST','/window/rect',{'width':390,'height':844})
            rect=browser.call('GET','/element/'+browser.element('tbody tr')+'/rect')
            assert rect['y'] < browser.call('GET','/window/rect')['height']
            browser.screenshot('article-inventory-mobile')
            browser.call('POST','/window/rect',{'width':1280,'height':900})
            browser.click('a[rel="next"]');browser.expect_text('Browser B')
            current=browser.call('GET','/url');params=urllib.parse.parse_qs(urllib.parse.urlsplit(current).query)
            assert params['tag']==['Browser'] and params['sort']==['date_desc'] and params['per_page']==['1'] and params['page']==['2']
            browser.go(current);browser.expect_text('Browser B')
            browser.click('details summary')
            browser.fill('input[name="q"]','Browser B')
            browser.click('form[method="get"] button')
            browser.expect_text('Showing 1 of 1 matching posts')
            assert browser.call('GET','/element/'+browser.element('input[name="tag"]')+'/property/value')=='Browser'
            browser.screenshot('article-filtered')
            browser.click('a[href="/edit?name=find-b.md"]')
            browser.fill('form[action="/fields"] textarea[name="body"]','# Browser B\n\nEdited after finding this article.')
            browser.click('form[action="/fields"] button')
            browser.go(base+'/edit?name=find-b.md')
            editor=browser.element('form[action="/fields"] textarea[name="body"]')
            assert 'Edited after finding this article.' in browser.call('GET',f'/element/{editor}/property/value')
            browser.go(base+'/?tag=Browser&sort=date_desc&per_page=1&page=2')
            browser.expect_text('Browser B')
            browser.click('a[href="/history?name=find-b.md"]');browser.expect_text('History')
            browser.go(base+'/rooms/build');browser.click('form[action="/plan-production"] button');browser.click('form[action="/build-production"] button')
            browser.expect_text('Production files built')
            article=site.site/'.moonpress-build/find-b.html';assert 'Edited after finding this article.' in article.read_text()
            browser.go(base+'/rooms/publish');browser.click('form[action="/export-production"] button')
            archive=download/'moonpress-site.zip';wait(lambda:archive.exists() and not list(download.glob('*.crdownload')))
            with zipfile.ZipFile(archive) as zipped:assert zipped.read('find-b.html')==article.read_bytes()
            print('Real Chrome article inventory journey passed: retained filters, pagination, search submission, saved edit, history, production HTML and exact ZIP bytes.')
        finally:
            if browser:browser.quit()
            driver.terminate();driver.wait(timeout=8)
