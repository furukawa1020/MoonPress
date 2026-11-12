"""Exercise Pages image replacement with a real compiler and Git remote."""
from hashlib import sha256
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
SCRIPT = ROOT / 'scripts/pages-media.py'


def png(red):
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data))
    header = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(bytes([0, red, 0, 0]))) + chunk(b'IEND', b'')


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    work = root / 'work'
    work.mkdir()

    def command(*args):
        return subprocess.check_output(args, cwd=work)

    def git(*args):
        return command('git', *args).strip()

    git('init', '-q', '--bare', root / 'remote')
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'Media Test')
    git('config', 'user.email', 'test@example.test')
    git('remote', 'add', 'origin', root / 'remote')
    command(CLI, 'init', 'site')
    site = work / 'site'
    public = site / 'public'
    public.mkdir(exist_ok=True)
    target = '月 & lamp.PNG'
    old, new = png(1), png(2)
    expected = sha256(old).hexdigest()
    (public / target).write_bytes(old)
    (public / 'font.txt').write_text('non-image')
    (site / 'content/index.md').write_text('# Home\n\n![Lamp](%E6%9C%88%20%26%20lamp.PNG)\n')
    config = json.loads((site / 'site.json').read_bytes())
    config['pages_admin'] = {'repository': 'example/MoonPress', 'directory': 'site'}
    (site / 'site.json').write_text(json.dumps(config))
    git('add', 'site')
    git('commit', '-qm', 'Base')
    git('push', '-q', 'origin', 'main')
    main = git('rev-parse', 'HEAD')
    command(CLI, 'build', 'site', root / 'before')
    dashboard = (root / 'before/manage.html').read_text()
    assert '画像' in dashboard and 'その他のファイル' in dashboard and '月 &amp; lamp.PNG' in dashboard
    assert expected in dashboard and f'{len(old)} B' in dashboard
    assert '/upload/main/site/media-inbox' in dashboard and '/actions/workflows/pages-media.yml' in dashboard

    git('checkout', '-qb', 'staged/image')
    inbox = site / 'media-inbox'
    inbox.mkdir()
    (inbox / '候補.PNG').write_bytes(new)
    (inbox / 'same.png').write_bytes(old)
    (inbox / 'wrong.png').write_bytes(b'not a PNG')
    (inbox / 'oversize.png').write_bytes(b'\0' * (8 * 1024 * 1024 + 1))
    (inbox / 'alias.png').symlink_to('候補.PNG')
    (site / 'content/index.md').write_text('# Staging content must not reach the review branch')
    git('add', 'site')
    git('commit', '-qm', 'Upload')
    revision = git('rev-parse', 'HEAD').decode()
    git('push', '-q', 'origin', 'staged/image')
    git('checkout', '-q', '--detach', 'main')

    def run(attempt, *, reject=False, **overrides):
        summary = root / f'summary-{attempt}'
        inputs = {'target': target, 'source': '候補.PNG', 'upload_branch': 'staged/image', 'version': expected}
        env = dict(os.environ, GITHUB_REF='refs/heads/main', GITHUB_REPOSITORY='example/MoonPress',
                   GITHUB_RUN_ID='12', GITHUB_RUN_ATTEMPT=str(attempt), GITHUB_STEP_SUMMARY=str(summary),
                   PAGES_MEDIA_INPUTS=json.dumps({**inputs, **overrides}))
        result = subprocess.run([sys.executable, SCRIPT, CLI], cwd=work, env=env, capture_output=True)
        assert (result.returncode != 0) == reject, result.stderr
        branch = f'moonpress-media-12-{attempt}'
        ref = git('ls-remote', 'origin', f'refs/heads/{branch}')
        assert git('ls-remote', 'origin', 'refs/heads/main').split()[0] == main
        return ref, summary

    assert not run(1, source='same.png')[0]
    for index, values in enumerate([
        {'version': '0' * 64}, {'source': '../候補.PNG'}, {'source': 'wrong.png'},
        {'source': 'oversize.png'}, {'source': 'alias.png'}, {'source': 'absent.png'},
        {'target': '../月 & lamp.PNG'}, {'source': 'candidate.jpg'},
        {'upload_branch': 'gh-pages'}, {'upload_branch': 'staged/../image'},
    ], start=2):
        assert not run(index, reject=True, **values)[0]
        assert not git('status', '--porcelain')

    ref, summary = run(20)
    assert ref and b'site/public/' in git('diff', '--name-only', 'main')
    assert git('diff', '--name-only', '--no-renames', 'main').count(b'\n') == 0
    assert (public / target).read_bytes() == new
    assert not inbox.exists()
    assert revision in summary.read_text() and expected in summary.read_text()
    assert 'compare/main...moonpress-media-12-20' in summary.read_text()
    command(CLI, 'build', 'site', root / 'after')
    assert (root / 'after' / target).read_bytes() == new
    assert (root / 'before/index.html').read_bytes() == (root / 'after/index.html').read_bytes()
    assert sha256(new).hexdigest() in (root / 'after/manage.html').read_text()

print('Pages media: metadata, versioning, branch isolation, same URL, no-op and unsafe candidate rejection.')
