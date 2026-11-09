"""WordPress-like authoring controls on the exact native executable, JavaScript disabled."""
import base64,json,pathlib,runpy,subprocess,tempfile,zipfile
from rest_fixture import NativeSite
from operator_fixture import Operator
h=runpy.run_path('scripts/browser-test.py',run_name='browser_helpers');Browser=h['Browser'];wait=h['wait_until'];http=h['HTTP'];driver_path=h['DRIVER']
assert h['CHROME'] and driver_path
with NativeSite() as site,tempfile.TemporaryDirectory() as temporary:
    for name in ['index','guide']:(site.site/'content'/f'{name}.md').write_text('# '+name)
    with Operator(site.site) as o:
        port=h['port_pair']();browser=None;tmp=pathlib.Path(temporary);download=tmp/'downloads';download.mkdir()
        driver=subprocess.Popen([driver_path,f'--port={port}','--allowed-ips=127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            wait(lambda:http.open(f'http://127.0.0.1:{port}/status',timeout=1).status==200)
            browser=Browser(port,download,tmp/'profile');base=f'http://127.0.0.1:{o.port}'
            browser.go(base+'/');browser.fill('form[action="/new"] input[name="title"]','Composer journey');browser.fill('form[action="/new"] input[name="slug"]','composer-journey');browser.click('form[action="/new"] button')
            browser.click('a[href="/compose?name=composer-journey.md"]');browser.expect_text('Edit post')
            assert browser.call('POST','/elements',{'using':'css selector','value':'script'})==[]
            browser.fill('textarea[name="body"]','\n\n# Writing in one editor\n\nText kept while uploading an image.')
            browser.fill('textarea[name="description"]','Composer excerpt')
            browser.fill('textarea[name="tags"]','Editor\n日記')
            browser.fill('textarea[name="categories"]','Writing')
            browser.fill('textarea[name="date"]','2026-01-01')
            original_window=browser.call('GET','/window')
            browser.click('details.compose-tools:nth-of-type(2) summary')
            browser.click('a[href="/media"][target="_blank"]')
            wait(lambda:len(browser.call('GET','/window/handles'))==2)
            other=[v for v in browser.call('GET','/window/handles') if v!=original_window][0];browser.call('POST','/window',{'handle':other})
            browser.expect_text('Media')
            # A new starter has no public storage until explicitly prepared.
            browser.click('form[action="/prepare-media"] button');browser.go(base+'/media')
            image=tmp/'moon.png';image.write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII='))
            browser.fill('form[action="/upload"] input[name="name"]','moon.png');browser.fill('input[type="file"]',str(image),clear=False);browser.click('form[action="/upload"] button');browser.expect_text('Media uploaded')
            browser.call('DELETE','/window');browser.call('POST','/window',{'handle':original_window})
            body=browser.element('textarea[name="body"]');assert 'Text kept while uploading an image.' in browser.call('GET',f'/element/{body}/property/value')
            browser.click('button[name="intent"][value="media_refresh"]');browser.expect_text('Library refreshed')
            browser.click('details.compose-tools:nth-of-type(2) summary');browser.click('select[name="media"] option[value="public/moon.png"]');browser.fill('textarea[name="alt"]','Moon image');browser.click('button[name="intent"][value="media"]');browser.expect_text('Image inserted into editor')
            body=browser.element('textarea[name="body"]');assert '![Moon image](moon.png)' in browser.call('GET',f'/element/{body}/property/value')
            assert 'Text kept while uploading' not in (site.site/'content/composer-journey.md').read_text()
            browser.click('details.compose-tools:nth-of-type(1) summary');browser.click('select[name="block_kind"] option[value="heading"]');browser.fill('textarea[name="block_text"]','Added heading');browser.click('button[name="intent"][value="block"]')
            browser.click('button[name="intent"][value="preview"]');browser.expect_text('Unsaved body preview');assert 'Added heading' in browser.text('article')
            browser.click('button[name="intent"][value="draft"]');browser.expect_text('Post saved.')
            saved=(site.site/'content/composer-journey.md').read_text();meta=json.loads(saved.split('---\n',2)[1]);assert meta['draft'] and meta['categories']==['Writing'] and meta['description']=='Composer excerpt'
            browser.call('POST','/window/rect',{'width':390,'height':844});browser.screenshot('composer-mobile');rect=browser.call('GET','/element/'+browser.element('textarea[name="body"]')+'/rect');assert rect['x']>=0 and rect['x']+rect['width']<=390
            browser.call('POST','/window/rect',{'width':1280,'height':900});browser.click('button[name="intent"][value="preview_saved"]');browser.expect_text('Saved and built themed preview')
            browser.go(f'http://127.0.0.1:{o.port+1}/composer-journey.html');browser.expect_text('Text kept while uploading an image.');wait(lambda:browser.call('GET','/element/'+browser.element('img')+'/property/naturalWidth')==1)
            browser.go(base+'/compose?name=composer-journey.md');browser.click('button[name="intent"][value="ready"]');browser.expect_text('Post saved.');browser.click('form[action="/plan-production"] button');browser.click('form[action="/build-production"] button');browser.expect_text('Production files built')
            article=site.site/'.moonpress-build/composer-journey.html';assert article.exists() and 'Added heading' in article.read_text()
            browser.go(base+'/rooms/publish');browser.click('form[action="/export-production"] button');archive=download/'moonpress-site.zip';wait(lambda:archive.exists() and not list(download.glob('*.crdownload')))
            with zipfile.ZipFile(archive) as z:assert z.read('composer-journey.html')==article.read_bytes() and z.read('moon.png')==image.read_bytes()
            print('Real Chrome unified editor passed: new post, single save, retained upload, image/block insertion, unsaved and themed previews, draft, publication review, exact HTML and image ZIP bytes.')
        finally:
            if browser:browser.quit()
            driver.terminate();driver.wait(timeout=8)
