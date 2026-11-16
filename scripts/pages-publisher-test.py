"""Check signed publication from queue records to compiled public routes."""

import base64
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
functions = runpy.run_path(str(ROOT / 'scripts/pages-publisher.py'))
import_items = functions['import_items']
receipt = functions['receipt']

with tempfile.TemporaryDirectory() as temp:
    directory = Path(temp)
    private = directory / 'private.pem'
    public = directory / 'public.pem'
    subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048',
                    '-out', private], check=True, stderr=subprocess.DEVNULL)
    subprocess.run(['openssl', 'pkey', '-in', private, '-pubout', '-out', public], check=True)

    def article(seq, slug, kind='post'):
        payload = json.dumps({'title': '公開された記事 ' + str(seq), 'slug': slug,
                              'kind': kind, 'markdown': '本文と **太字**'}, ensure_ascii=False)
        signature = subprocess.check_output(['openssl', 'dgst', '-sha256', '-sign', private],
                                            input=payload.encode())
        return {'seq': seq, 'payload': payload, 'signature': base64.b64encode(signature).decode()}

    site = directory / 'site'
    shutil.copytree(ROOT / 'site', site)
    first = article(1, '公開記事')
    malformed = article(2, 'forged')
    malformed['payload'] = malformed['payload'].replace('太字', '変更')

    try:
        import_items(CLI, site, [first, malformed], public)
    except subprocess.CalledProcessError:
        pass
    else:
        raise AssertionError('Tampered body accepted')
    assert receipt(site)['cursor'] == 0
    assert not (site / 'content' / 'published-1.md').exists()

    second = article(2, 'room-write')  # Existing public route.
    third = article(3, 'fixed-page', 'page')
    import_items(CLI, site, [first, second, third], public)
    assert receipt(site) == {'cursor': 3, 'entries': {
        '公開記事': 'published', 'room-write': 'rejected', 'fixed-page': 'published',
    }}
    assert not (site / 'content' / 'published-2.md').exists()
    out = directory / 'out'
    subprocess.run([CLI, 'build', site, out], check=True, capture_output=True)
    assert '<strong>太字</strong>' in (out / '公開記事.html').read_text()
    assert '公開された記事 1' in (out / 'articles.html').read_text()
    assert '公開された記事 3' not in (out / 'articles.html').read_text()
    assert '公開された記事 3' in (out / 'fixed-page.html').read_text()
    assert json.loads((out / 'publication-status.json').read_bytes()) == receipt(site)

    try:
        import_items(CLI, site, [first], public)
    except ValueError:
        pass
    else:
        raise AssertionError('An already imported record was accepted')

print('Pages publication: signed input, tamper and replay rejection, URL collisions, post index and stable page routes.')
