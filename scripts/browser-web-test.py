"""Exercise the HTTPS service in Chrome, with JavaScript disabled."""
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
from urllib.parse import quote

helpers = runpy.run_path('scripts/browser-test.py', run_name='browser_helpers')
origin = os.environ['MOONPRESS_TEST_WEB_ORIGIN']
password = quote(os.environ['MOONPRESS_ADMIN_PASSWORD'], safe='')
login = origin.replace('https://', f'https://admin:{password}@', 1)
port = helpers['port_pair']()
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    download = work / 'download'
    download.mkdir()
    browser = None
    driver = subprocess.Popen(
        [helpers['DRIVER'], f'--port={port}', '--allowed-ips=127.0.0.1'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        helpers['wait_until'](lambda: helpers['HTTP'].open(f'http://127.0.0.1:{port}/status', timeout=1).status == 200)
        browser = helpers['Browser'](port, download, work / 'profile', accept_insecure_certs=True)
        browser.go(login + '/')
        browser.fill('form[action="/new"] input[name="title"]', 'Browser hosted article')
        browser.fill('form[action="/new"] input[name="slug"]', 'web-browser')
        browser.click('form[action="/new"] button')
        browser.click('a[href="/compose?name=web-browser.md"]')
        browser.fill('textarea[name="body"]', '# Browser-only publication')
        browser.click('button[name="intent"][value="preview_saved"]')
        browser.expect_text('Saved and built themed preview')
        browser.go(origin + '/preview/web-browser.html')
        browser.expect_text('Browser-only publication')
        browser.go(origin + '/compose?name=web-browser.md')
        browser.click('button[name="intent"][value="ready"]')
        browser.click('form[action="/plan-production"] button')
        browser.click('form[action="/build-production"] button')
        browser.expect_text('Published the reviewed changes.')
        browser.go(origin + '/site/web-browser.html')
        browser.expect_text('Browser-only publication')
        print('Chrome published a post through the HTTPS interface without JavaScript.')
    finally:
        if browser:
            browser.quit()
        driver.terminate()
        driver.wait(timeout=8)
