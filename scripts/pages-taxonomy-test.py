"""Exercise taxonomy changes with the native compiler and a real Git remote."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
EDITOR = ROOT / 'scripts/pages-edit.py'
BODY = b'# Exact CRLF body\r\n\r\nLine two.\r\n'

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    work = root / 'work'
    work.mkdir()
    remote = root / 'remote.git'

    def cmd(*args):
        return subprocess.check_output(args, cwd=work, stderr=subprocess.PIPE)

    def git(*args):
        return cmd('git', *args).decode().strip()

    def post(name, **fields):
        header = json.dumps(fields, ensure_ascii=False).encode()
        (content / name).write_bytes(b'---\r\n' + header + b'\r\n---\r\n' + BODY)

    git('init', '-q', '--bare', str(remote))
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'MoonPress QA')
    git('config', 'user.email', 'qa@example.test')
    git('remote', 'add', 'origin', str(remote))
    cmd(CLI, 'init', 'site')
    content = work / 'site/content'
    post('a.md', title='A', tags=['月', 'Tag', 'tag', 'comma,term'],
         categories=['旧', '既存'], wp_id=21, description='保持')
    post('b.md', title='B', tags=['moon', '保留'], categories=['別', '旧'])
    post('draft.md', title='Draft', draft=True, tags=['月'], categories=['旧'])
    post('fixed.md', title='Fixed', kind='page', tags=['moon'], categories=['別'])
    post('future.md', title='Future', publish_at='2090-01-01T00:00:00Z',
         tags=['月'], categories=['別'])
    git('add', '.')
    git('commit', '-qm', 'Original sources')
    git('push', '-q', 'origin', 'main')
    main = git('rev-parse', 'HEAD')
    git('checkout', '--detach')
    attempt = 0

    def run(taxonomy, operation, terms, *, changed=0, rejected=False, **inputs):
        global attempt
        attempt += 1
        git('reset', '--hard', 'main')
        summary = root / 'summary'
        summary.unlink(missing_ok=True)
        env = {
            **os.environ,
            'GITHUB_REF': 'refs/heads/main',
            'GITHUB_REPOSITORY': 'example/MoonPress',
            'GITHUB_RUN_ID': '451',
            'GITHUB_RUN_ATTEMPT': str(attempt),
            'GITHUB_STEP_SUMMARY': str(summary),
            'PAGES_EDIT_INPUTS': json.dumps({
                'taxonomy': taxonomy, 'operation': operation, 'terms': terms, **inputs,
            }),
        }
        result = subprocess.run([sys.executable, EDITOR, CLI, '--taxonomy'], cwd=work, env=env,
                                capture_output=True, text=True)
        assert (result.returncode != 0) == rejected, result.stderr
        assert git('ls-remote', 'origin', 'refs/heads/main').split()[0] == main
        branch = f'moonpress-edit-451-{attempt}'
        assert bool(git('ls-remote', 'origin', f'refs/heads/{branch}')) == bool(changed)
        if changed:
            assert git('rev-parse', 'HEAD^') == main
            report = summary.read_text()
            assert f'変更した原稿 {changed} 件' in report and f'compare/main...{branch}' in report
            assert not any(name in report for name in ('draft.md', 'future.md', '# Exact CRLF'))
        elif rejected:
            assert not summary.exists()
        else:
            assert '変更なし' in summary.read_text() and not git('status', '--porcelain')

    def fields(name):
        data = (content / f'{name}.md').read_bytes()
        assert data.endswith(BODY)
        return json.loads(data.splitlines()[1])

    run('categories', 'add', '新規', files='a.md,b.md', changed=2)
    assert set(fields('a')['categories']) == {'旧', '既存', '新規'}
    assert set(fields('b')['categories']) == {'別', '旧', '新規'}
    assert fields('a')['wp_id'] == 21 and fields('a')['description'] == '保持'

    run('tags', 'add', '月, 夜', files='a.md,b.md', changed=2)
    assert set(fields('a')['tags']) == {'月', 'Tag', 'tag', 'comma,term', '夜'}

    run('categories', 'remove', '旧', files='a.md,b.md', changed=2)
    assert fields('a')['categories'] == ['既存'] and fields('draft')['categories'] == ['旧']
    run('tags', 'remove', 'Tag', files='a.md,b.md', changed=1)
    assert set(fields('a')['tags']) == {'月', 'tag', 'comma,term'}

    run('categories', 'rename', '旧', destination='既存', confirm_site=True, changed=3)
    assert fields('a')['categories'] == ['既存'] and fields('draft')['categories'] == ['既存']
    run('tags', 'rename', 'Tag', destination='tag', confirm_site=True, changed=1)
    assert set(fields('a')['tags']) == {'月', 'tag', 'comma,term'}

    run('categories', 'merge', '旧,別', destination='まとめ', confirm_site=True, changed=5)
    assert fields('a')['categories'] == ['まとめ', '既存']
    assert fields('fixed')['categories'] == ['まとめ'] and fields('future')['categories'] == ['まとめ']
    run('tags', 'merge', '月,moon', destination='夜', confirm_site=True, changed=5)
    assert fields('fixed')['tags'] == ['夜'] and fields('future')['tags'] == ['夜']
    run('tags', 'remove', '月', confirm_site=True, changed=3)

    run('tags', 'add', '月', files='a.md')
    run('tags', 'remove', 'missing', files='a.md,b.md')
    run('tags', 'rename', 'missing', destination='new', confirm_site=True)
    run('tags', 'rename', '月', destination='new', rejected=True)
    run('tags', 'merge', '月,moon', destination='new', confirm_site='true', rejected=True)
    run('tags', 'remove', '月', rejected=True)
    run('tags', 'add', '月', confirm_site=True, rejected=True)
    run('tags', 'add', '月', files='a.md,missing.md', rejected=True)
    assert not git('status', '--porcelain')
    for term in ('', '月,', '月,月', '月\n日', '月' * 33):
        run('tags', 'add', term, files='a.md', rejected=True)
    run('tags', 'merge', '月,moon', destination='moon', confirm_site=True, rejected=True)
    run('tags', 'rename', '月', destination='new', files='a.md', confirm_site=True, rejected=True)

print('Pages taxonomy: scoped add/remove, global rename/merge, exact match, safety, byte fidelity and real review branches.')
