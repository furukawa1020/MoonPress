"""Verify the real compiler's dashboard, draft scaffold and PR delta."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

CLI = Path('_build/native/release/build/cmd/main/main.exe').resolve()


def native(*args, ok=True):
    run = subprocess.run([CLI, *map(str, args)], capture_output=True, text=True)
    assert (run.returncode == 0) == ok, (args, run.stderr)
    return run.stdout


def document(site, name, metadata, body='Body'):
    (site / 'content' / (name + '.md')).write_text(
        '---\n' + json.dumps(metadata, ensure_ascii=False) + '\n---\n\n' + body + '\n', encoding='utf-8'
    )


def draft(site, **fields):
    values = {'slug': 'example', 'title': 'Title', 'kind': 'post', 'excerpt': '', **fields}
    env = {**os.environ, **{'DRAFT_' + key.upper(): value for key, value in values.items()}}
    return subprocess.run(
        [sys.executable, 'scripts/create-pages-draft.py', str(site)],
        env=env, capture_output=True, text=True,
    )


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    site = root / 'site'
    shutil.copytree('site', site)
    config_path = site / 'site.json'
    config = json.loads(config_path.read_text())
    document(site, '古い記事', {'title': 'Old <img onerror=test>', 'date': '2026-01-01', 'slug': 'old-url', 'categories': ['Research'], 'tags': ['日記']})
    document(site, 'fresh', {'title': 'Latest public post', 'date': '2026-02-01', 'categories': ['Research'], 'tags': ['日記']})
    document(site, 'unlisted', {'title': 'Unlisted title', 'listed': False, 'tags': ['HIDDEN_UNLISTED']})
    document(site, 'future', {'title': 'Hidden scheduled', 'publish_at': '9999-12-31T00:00:00Z', 'tags': ['HIDDEN_FUTURE']})
    document(site, '固定', {'title': 'Fixed page title', 'kind': 'page', 'tags': ['HIDDEN_FIXED']})
    document(site, 'private-taxonomy', {'title': 'Private', 'draft': True, 'tags': ['HIDDEN_DRAFT']})

    attempt = draft(site, slug='from-form', title='見出し " & <', kind='page', excerpt='説明')
    assert attempt.returncode == 0, attempt.stderr
    scaffold = site / 'content/from-form.md'
    initial = scaffold.read_bytes()
    assert json.loads(initial.decode().split('---\n', 2)[1]) == {
        'title': '見出し " & <', 'kind': 'page', 'draft': True, 'description': '説明',
    }
    assert draft(site, slug='from-form').returncode != 0 and scaffold.read_bytes() == initial
    for fields in [{'slug': '../outside'}, {'slug': 'a--b'}, {'title': 'bad\nline'}, {'kind': 'other'}, {'slug': 'a' * 65}]:
        assert draft(site, **fields).returncode != 0

    output = root / 'public'
    native('build', site, output)
    page = (output / 'manage.html').read_text()
    assert 'noindex, nofollow' in page and '<script' not in page
    assert 'Old &lt;img onerror=test&gt;' in page and 'Research、日記' in page
    assert 'edit/main/site/content/%E5%8F%A4%E3%81%84%E8%A8%98%E4%BA%8B.md' in page and 'href="old-url.html"' in page
    assert page.index('Latest public post') < page.index('Old &lt;img')
    assert page.index('Fixed page title') > page.index('<section id="pages">')
    assert 'upload/main/site/public' in page and 'src="moonpress-logo.jpg"' in page
    assert 'actions/workflows/pages-draft.yml' in page and 'actions/workflows/pages-review.yml' in page
    assert 'edit/main/site/site.json' in page and 'edit/main/site/style.css' in page
    assert all(word not in page for word in ('Unlisted title', 'Hidden scheduled', '見出し', 'from-form.md'))
    terms = page.split('<section id="taxonomy">', 1)[1].split('</section>', 1)[0]
    assert 'actions/workflows/pages-taxonomy.yml' in terms
    for name, target in [('Research', 'category-' + b'Research'.hex() + '.html'),
                         ('日記', 'tag-' + '日記'.encode().hex() + '.html')]:
        assert f'href="{target}">{name}</a> <span>(2 件)</span>' in terms
        assert (output / target).is_file()
    assert 'HIDDEN_' not in terms
    assert 'manage.html' not in (output / 'sitemap.xml').read_text()
    assert any(row['name'] == 'manage.html' for row in json.loads((output / '.moonpress.json').read_text())['artifacts'])
    native('build', site, root / 'preview', '--include-drafts')
    assert (root / 'preview/manage.html').read_bytes() == (output / 'manage.html').read_bytes()
    native('build', site, output)
    assert (output / 'manage.html').read_text() == page

    # Built output changes only after a draft is made public in the source.
    scaffold.write_bytes(initial.replace(b'"draft": true', b'"draft": false'))
    native('build', site, root / 'after')
    assert (root / 'after/from-form.html').exists()
    assert 'from-form.html' in (root / 'after/manage.html').read_text()
    before, after = root / 'before-bundle', root / 'after-bundle'
    for source, bundle in [(output, before), (root / 'after', after)]:
        subprocess.run(['bash', 'scripts/prepare-pages.sh', source, bundle], check=True)
    report = subprocess.check_output([sys.executable, 'scripts/pages-review.py', before, after], text=True)
    assert '追加 1件' in report and 'from-form.html' in report and 'manage.html' in report

    for value in [
        {'repository': '../MoonPress', 'directory': 'site'},
        {'repository': 'safe/repo', 'directory': 'site/../secret'},
        {'repository': 'https://example.org', 'directory': 'site'},
        {'repository': 'safe/repo', 'directory': '/site'},
        {'repository': 'safe/repo', 'directory': 'site', 'token': 'no'},
    ]:
        config_path.write_text(json.dumps({**config, 'pages_admin': value}))
        native('check', site, ok=False)
    config_path.write_text(json.dumps(config))
    assert draft(site, slug='manage').returncode == 0
    native('check', site, '--include-drafts', ok=False)

    (site / 'content/manage.md').unlink()
    remote = root / 'remote.git'
    checkout = root / 'checkout'
    checkout.mkdir()

    def git(*args, cwd=checkout):
        return subprocess.check_output(['git', *args], cwd=cwd, text=True, stderr=subprocess.PIPE).strip()

    git('init', '--bare', str(remote))
    git('init', '-b', 'main')
    shutil.copytree(site, checkout / 'site')
    git('add', 'site')
    git('-c', 'user.name=QA', '-c', 'user.email=qa@example.invalid', 'commit', '-m', 'Base')
    git('remote', 'add', 'origin', str(remote))
    git('push', 'origin', 'main')
    main = git('rev-parse', 'HEAD')
    git('checkout', '--detach', main)
    assert draft(checkout / 'site', slug='workflow-test', title='Workflow test').returncode == 0
    native('check', checkout / 'site', '--include-drafts')
    summary = root / 'summary.md'
    subprocess.run(
        ['bash', str(Path('scripts/save-pages-draft.sh').resolve())], cwd=checkout, check=True,
        env={**os.environ, 'GITHUB_REF': 'refs/heads/main', 'GITHUB_RUN_ID': '1234',
             'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_REPOSITORY': 'example/MoonPress',
             'GITHUB_STEP_SUMMARY': str(summary), 'DRAFT_SLUG': 'workflow-test'},
    )
    branch = 'moonpress-draft-workflow-test-1234-1'
    assert git('--git-dir', str(remote), 'rev-parse', 'refs/heads/main') == main
    created = git('--git-dir', str(remote), 'show', branch + ':site/content/workflow-test.md')
    assert '"draft": true' in created
    assert f'/edit/{branch}/site/content/workflow-test.md' in summary.read_text()
    assert f'/compare/main...{branch}?expand=1' in summary.read_text()

    git('checkout', '--detach', main)
    assert draft(
        checkout / 'site', slug='workflow-ready', title='Workflow ready',
        body='画像付き本文', image='publishing-rooms.webp', alt='月', visibility='ready',
    ).returncode == 0
    native('check', checkout / 'site', '--include-drafts')
    native('check', checkout / 'site')
    ready_summary = root / 'ready-summary.md'
    subprocess.run(
        ['bash', str(Path('scripts/save-pages-draft.sh').resolve())], cwd=checkout, check=True,
        env={**os.environ, 'GITHUB_REF': 'refs/heads/main', 'GITHUB_RUN_ID': '1234',
             'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_REPOSITORY': 'example/MoonPress',
             'GITHUB_STEP_SUMMARY': str(ready_summary), 'DRAFT_SLUG': 'workflow-ready',
             'DRAFT_VISIBILITY': 'ready'},
    )
    ready = git('--git-dir', str(remote), 'show', 'moonpress-draft-workflow-ready-1234-1:site/content/workflow-ready.md')
    assert '"draft": false' in ready and '画像付き本文' in ready
    assert git('--git-dir', str(remote), 'rev-parse', 'refs/heads/main') == main
    assert 'PRを作成する' in ready_summary.read_text()

print('Pages admin: public inventory, safe source links, no unpublished metadata, owned output, draft creation and reviewed publication verified.')
