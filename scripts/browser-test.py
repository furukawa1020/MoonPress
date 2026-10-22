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
        options = {'binary': CHROME, 'args': ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--no-proxy-server', '--window-size=1280,900', f'--user-data-dir={profile}'], 'prefs': {'profile.managed_default_content_settings.javascript': 2, 'download.default_directory': str(download), 'download.prompt_for_download': False, 'download.directory_upgrade': True}}
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
                steps.append('ready transition, review and production build')
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
                before = (site / '.moonpress-build/browser-moon.html').read_bytes()
                with (site / 'content/browser-moon.md').open('a') as source:
                    source.write('\nExternal change after review.\n')
                browser.click('form[action="/build-production"] button')
                wait_until(lambda: 'changed' in browser.text().lower())
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
