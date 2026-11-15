"""Exercise navigation editing with the native compiler and a real Git remote."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
EDITOR = ROOT / 'scripts/pages-edit.py'


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    work = root / 'checkout'
    work.mkdir()
    remote = root / 'remote.git'
    site = work / 'site'
    shutil.copytree(ROOT / 'site', site)
    settings = site / 'site.json'

    def command(*args):
        return subprocess.check_output(args, cwd=work, stderr=subprocess.PIPE)

    def git(*args):
        return command('git', *args).decode().strip()

    def settings_data():
        return json.loads(settings.read_bytes())

    def urls():
        return [item['url'] for item in settings_data()['menu']]

    def menu_links(directory, path):
        body = (directory / path).read_text(encoding='utf-8')
        return re.search(r'<nav aria-label="メインメニュー">(.*?)</nav>', body).group(1)

    (site / 'content' / 'ordinary.md').write_text('# Plain article\n', encoding='utf-8')
    (site / 'content' / '月の便り.md').write_text('# 便り\n', encoding='utf-8')
    (site / 'content' / 'draft-test.md').write_text(
        '---\n{"draft":true}\n---\n# Draft\n', encoding='utf-8',
    )
    git('init', '-q', '--bare', str(remote))
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'MoonPress QA')
    git('config', 'user.email', 'qa@example.test')
    git('remote', 'add', 'origin', str(remote))
    git('add', '.')
    git('commit', '-qm', 'Original sources')
    git('push', '-q', 'origin', 'main')
    main = git('rev-parse', 'HEAD')
    git('checkout', '--detach')
    before = settings_data()
    assert urls() == ['index.html', 'manage.html', 'guide.html', 'https://github.com/furukawa1020/MoonPress']
    out = root / 'incremental'
    command(CLI, 'build', site, out)
    original_links = menu_links(out, 'index.html')

    attempt = 0

    def run(operation, url, *, changed=True, rejected=False, **fields):
        global attempt
        attempt += 1
        git('reset', '--hard', 'main')
        summary = root / 'summary'
        summary.unlink(missing_ok=True)
        env = {
            **os.environ,
            'GITHUB_REF': 'refs/heads/main',
            'GITHUB_REPOSITORY': 'example/MoonPress',
            'GITHUB_RUN_ID': '752',
            'GITHUB_RUN_ATTEMPT': str(attempt),
            'GITHUB_STEP_SUMMARY': str(summary),
            'PAGES_EDIT_INPUTS': json.dumps({'operation': operation, 'url': url, **fields}),
        }
        result = subprocess.run(
            [sys.executable, EDITOR, CLI, '--menu'], cwd=work, env=env, capture_output=True, text=True,
        )
        assert (result.returncode != 0) == rejected, result.stderr
        assert git('ls-remote', 'origin', 'refs/heads/main').split()[0] == main
        branch = f'moonpress-edit-752-{attempt}'
        assert bool(git('ls-remote', 'origin', f'refs/heads/{branch}')) == (changed and not rejected)
        if rejected:
            assert not summary.exists()
        elif not changed:
            assert '変更なし' in summary.read_text() and not git('status', '--porcelain')
        else:
            assert f'compare/main...{branch}' in summary.read_text()
            assert git('diff', '--name-only', main, 'HEAD') == 'site/site.json'
            assert git('rev-parse', 'HEAD^') == main
            assert {k: v for k, v in settings_data().items() if k != 'menu'} == {
                k: v for k, v in before.items() if k != 'menu'
            }

    run('add', '月の便り.html', label='月 <b>\u0026 {{content}}', position='2')
    assert urls()[1] == '月の便り.html'
    clean = root / 'clean'
    command(CLI, 'build', site, out)
    command(CLI, 'build', site, clean)
    assert {p.name: p.read_bytes() for p in out.iterdir()} == {p.name: p.read_bytes() for p in clean.iterdir()}
    links = menu_links(out, 'index.html')
    assert links != original_links
    for page in ('guide.html', 'ordinary.html', 'articles.html', 'room-write.html'):
        assert menu_links(out, page) == links
    assert 'href="%E6%9C%88%E3%81%AE%E4%BE%BF%E3%82%8A.html"' in links
    assert '月 &lt;b&gt;&amp; &#123;&#123;content}}' in links
    admin = (out / 'manage.html').read_text()
    menu = admin.split('id="menu"', 1)[1].split('</section>', 1)[0]
    assert 'actions/workflows/pages-menu.yml' in menu
    assert 'index.html' in menu and menu.index('index.html') < menu.index('月の便り.html')

    run('add', 'https://example.test/a?q=one&n=2#details', label='外部')
    assert urls()[-1] == 'https://example.test/a?q=one&n=2#details'
    command(CLI, 'build', site, out)
    assert 'https://example.test/a?q=one&amp;n=2#details' in menu_links(out, 'guide.html')
    run('edit', 'guide.html', label='説明')
    assert settings_data()['menu'][2] == {'label': '説明', 'url': 'guide.html'}
    run('edit', 'guide.html', new_url='ordinary.html')
    assert settings_data()['menu'][2] == {'label': '使い方', 'url': 'ordinary.html'}
    run('move', 'guide.html', position='1')
    assert urls()[0] == 'guide.html'
    run('move', 'index.html', position='4')
    assert urls()[-1] == 'index.html'
    run('remove', 'guide.html')
    assert 'guide.html' not in urls()
    run('edit', 'guide.html', label='使い方', changed=False)
    run('move', 'guide.html', position='3', changed=False)

    for url in ('missing.html', 'draft-test.html', 'javascript:alert(1)', '//example.test',
                'https://', 'http://example.test', 'https://example.test@else.test/', '../guide.html',
                'guide.html#x', 'guide.html', 'https://example.test/"><img>'):
        run('add', url, label='拒否', rejected=True)
    run('add', 'ordinary.html', label='位置', position='6', rejected=True)
    run('add', 'ordinary.html', label='位置', position='0', rejected=True)
    run('edit', 'guide.html', new_url='manage.html', rejected=True)
    run('remove', 'missing.html', rejected=True)
    run('move', 'guide.html', position='1', label='矛盾', rejected=True)

print('Pages menu: HTML layouts, URL validation, incremental parity, all edit operations, and isolated Git review branches.')
