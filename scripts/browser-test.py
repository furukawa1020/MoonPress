"""Real-browser regression using only W3C WebDriver and Python's standard library."""
import base64
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import zipfile

ROOT = Path.cwd()
CLI = Path(os.environ.get('MOONPRESS_BROWSER_CLI', ROOT / '_build/native/release/build/cmd/main/main.exe')).resolve()
CHROME = os.environ.get('MOONPRESS_CHROME') or shutil.which('google-chrome') or shutil.which('chromium')
DRIVER = os.environ.get('MOONPRESS_CHROMEDRIVER') or shutil.which('chromedriver')
ARTIFACTS = Path(os.environ.get('MOONPRESS_BROWSER_ARTIFACTS', ROOT / '_build/browser-verification')).resolve()
ARTIFACTS.mkdir(parents=True, exist_ok=True)
HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def port_pair():
    for _ in range(100):
        with socket.socket() as first, socket.socket() as second:
            first.bind(('127.0.0.1', 0))
            port = first.getsockname()[1]
            try:
                second.bind(('127.0.0.1', port + 1))
            except OSError:
                continue
            return port
    raise RuntimeError('No free local port pair')

def wait_until(predicate, seconds=20):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        try:
            result = predicate()
            if result:
                return result
        except (OSError, ValueError, RuntimeError) as error:
            last = error
        time.sleep(.1)
    raise RuntimeError(f'Timed out: {last}')

class Browser:
    def __init__(self, port, download, profile):
        self.base = f'http://127.0.0.1:{port}'
        self.session = None
        options = {'binary': CHROME, 'args': ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--no-proxy-server', '--window-size=1280,900', f'--user-data-dir={profile}'], 'prefs': {'intl.accept_languages': 'en-US,en', 'profile.managed_default_content_settings.javascript': 2, 'download.default_directory': str(download), 'download.prompt_for_download': False, 'download.directory_upgrade': True}}
        result = self.call('POST', '/session', {'capabilities': {'alwaysMatch': {'browserName': 'chrome', 'goog:chromeOptions': options}}})
        self.session = result['sessionId']
        self.capabilities = result['capabilities']
        self.call('POST', '/timeouts', {'implicit': 2000, 'pageLoad': 20000, 'script': 1000})
    def call(self, method, path, data=None):
        prefix = '/session/' + self.session if self.session else ''
        request = urllib.request.Request(self.base + prefix + path, data=None if data is None else json.dumps(data).encode(), headers={'Content-Type': 'application/json'}, method=method)
        try:
            with HTTP.open(request, timeout=30) as response:
                result = json.load(response)['value']
        except urllib.error.HTTPError as error:
            raise RuntimeError(error.read().decode()) from error
        if isinstance(result, dict) and 'error' in result:
            raise RuntimeError(result)
        return result
    def element(self, selector):
        return self.call('POST', '/element', {'using': 'css selector', 'value': selector})['element-6066-11e4-a52e-4f735466cecf']
    def click(self, selector):
        self.call('POST', '/element/' + self.element(selector) + '/click', {})
    def fill(self, selector, value, clear=True):
        element = self.element(selector)
        if clear:
            self.call('POST', f'/element/{element}/clear', {})
        self.call('POST', f'/element/{element}/value', {'text': value})
    def text(self, selector='body'):
        return self.call('GET', '/element/' + self.element(selector) + '/text')
    def expect_text(self, text):
        wait_until(lambda: text in self.text())
    def go(self, url):
        self.call('POST', '/url', {'url': url})
    def screenshot(self, name):
        (ARTIFACTS / (name + '.png')).write_bytes(base64.b64decode(self.call('GET', '/screenshot')))
    def quit(self):
        if self.session:
            self.call('DELETE', '')
            self.session = None

def run():
    assert CHROME and DRIVER, 'Install Chrome and matching ChromeDriver, or set MOONPRESS_CHROME / MOONPRESS_CHROMEDRIVER'
    steps = []
    with tempfile.TemporaryDirectory(prefix='moonpress-browser-') as temporary:
        tmp = Path(temporary)
        site = tmp / 'site'
        download = tmp / 'downloads'
        download.mkdir()
        subprocess.run([str(CLI), 'init', str(site)], check=True, capture_output=True)
        port = port_pair()
        driver_port = port_pair()
        browser = None
        with (ARTIFACTS / 'admin.log').open('w') as admin_log, (ARTIFACTS / 'driver.log').open('w') as driver_log:
            admin = subprocess.Popen([str(CLI), 'admin', str(site), str(port)], stdout=admin_log, stderr=subprocess.STDOUT)
            driver = subprocess.Popen([DRIVER, f'--port={driver_port}', '--allowed-ips=127.0.0.1'], stdout=driver_log, stderr=subprocess.STDOUT)
            origin = f'http://127.0.0.1:{port}'
            try:
                wait_until(lambda: HTTP.open(origin + '/rooms', timeout=1).status == 200)
                wait_until(lambda: HTTP.open(f'http://127.0.0.1:{driver_port}/status', timeout=1).status == 200)
                browser = Browser(driver_port, download, tmp / 'profile')
                browser.go(origin + '/rooms')
                browser.expect_text('The beginning room')
                browser.click('a[lang="ja"][href^="/language/ja"]')
                browser.expect_text('はじまりのおへや')
                browser.go(origin + '/rooms/write')
                browser.expect_text('かきかきる〜む')
                browser.click('a[href^="/language/auto"]')
                browser.expect_text('The writing room')
                steps.append('automatic English, persistent Japanese override, return to browser language')
                browser.go(origin + '/rooms')
                browser.screenshot('entrance-desktop')
                for route in ['/rooms/write', '/rooms/preview', '/rooms/build', '/rooms/publish']:
                    browser.click(f'a[href="{route}"]')
                    wait_until(lambda: browser.call('GET', '/url').endswith(route))
                    assert browser.text('h1')
                steps.append('five rooms through links')
                browser.go(origin + '/')
                browser.fill('form[action="/new"] input[name="title"]', 'Browser moon')
                browser.fill('form[action="/new"] input[name="slug"]', 'browser-moon')
                browser.click('form[action="/new"] button')
                wait_until(lambda: (site / 'content/browser-moon.md').exists())
                browser.expect_text('Source saved')
                browser.go(origin + '/edit?name=browser-moon.md')
                body = '# Browser moon\n\nSaved through a real browser.\n'
                browser.fill('textarea[name="body"]', body)
                browser.click('form[action="/fields"] button:not([formaction])')
                browser.expect_text('Source saved')
                browser.go(origin + '/edit?name=browser-moon.md')
                browser.call('POST', '/refresh', {})
                element = browser.element('textarea[name="body"]')
                assert browser.call('GET', f'/element/{element}/property/value') == body
                steps.append('create/edit/save/reload')
                # Full native authoring lifecycle through real forms with JavaScript disabled.
                browser.go(origin + '/')
                browser.fill('form[action="/new"] input[name="title"]', 'Journey article')
                browser.fill('form[action="/new"] input[name="slug"]', 'journey-article')
                browser.click('form[action="/new"] button')
                browser.expect_text('Source saved')
                journey = site / 'content/journey-article.md'
                browser.go(origin + '/edit?name=journey-article.md')
                browser.fill('textarea[name="body"]', '# Journey article\n\nHistory original text.\n')
                browser.click('form[action="/fields"] button:not([formaction])')
                browser.expect_text('Source saved')
                original = journey.read_bytes()
                browser.go(origin + '/history?name=journey-article.md')
                browser.click('form[action="/history-enable"] button')
                browser.expect_text('History is enabled')
                browser.click('form[action="/checkpoint"] button')
                browser.expect_text('History is enabled')
                browser.go(origin + '/edit?name=journey-article.md')
                browser.fill('textarea[name="body"]', '# Journey article\n\nHistory edited text.\n')
                browser.click('form[action="/fields"] button:not([formaction])')
                browser.expect_text('Source saved')
                browser.go(origin + '/history?name=journey-article.md')
                browser.click('a[href^="/revision?name="]')
                revision_url = browser.call('GET', '/url')
                browser.click('a[href^="/revision-diff?"]')
                browser.expect_text('History original text.')
                browser.expect_text('History edited text.')
                browser.screenshot('revision-comparison')
                browser.go(revision_url)
                browser.click('form[action="/restore-revision"] button')
                browser.expect_text('History is enabled')
                assert journey.read_bytes() == original
                steps.append('enable history, checkpoint, edit, compare and exact revision restore')
                browser.go(origin + '/edit?name=journey-article.md')
                browser.click('form[action="/kind"] option[value="page"]')
                browser.click('form[action="/kind"] button')
                browser.expect_text('Source saved')
                assert json.loads(journey.read_text().split('---\n')[1])['kind'] == 'page'
                browser.go(origin + '/?kind=page')
                browser.expect_text('Journey article')
                browser.go(origin + '/edit?name=journey-article.md')
                browser.fill('form[action="/categories"] textarea', 'Science\n日記\nScience')
                browser.click('form[action="/categories"] button')
                browser.expect_text('Source saved')
                assert set(json.loads(journey.read_text().split('---\n')[1])['categories']) == {'Science','日記'}
                retained = journey.read_bytes()
                browser.go(origin + '/trash-post?name=journey-article.md')
                browser.click('form[action="/trash-post"] button')
                wait_until(lambda: not journey.exists())
                browser.go(origin + '/trash')
                browser.click('a[href^="/trash-item?id="]')
                browser.screenshot('trash-review')
                browser.click('form[action="/trash-restore"] button')
                wait_until(journey.exists)
                assert journey.read_bytes() == retained
                assert journey.stat().st_mode & 0o777 == 0o600
                browser.go(origin + '/edit?name=journey-article.md')
                browser.click('form[action="/kind"] option[value="post"]')
                browser.click('form[action="/kind"] button')
                browser.expect_text('Source saved')
                browser.go(origin + '/edit?name=journey-article.md')
                browser.click('button[name="state"][value="ready"]')
                browser.expect_text('Source saved')
                steps.append('page type/filter, distinct categories, reviewed trash and private exact restore')
                browser.go(origin + '/')
                browser.fill('form[action="/new"] input[name="title"]', 'Purge fixture')
                browser.fill('form[action="/new"] input[name="slug"]', 'purge-fixture')
                browser.click('form[action="/new"] button')
                browser.expect_text('Source saved')
                purge_source = site / 'content/purge-fixture.md'
                wait_until(purge_source.exists)
                browser.go(origin + '/trash-post?name=purge-fixture.md')
                browser.click('form[action="/trash-post"] button')
                # A new navigation can cancel an asynchronously submitted form.
                # Observe the completed mutation before asking for its inventory.
                wait_until(lambda: not purge_source.exists())
                wait_until(lambda: len(list((site / '.moonpress-trash').glob('*.json'))) == 1)
                browser.go(origin + '/trash')
                browser.click('a[href^="/trash-item?id="]')
                browser.click('form[action="/trash-purge"] input[type="checkbox"]')
                browser.click('form[action="/trash-purge"] button')
                wait_until(lambda: not list((site / '.moonpress-trash').glob('*.json')))
                assert not (site / 'content/purge-fixture.md').exists()
                steps.append('individually reviewed permanent purge with explicit acknowledgement')
                browser.go(origin + '/edit?name=browser-moon.md')
                browser.call('POST', '/window/rect', {'width': 390, 'height': 844})
                browser.screenshot('editor-mobile')
                rect = browser.call('GET', '/element/' + browser.element('textarea[name="body"]') + '/rect')
                window = browser.call('GET', '/window/rect')
                assert rect['x'] >= 0 and rect['x'] + rect['width'] <= window['width']
                browser.fill('textarea[name="body"]', '\ue004', clear=False)
                assert browser.call('GET', '/element/active')['element-6066-11e4-a52e-4f735466cecf'] == browser.element('form[action="/fields"] button:not([formaction])')
                steps.append('narrow viewport and keyboard Tab')
                browser.call('POST', '/window/rect', {'width': 1280, 'height': 900})
                browser.go(origin + '/media')
                browser.click('form[action="/prepare-media"] button')
                browser.expect_text('Media storage ready')
                browser.go(origin + '/media')
                image = tmp / 'moon.png'
                image.write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII='))
                browser.fill('form[action="/upload"] input[name="name"]', 'moon.png')
                browser.fill('input[type="file"]', str(image), clear=False)
                browser.click('form[action="/upload"] button')
                wait_until(lambda: (site / 'public/moon.png').exists())
                browser.expect_text('Media uploaded')
                assert (site / 'public/moon.png').read_bytes() == image.read_bytes()
                steps.append('browser file upload and byte equality')
                browser.go(origin + '/edit?name=browser-moon.md')
                browser.fill('textarea[name="body"]', body + '\n![Moon](moon.png)\n')
                browser.click('form[action="/fields"] button:not([formaction])')
                browser.expect_text('Source saved')
                browser.go(origin + '/workflow')
                browser.click('form[action="/build-preview"] button')
                browser.expect_text('Full preview files built')
                browser.go(f'http://127.0.0.1:{port+1}/browser-moon.html')
                browser.expect_text('Saved through a real browser.')
                wait_until(lambda: browser.call('GET', '/element/' + browser.element('img') + '/property/naturalWidth') == 1)
                steps.append('draft preview on separate origin with loaded image')
                browser.go(origin + '/edit?name=browser-moon.md')
                browser.click('button[name="state"][value="ready"]')
                browser.expect_text('Source saved')
                browser.go(origin + '/workflow')
                browser.click('form[action="/plan-production"] button')
                browser.click('form[action="/build-production"] button')
                wait_until(lambda: (site / '.moonpress-build/browser-moon.html').exists())
                browser.expect_text('Production files built')
                assert 'Journey article' in (site / '.moonpress-build/category-536369656e6365.html').read_text()
                steps.append('ready transition, review and production build with category archives')
                browser.go(origin + '/publish')
                browser.screenshot('publish-desktop')
                browser.click('form[action="/export-production"] button')
                archive = download / 'moonpress-site.zip'
                wait_until(lambda: archive.exists() and not list(download.glob('*.crdownload')))
                with zipfile.ZipFile(archive) as zipped:
                    expected = {p.name: p.read_bytes() for p in (site / '.moonpress-build').iterdir() if p.name != '.moonpress.json'}
                    assert set(zipped.namelist()) == set(expected)
                    for name, data in expected.items():
                        assert zipped.read(name) == data, name
                steps.append('ZIP download and full production byte parity')
                browser.go(origin + '/workflow')
                browser.click('form[action="/plan-production"] button')
                review_element = wait_until(lambda: browser.element('form[action="/build-production"] input[name="review_id"]'))
                reviewed = browser.call('GET', f'/element/{review_element}/property/value')
                assert len(reviewed) == 64
                before = (site / '.moonpress-build/browser-moon.html').read_bytes()
                with (site / 'content/browser-moon.md').open('a') as source:
                    source.write('\nExternal change after review.\n')
                browser.click('form[action="/build-production"] button')
                browser.expect_text('Reviewed build plan changed')
                assert (site / '.moonpress-build/browser-moon.html').read_bytes() == before
                steps.append('stale reviewed build refused without output mutation')
                report = {'browser': browser.capabilities['browserVersion'], 'javascript': 'disabled by managed browser preference; no injected scripts', 'steps': steps}
                (ARTIFACTS / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
                print(json.dumps(report, indent=2))
            except Exception:
                if browser:
                    browser.screenshot('failure')
                    (ARTIFACTS / 'failure.html').write_text(browser.call('GET', '/source'))
                raise
            finally:
                if browser:
                    try:
                        browser.quit()
                    except (OSError, RuntimeError):
                        pass
                for process in [driver, admin]:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()

if __name__ == '__main__':
    run()
