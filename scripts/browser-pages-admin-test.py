"""Use the Pages navigation in Chrome with JavaScript disabled."""
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile

helpers = runpy.run_path('scripts/browser-test.py', run_name='browser_helpers')
port, driver_port = helpers['port_pair'](), helpers['port_pair']()
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    shutil.copytree(sys.argv[1], root / 'MoonPress')
    downloads = root / 'downloads'
    downloads.mkdir()
    server = subprocess.Popen(
        [sys.executable, '-m', 'http.server', str(port), '--bind', '127.0.0.1', '--directory', str(root)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    driver = subprocess.Popen(
        [helpers['DRIVER'], f'--port={driver_port}', '--allowed-ips=127.0.0.1'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    browser = None
    try:
        base = f'http://127.0.0.1:{port}/MoonPress/'
        wait = helpers['wait_until']
        http = helpers['HTTP']
        wait(lambda: http.open(base, timeout=1).status == 200)
        wait(lambda: http.open(f'http://127.0.0.1:{driver_port}/status', timeout=1).status == 200)
        browser = helpers['Browser'](driver_port, downloads, root / 'profile')
        for width, height in ((1280, 900), (390, 780)):
            browser.call('POST', '/window/rect', {'width': width, 'height': height})
            browser.go(base)
            html = browser.element('html')
            viewport = browser.call('GET', f'/element/{html}/property/clientHeight')
            body = browser.element('body')
            assert 'MoonPixel' in browser.call('GET', f'/element/{body}/css/font-family')
            art = browser.element('.home-stage .stage-art')
            assert browser.call('GET', f'/element/{art}/property/naturalWidth') == 1536
            assert browser.call('GET', f'/element/{art}/css/image-rendering') == 'pixelated'
            cta = browser.element('.home-stage a[href="manage.html"]')
            rect = browser.call('GET', f'/element/{cta}/rect')
            assert rect['y'] + rect['height'] <= viewport

            for route in ('guide.html', 'room-write.html', 'manage.html'):
                browser.go(base + route)
                title = browser.element('h1')
                assert 'MoonPixel' in browser.call('GET', f'/element/{title}/css/font-family')
                body = browser.element('body')
                assert 'MoonPixel' in browser.call('GET', f'/element/{body}/css/font-family')
                if route != 'manage.html':
                    scene = browser.element('.workshop-scene img')
                    assert browser.call('GET', f'/element/{scene}/property/naturalWidth') == 1536
                    assert browser.call('GET', f'/element/{scene}/css/image-rendering') == 'pixelated'
                assert browser.call('GET', f'/element/{body}/css/background-color') == 'rgba(8, 15, 36, 1)'
                html = browser.element('html')
                assert browser.call('GET', f'/element/{html}/property/scrollWidth') <= browser.call('GET', f'/element/{html}/property/clientWidth')

        browser.go(base)
        browser.click('header nav a[href="manage.html"]')
        browser.expect_text('サイト管理')
        assert browser.call('GET', '/url') == base + 'manage.html'
        browser.call('POST', '/actions', {'actions': [
            {'type': 'key', 'id': 'keyboard', 'actions': [{'type': 'keyDown', 'value': '\ue004'}, {'type': 'keyUp', 'value': '\ue004'}]},
        ]})
        active = browser.call('GET', '/element/active')['element-6066-11e4-a52e-4f735466cecf']
        assert browser.call('GET', f'/element/{active}/attribute/href') == '#main'
        for anchor in ('posts', 'pages', 'quick-edit', 'media', 'settings', 'publish'):
            browser.click(f'nav a[href="#{anchor}"]')
            assert browser.call('GET', '/url').endswith('#' + anchor)
        edit = browser.element('#pages a[href$="/edit/main/site/content/guide.md"]')
        assert browser.call('GET', f'/element/{edit}/attribute/href') == 'https://github.com/furukawa1020/MoonPress/edit/main/site/content/guide.md'
        quick_edit = browser.element('#pages a[href$="/actions/workflows/pages-edit.yml"]')
        assert browser.call('GET', f'/element/{quick_edit}/text') == 'クイック編集'
        history = browser.element('#pages a[href$="/commits/main/site/content/guide.md"]')
        assert browser.call('GET', f'/element/{history}/text') == '履歴'
        source = browser.element('#pages .source-name code')
        assert browser.call('GET', f'/element/{source}/text') == 'guide.md'
        assert browser.call('POST', '/elements', {'using': 'css selector', 'value': 'script'}) == []
        print('Chrome Pages: shared pixel theme on desktop and mobile, above-fold management link, keyboard navigation and GitHub editor destinations.')
    finally:
        if browser:
            browser.quit()
        for process in (driver, server):
            process.terminate()
            process.wait(timeout=8)
