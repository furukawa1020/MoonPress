"""Exercise the real compiler and the Actions edit script with a local remote."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
EDITOR = ROOT / 'scripts/pages-edit.py'


def command(cwd, *args):
    return subprocess.check_output(args, cwd=cwd).strip()


with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    remote = root / 'remote'
    work = root / 'work'
    work.mkdir()

    def git(*args):
        return command(work, 'git', *args)

    command(root, 'git', 'init', '-q', '--bare', remote)
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'MoonPress Tests')
    git('config', 'user.email', 'moonpress@example.test')
    git('remote', 'add', 'origin', remote)
    command(work, CLI, 'init', 'site')
    site = work / 'site'
    content = site / 'content'
    (site / 'layouts').mkdir(exist_ok=True)
    (site / 'layouts' / 'wide.html').write_text('<main>{{content}}</main>', encoding='utf-8')
    body = b'# Body\r\n\r\nOriginal line.\r\n'
    legacy = b'---\r\n{"title":"Old","slug":"existing","description":"Keep","tags":["keep"],"wp_id":16}\r\n---\r\n' + body
    source = content / 'entry.md'
    source.write_bytes(legacy)
    (content / 'other.md').write_text('# Other\n', encoding='utf-8')
    (content / 'scheduled.md').write_text(
        '---\n{"title":"Scheduled","draft":true,"publish_at":"2035-12-01T00:00:00Z"}\n---\n# Later\n',
        encoding='utf-8',
    )
    git('add', 'site')
    git('commit', '-qm', 'Old version')
    revision = git('rev-parse', 'HEAD').decode()

    source.write_bytes(legacy.replace(b'"Old"', b'"Current"'))
    (content / 'index.md').write_text('# Home\n\n[Read](existing.html)\n', encoding='utf-8')
    git('add', 'site')
    git('commit', '-qm', 'Current version')
    git('push', '-q', 'origin', 'main')
    main = git('rev-parse', 'HEAD')
    command(work, CLI, 'check', 'site')
    git('checkout', '-q', '--detach')

    def run(attempt, *, reject=False, **inputs):
        env = dict(os.environ, GITHUB_REF='refs/heads/main', GITHUB_REPOSITORY='example/MoonPress',
                   GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT=str(attempt),
                   GITHUB_STEP_SUMMARY=str(root / 'summary'),
                   PAGES_EDIT_INPUTS=json.dumps({'operation': 'edit', 'files': 'entry.md', **inputs}))
        p = subprocess.run([sys.executable, EDITOR, CLI], env=env, cwd=work,
                           capture_output=True, text=True)
        assert (p.returncode != 0) == reject, (inputs, p.stdout, p.stderr)
        ref = f'refs/heads/moonpress-edit-123-{attempt}'
        sha = git('ls-remote', 'origin', ref)
        assert git('ls-remote', 'origin', 'refs/heads/main').split()[0] == main
        if sha:
            assert git('rev-list', '--parents', '-n', '1', 'HEAD').split()[1:] == [main]
        return sha

    def metadata(name):
        return json.loads((content / name).read_bytes().splitlines()[1])

    def reset():
        git('reset', '--hard', 'main')
        git('clean', '-fd')

    assert run(1, title='編集済み', date='2025-12-31', tags='技術, 月',
               categories='制作, 記事', layout='wide.html', kind='page',
               listing='unlist', clear='excerpt')
    edited = metadata('entry.md')
    assert edited == {'title': '編集済み', 'slug': 'existing', 'date': '2025-12-31',
                      'tags': ['技術', '月'], 'categories': ['制作', '記事'],
                      'layout': 'wide.html', 'kind': 'page', 'listed': False, 'wp_id': 16}, edited
    assert source.read_bytes().endswith(body)
    assert git('diff', '--name-only', 'main') == b'site/content/entry.md'
    assert 'compare/main...moonpress-edit-123-1?expand=1' in (root / 'summary').read_text()
    reset()

    assert run(2, files='entry.md, other.md', categories='運用', listing='unlist')
    assert metadata('entry.md')['categories'] == metadata('other.md')['categories'] == ['運用']
    assert git('diff', '--name-only', 'main').splitlines() == [b'site/content/entry.md', b'site/content/other.md']
    reset()

    assert run(3, operation='duplicate', title='Copy', copy_to='copy')
    assert source.read_bytes() == legacy.replace(b'"Old"', b'"Current"')
    copy = metadata('copy.md')
    assert copy['draft'] and 'wp_id' not in copy and 'slug' not in copy
    command(work, CLI, 'build', 'site', root / 'production')
    assert not (root / 'production' / 'copy.html').exists()
    command(work, CLI, 'build', 'site', root / 'preview', '--include-drafts')
    assert (root / 'preview' / 'copy.html').exists()
    reset()

    assert run(4, operation='restore', revision=revision)
    assert source.read_bytes() == legacy
    reset()

    assert not run(5, title='Current')
    assert not run(6)
    assert '変更なし' in (root / 'summary').read_text()
    cases = [
        {'files': '../entry.md'}, {'files': 'entry.md,entry.md'},
        {'files': 'entry.md,missing.md', 'excerpt': 'all or none'},
        {'files': ','.join(f'page-{n}.md' for n in range(21))},
        {'files': 'entry.md,other.md', 'title': 'Ambiguous'},
        {'clear': 'date', 'date': '2025-12-31'}, {'date': '2025-02-30'},
        {'slug': 'other'}, {'slug': 'new-url'}, {'layout': 'missing.html'},
        {'visibility': 'draft'}, {'publish_at': '2035-12-01T00:00:00Z'},
        {'publish_at': '2035-12-01T00:00:00+01:00'},
        {'operation': 'duplicate', 'title': 'Overwrite', 'copy_to': 'other'},
        {'operation': 'restore', 'revision': revision[:8]},
        {'operation': 'restore', 'revision': '0' * 40},
    ]
    for attempt, inputs in enumerate(cases, start=7):
        assert not run(attempt, reject=True, **inputs)
        reset()

    assert run(23, files='other.md', visibility='ready', publish_at='2035-12-01T00:00:00Z')
    assert metadata('other.md')['publish_at'] == '2035-12-01T00:00:00Z'
    command(work, CLI, 'build', 'site', root / 'scheduled')
    assert not (root / 'scheduled' / 'other.html').exists()
    reset()
    assert run(24, files='scheduled.md', operation='duplicate', title='Scheduled copy', copy_to='scheduled-copy')
    scheduled = metadata('scheduled-copy.md')
    assert scheduled['draft'] and 'publish_at' not in scheduled
    reset()

    assert run(25, files='other.md', slug='renamed', excerpt='New description', kind='page')
    command(work, CLI, 'build', 'site', root / 'renamed')
    assert not (root / 'renamed' / 'other.html').exists()
    assert 'New description' in (root / 'renamed' / 'renamed.html').read_text()
    assert 'renamed.html' not in (root / 'renamed' / 'articles.html').read_text()
    reset()

    assert run(26, files='other.md', visibility='draft')
    assert metadata('other.md')['draft']
    command(work, CLI, 'build', 'site', root / 'drafted')
    assert not (root / 'drafted' / 'other.html').exists()
    reset()

    patch = root / 'patch.json'
    patch.write_text('{"body":"unexpected"}')
    digest = json.loads(command(work, CLI, 'read', 'site', 'entry.md', '--json'))['report']['digest']
    for expected in (digest, '0' * 64):
        result = subprocess.run([CLI, 'pages-patch', 'site', 'entry.md', expected, patch],
                                cwd=work, capture_output=True)
        assert result.returncode == 1 and not git('status', '--porcelain')

print('Pages edits: metadata, original bytes, bulk, draft copy, restore, no-op and rejected changes against a real Git remote.')
