"""HTTPS, access boundaries, review gating and persistent publication."""
import base64
from html.parser import HTMLParser
import http.client
import os
import re
import ssl
import sys
from urllib.parse import urlencode, urlsplit

origin = os.environ['MOONPRESS_TEST_WEB_ORIGIN']
host = urlsplit(origin).netloc
password = os.environ['MOONPRESS_ADMIN_PASSWORD']
authorization = 'Basic ' + base64.b64encode(('admin:' + password).encode()).decode()
image = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII='
)


class Form(HTMLParser):
    def __init__(self, html, action):
        super().__init__()
        self.action = action
        self.active = False
        self.controls = {}
        self.current = None
        self.select = None
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == 'form':
            self.active = values.get('action') == self.action
        if not self.active:
            return
        if tag == 'input' and 'name' in values:
            self.controls[values['name']] = values.get('value', '')
        if tag == 'textarea':
            self.current = values['name']
            self.controls[self.current] = ''
        if tag == 'select':
            self.select = values['name']
        if tag == 'option' and self.select:
            if self.select not in self.controls or 'selected' in values:
                self.controls[self.select] = values.get('value', '')

    def handle_data(self, text):
        if self.current:
            self.controls[self.current] += text

    def handle_endtag(self, tag):
        if tag == 'textarea' and self.current:
            self.controls[self.current] = self.controls[self.current].removeprefix('\n')
            self.current = None
        if tag == 'select':
            self.select = None
        if tag == 'form':
            self.active = False


def request(path, *, fields=None, auth=True, status=200, method=None, headers=None, payload=None):
    selected = {'Accept-Language': 'en'}
    if auth:
        selected['Authorization'] = authorization
    if fields is not None:
        payload = urlencode(fields).encode()
        selected.update({'Content-Type': 'application/x-www-form-urlencoded', 'Origin': origin})
    selected.update(headers or {})
    connection = http.client.HTTPSConnection(
        host, timeout=12, context=ssl._create_unverified_context()
    )
    try:
        connection.request(method or ('POST' if payload is not None else 'GET'), path, payload, selected)
        response = connection.getresponse()
        body = response.read()
        assert response.status == status, (path, response.status, status, re.findall(rb'<p[^>]*>([^<]+)', body)[-12:])
        return dict(response.getheaders()), body
    finally:
        connection.close()


def controls(page, action):
    result = Form(page.decode(), action).controls
    assert 'token' in result, action
    return result


def new(title, slug):
    fields = controls(request('/')[1], '/new')
    request('/new', fields={**fields, 'title': title, 'slug': slug})


def edit(slug, text, intent):
    fields = controls(request('/compose?name=' + slug + '.md')[1], '/compose-save')
    return request('/compose-save', fields={**fields, 'body': text, 'intent': intent})[1]


if '--after-restart' in sys.argv:
    assert b'Published body' in request('/site/web-test.html', auth=False)[1]
    assert request('/site/web-image.png', auth=False)[1] == image
    assert b'Private draft' in request('/preview/web-draft.html')[1]
    assert b'Edited after review' in request('/compose?name=web-test.md')[1]
    print('Web restart preserved authored changes, media, private preview and published output.')
    sys.exit()

assert request('/healthz', auth=False)[1] == b'OK\n'
assert 'MoonPress' in request('/', auth=False, status=401)[0]['Www-Authenticate']
request('/', status=401, headers={'Authorization': 'Basic aW52YWxpZDppbnZhbGlk'})
request('/', status=400, headers={'Host': 'other.invalid', 'X-Forwarded-Host': host})
request('/preview/', auth=False, status=401)
request('/media-image?name=web-image.png', auth=False, status=401)
request('/site/', auth=False, status=404)
request('/site/', auth=False, method='POST', status=405, payload=b'x')
request('/web-health', status=404)

initial = request('/', headers={'Sec-Fetch-Site': 'cross-site', 'Sec-Fetch-Mode': 'navigate', 'Sec-Fetch-Dest': 'document'})[1]
new_fields = controls(initial, '/new')
request('/new', fields={**new_fields, 'title': 'Blocked', 'slug': 'blocked'}, status=403,
        headers={'Origin': 'https://other.invalid', 'X-Forwarded-Host': host, 'X-Forwarded-Proto': 'https'})
request('/new', fields={**new_fields, 'title': 'Blocked', 'slug': 'blocked'}, status=403,
        headers={'Sec-Fetch-Site': 'cross-site'})
request('/new', fields={**new_fields, 'token': 'incorrect', 'title': 'Blocked', 'slug': 'blocked'}, status=400)
request('/new', payload=b'x' * (256 * 1024 + 1), status=413, headers={'Origin': origin})
assert b'Blocked' not in request('/')[1]

new('Web journey', 'web-test')
new('Private draft', 'web-draft')
edit('web-draft', '# Private draft', 'draft')
page = request('/media')[1]
request('/prepare-media', fields=controls(page, '/prepare-media'))
media = request('/media')[1]
assert b'action="/import"' not in media
token = controls(media, '/upload')['token']
request('/import', fields={'token': token, 'source': '/etc/passwd', 'name': 'blocked.txt'}, status=400)
boundary = 'moonpress-web-qa'
payload = (
    f'--{boundary}\r\nContent-Disposition: form-data; name="token"\r\n\r\n{token}\r\n'
    f'--{boundary}\r\nContent-Disposition: form-data; name="name"\r\n\r\nweb-image.png\r\n'
    f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="web-image.png"\r\n'
    'Content-Type: image/png\r\n\r\n'
).encode() + image + f'\r\n--{boundary}--\r\n'.encode()
request('/upload', payload=payload, headers={
    'Origin': origin, 'Content-Type': 'multipart/form-data; boundary=' + boundary
})

body = '# Published body\n\n![Example](web-image.png)\n'
saved = edit('web-test', body, 'preview_saved')
assert b'Saved and built themed preview' in saved and b'href="/preview/"' in saved
headers, preview = request('/preview/web-test.html')
assert b'Published body' in preview and 'sandbox' in headers['Content-Security-Policy']
assert headers['Cache-Control'] == 'no-store'
assert request('/preview/web-image.png')[1] == image
request('/preview/web-test.html', auth=False, status=401)
request('/site/web-test.html', auth=False, status=404)

ready = edit('web-test', body, 'ready')
plan = request('/plan-production', fields=controls(ready, '/plan-production'))[1]
build = controls(plan, '/build-production')
assert b'Publish reviewed changes' in plan and b'Planned output changes' in plan
result = request('/build-production', fields=build)[1]
assert b'Published the reviewed changes.' in result and b'href="/site/"' in result
public_headers, public_page = request('/site/web-test.html', auth=False, headers={'Sec-Fetch-Site': 'cross-site'})
assert b'Published body' in public_page and b'web-image.png' in public_page
assert 'sandbox' in public_headers['Content-Security-Policy']
assert request('/site/web-image.png', auth=False)[1] == image
assert request('/site/web-test.html', auth=False, method='HEAD')[1] == b''
request('/site/web-test.html', auth=False, status=304, headers={'If-None-Match': public_headers['Etag']})
for path in ['/site/web-draft.html', '/site/.moonpress.json', '/site/../content', '/site/%2E%2E', '/site/%2e%2e%2fpreview']:
    request(path, auth=False, status=404)

stale = request('/plan-production', fields=controls(request('/publish')[1], '/plan-production'))[1]
edit('web-test', '# Edited after review', 'save')
request('/build-production', fields=controls(stale, '/build-production'), status=400)
assert request('/site/web-test.html', auth=False)[1] == public_page
print('Hosted editor passed HTTPS login, origin/token checks, media, private preview, reviewed public output, HEAD/ETag and stale review refusal.')
