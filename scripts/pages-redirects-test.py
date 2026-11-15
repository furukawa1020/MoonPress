"""Exercise reviewed URL moves and redirects with the native compiler and Git."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
EDITOR = ROOT / 'scripts/pages-edit.py'

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    work = root / 'work'
    work.mkdir()
    site = work / 'site'
    shutil.copytree(ROOT / 'site', site)
    config = site / 'site.json'
    content = site / 'content'
    summary = root / 'summary'
    original = json.loads(config.read_bytes())

    def command(*args):
        return subprocess.check_output(args, cwd=work, stderr=subprocess.PIPE)

    def git(*args):
        return command('git', *args).decode().strip()

    def post(name, **metadata):
        (content / name).write_text(
            '---\n' + json.dumps(metadata, ensure_ascii=False) + '\n---\n# 原稿\n',
            encoding='utf-8',
        )

    post('entry.md', title='Article', slug='記事')
    post('info.md', title='Info', kind='page', slug='案内')
    post('draft.md', draft=True)
    post('future.md', publish_at='2090-01-01T00:00:00Z')
    remote = root / 'remote.git'
    git('init', '--bare', str(remote))
    git('init', '-b', 'main')
    git('config', 'user.name', 'MoonPress QA')
    git('config', 'user.email', 'qa@example.test')
    git('remote', 'add', 'origin', str(remote))
    git('add', 'site')
    git('commit', '-m', 'Original site')
    git('push', 'origin', 'main')
    git('checkout', '--detach')
    start = git('rev-parse', 'main')
    out = root / 'dist'
    command(CLI, 'build', site, out)
    assert '登録済みの転送はありません。' in (out / 'manage.html').read_text()
    attempt = 0

    def run(operation, *, redirect=True, changed=True, rejected=False, base=start, **fields):
        global attempt
        attempt += 1
        git('reset', '--hard', base)
        summary.unlink(missing_ok=True)
        env = {
            **os.environ, 'GITHUB_REF': 'refs/heads/main',
            'GITHUB_REPOSITORY': 'example/MoonPress', 'GITHUB_RUN_ID': '765',
            'GITHUB_RUN_ATTEMPT': str(attempt), 'GITHUB_STEP_SUMMARY': str(summary),
            'PAGES_EDIT_INPUTS': json.dumps({'operation': operation, **fields}),
        }
        cmd = [sys.executable, EDITOR, CLI]
        if redirect:
            cmd.append('--redirects')
        result = subprocess.run(cmd, cwd=work, env=env, capture_output=True, text=True)
        assert (result.returncode != 0) == rejected, (fields, result.stderr)
        assert git('ls-remote', 'origin', 'refs/heads/main').split()[0] == start
        branch = f'moonpress-edit-765-{attempt}'
        assert bool(git('ls-remote', 'origin', f'refs/heads/{branch}')) == (changed and not rejected)
        if rejected:
            assert not summary.exists()
        elif changed:
            assert f'compare/main...{branch}' in summary.read_text()
            assert git('rev-parse', 'HEAD^') == base
            expected = ['site/site.json'] if redirect else [
                'site/content/' + fields['files'], 'site/site.json',
            ]
            assert git('diff', '--name-only', base, 'HEAD').splitlines() == expected
            assert {k: v for k, v in json.loads(config.read_bytes()).items() if k != 'redirects'} == original
        else:
            assert '変更なし' in summary.read_text()
            assert not git('status', '--porcelain')
        return git('rev-parse', 'HEAD')

    def redirects():
        return json.loads(config.read_bytes()).get('redirects', {})

    added = run('add', source='旧URL.html', target='記事.html')
    assert redirects() == {'旧URL.html': '記事.html'}
    command(CLI, 'build', site, out)
    html = (out / '旧URL.html').read_text()
    assert 'content="0; url=%E8%A8%98%E4%BA%8B.html"' in html
    assert 'href="https://furukawa1020.github.io/MoonPress/%E8%A8%98%E4%BA%8B.html"' in html
    assert '旧URL' not in (out / 'sitemap.xml').read_text()
    admin = (out / 'manage.html').read_text()
    assert 'href="%E6%97%A7URL.html">旧URL.html</a>' in admin
    assert 'href="%E8%A8%98%E4%BA%8B.html">記事.html</a>' in admin
    fresh = root / 'fresh'
    command(CLI, 'build', site, fresh)
    assert {p.name: p.read_bytes() for p in out.iterdir()} == {p.name: p.read_bytes() for p in fresh.iterdir()}
    run('update', source='旧URL.html', target='記事.html', base=added, changed=False)
    run('update', source='旧URL.html', target='guide.html', base=added)
    assert redirects() == {'旧URL.html': 'guide.html'}
    run('remove', source='旧URL.html', base=added)
    command(CLI, 'build', site, out)
    assert not (out / '旧URL.html').exists()
    assert '登録済みの転送はありません。' in (out / 'manage.html').read_text()
    run('add', source='旧URL.html', target='guide.html', base=added, rejected=True)

    extra = run('add', source='older.html', target='旧URL.html', base=added)
    run('update', source='旧URL.html', target='older.html', base=extra, rejected=True)
    run('remove', source='旧URL.html', base=extra, rejected=True)
    for source, target in [
        ('loop.html', 'loop.html'), ('guide.html', '記事.html'),
        ('old.html', 'missing.html'), ('old.html', 'draft.html'), ('old.html', 'future.html'),
        ('old.html', 'https://example.test/path.html'), ('../old.html', 'guide.html'),
        ('old.html', 'guide.html?q=x'), ('old.html', 'guide.html#part'),
        ('old.html', '%2e%2e.html'),
    ]:
        run('add', source=source, target=target, rejected=True)
    for action in ('remove', 'update'):
        run(action, source='missing.html', **({'target': 'guide.html'} if action == 'update' else {}),
            rejected=True)

    first = run('edit', redirect=False, files='entry.md', slug='新しい記事', keep_old_url=True)
    assert redirects() == {'記事.html': '新しい記事.html'}
    second = run('edit', redirect=False, files='entry.md', slug='final', keep_old_url=True, base=first)
    assert redirects() == {'記事.html': '新しい記事.html', '新しい記事.html': 'final.html'}
    command(CLI, 'build', site, out)
    for name in ('記事.html', '新しい記事.html'):
        assert 'content="0; url=final.html"' in (out / name).read_text()
    run('edit', redirect=False, files='entry.md', slug='記事', keep_old_url=True, base=second)
    assert redirects() == {'final.html': '記事.html', '新しい記事.html': 'final.html'}
    run('edit', redirect=False, files='info.md', clear='slug', keep_old_url=True)
    assert redirects() == {'案内.html': 'info.html'}
    run('edit', redirect=False, files='entry.md', slug='記事', keep_old_url=True, changed=False)
    for fields in [
        {'files': 'draft.md', 'slug': 'new-draft'},
        {'files': 'entry.md', 'slug': 'guide'},
        {'files': 'entry.md', 'slug': 'later', 'publish_at': '2090-01-01T00:00:00Z'},
        {'files': 'entry.md', 'slug': 'invisible', 'visibility': 'draft'},
        {'files': 'entry.md'}, {'files': 'entry.md,info.md', 'slug': 'later'},
    ]:
        run('edit', redirect=False, keep_old_url=True, rejected=True, **fields)

print('Pages redirects: safe URL operations, old links, chained moves, private-target refusal, incremental parity and Git review isolation.')
