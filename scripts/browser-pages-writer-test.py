"""Exercise the public Pages editor and reader in an actual browser."""

import runpy
from pathlib import Path
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
    reader = None
    try:
        base = f'http://127.0.0.1:{port}/MoonPress/'
        wait = helpers['wait_until']
        wait(lambda: helpers['HTTP'].open(f'http://127.0.0.1:{driver_port}/status', timeout=1).status == 200)
        browser = helpers['Browser'](driver_port, downloads, root / 'profile', javascript=True)

        def click(selector):
            return browser.call('POST', f'/element/{browser.element(selector)}/click', {})

        def evaluate(source):
            return browser.call('POST', '/execute/sync', {'script': source, 'args': []})

        browser.go(base + 'manage.html')
        click('#new a.primary')
        wait(lambda: browser.call('GET', '/url') == base + 'write.html')
        wait(lambda: evaluate('return !document.querySelector("#workspace").hidden'))
        browser.fill('#title', '最初の原稿')
        browser.fill('#body [contenteditable]', '月の文章', clear=False)
        evaluate('window.getSelection().selectAllChildren(document.querySelector("#body [contenteditable]")); document.dispatchEvent(new Event("selectionchange"));')
        click('[data-command="bold"]')
        wait(lambda: evaluate('return Boolean(document.querySelector("#body b, #body strong"))'))
        click('#preview-button')
        assert browser.text('#preview-title') == '最初の原稿'
        assert browser.text('#preview-body') == '月の文章'
        click('#preview-button')
        wait(lambda: '保存済み' in browser.text('#draft-status'))
        browser.go(base + 'write.html')
        assert evaluate('return document.querySelector("#title").value') == '最初の原稿'
        click('#new')
        browser.fill('#title', '別の原稿')
        browser.fill('#body [contenteditable]', 'ここは別の本文', clear=False)
        click('#open')
        assert '別の原稿' in browser.text('#draft-list')
        click('.draft-row:last-child button:first-child')
        assert evaluate('return document.querySelector("#title").value') == '最初の原稿'

        click('.writer-options summary')
        click('#download')
        wait(lambda: (downloads / '最初の原稿.md').is_file())
        assert '**月の文章**' in (downloads / '最初の原稿.md').read_text()
        click('#export')
        wait(lambda: (downloads / '最初の原稿.html').is_file())
        assert '月の文章' in (downloads / '最初の原稿.html').read_text()

        click('#share-button')
        url = wait(lambda: evaluate('return document.querySelector("#share-url").value'))
        assert url.startswith(base + 'write.html#read=')
        reader = helpers['Browser'](driver_port, downloads, root / 'reader-profile', javascript=True)
        reader.go(url)
        wait(lambda: reader.text('#reader-title') == '最初の原稿')
        assert reader.text('#reader-body') == '月の文章'
        reader.go(base + 'write.html#read=invalid')
        reader.call('POST', '/refresh', {})
        wait(lambda: '開けません' in reader.text('#reader-error'))
        print('Pages editor: Word-style formatting, preview, two drafts, storage, document exports and public reader.')
    finally:
        if reader:
            reader.quit()
        if browser:
            browser.quit()
        for process in (driver, server):
            process.terminate()
            process.wait(timeout=8)
