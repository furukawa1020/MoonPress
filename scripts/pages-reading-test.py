"""Test Pages reading settings from the workflow entry point through native builds."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
EDITOR = ROOT / 'scripts/pages-edit.py'

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    work = root / 'work'
    work.mkdir()
    site = work / 'site'
    shutil.copytree(ROOT / 'site', site)
    # Use the tracked layout and settings without inheriting live submissions.
    (site / 'public' / 'publication-status.json').unlink(missing_ok=True)
    for published in (site / 'content').glob('published-*.md'):
        published.unlink()
    config = site / 'site.json'
    summary = root / 'summary'
    original = json.loads(config.read_bytes())
    editable = {'page_size', 'tag_page_size', 'tag_index', 'collection_layout', 'feed'}

    def command(*args):
        return subprocess.check_output(args, cwd=work, stderr=subprocess.PIPE)

    def git(*args):
        return command('git', *args).decode().strip()

    for n in range(1, 4):
        metadata = {
            'title': f'記事 {n}', 'date': f'2025-01-0{n}',
            'categories': ['c'], 'tags': ['t'],
        }
        (site / 'content' / f'article-{n}.md').write_text(
            '---\n' + json.dumps(metadata, ensure_ascii=False) + '\n---\n# 記事\n',
            encoding='utf-8',
        )
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
    attempt = 0

    def run(*, changed=True, rejected=False, base=start, **fields):
        global attempt
        attempt += 1
        git('reset', '--hard', base)
        summary.unlink(missing_ok=True)
        env = {
            **os.environ, 'GITHUB_REF': 'refs/heads/main',
            'GITHUB_REPOSITORY': 'example/MoonPress', 'GITHUB_RUN_ID': '401',
            'GITHUB_RUN_ATTEMPT': str(attempt), 'GITHUB_STEP_SUMMARY': str(summary),
            'PAGES_EDIT_INPUTS': json.dumps(fields),
        }
        result = subprocess.run([sys.executable, EDITOR, CLI, '--reading'], cwd=work, env=env,
                                capture_output=True, text=True)
        assert (result.returncode != 0) == rejected, (fields, result.stderr)
        assert git('ls-remote', 'origin', 'refs/heads/main').split()[0] == start
        branch = f'moonpress-edit-401-{attempt}'
        assert bool(git('ls-remote', 'origin', f'refs/heads/{branch}')) == (changed and not rejected)
        if rejected:
            assert not summary.exists()
        elif changed:
            assert f'compare/main...{branch}' in summary.read_text()
            assert git('rev-parse', 'HEAD^') == base
            assert git('diff', '--name-only', base, 'HEAD') == 'site/site.json'
            current = json.loads(config.read_bytes())
            assert {k: v for k, v in current.items() if k not in editable} == {
                k: v for k, v in original.items() if k not in editable
            }
        else:
            assert '変更なし' in summary.read_text() and not git('status', '--porcelain')
        return git('rev-parse', 'HEAD')

    out = root / 'build'

    def build():
        command(CLI, 'build', site, out)

    def text(name):
        return (out / name).read_text(encoding='utf-8')

    def channel():
        return ElementTree.parse(out / 'rss.xml').getroot().find('channel')

    build()
    assert len(channel().findall('item')) == 3
    assert 'href="rss.xml"' in text('index.html')
    sized = run(page_size='1', tag_page_size='2', tag_index='enable', rss_limit='1',
                collection_layout='workshop.html', rss_title='月 & <灯> {{content}}',
                rss_description='説明 & <記事>')
    build()
    assert (out / 'articles-3.html').is_file()
    assert (out / 'category-63-2.html').is_file() and (out / 'tag-74-2.html').is_file()
    assert not (out / 'tag-74-3.html').exists()
    assert 'href="tag-74.html"' in text('tags.html')
    assert 'workshop-scene' in text('articles.html')
    assert channel().findtext('title') == '月 & <灯> {{content}}'
    assert channel().findtext('description') == '説明 & <記事>'
    assert [item.findtext('title') for item in channel().findall('item')] == ['記事 3']
    for page in ('index.html', 'guide.html', 'article-1.html', 'articles.html'):
        assert 'title="月 &amp; &lt;灯&gt; &#123;&#123;content}}" href="rss.xml"' in text(page)
    management = text('manage.html').split('id="reading"', 1)[1].split('id="menu"', 1)[0]
    for value in ('1 件', '2 件', 'workshop.html', '公開中', '1 件まで', 'href="rss.xml"'):
        assert value in management

    run(base=sized, rss_limit='all', tag_index='disable', page_size='all',
        tag_page_size='all', collection_layout='default')
    build()
    assert not any((out / name).exists() for name in (
        'articles-2.html', 'tag-74-2.html', 'category-63-2.html', 'tags.html',
    ))
    assert 'workshop-scene' not in text('articles.html')
    assert len(channel().findall('item')) == 3
    assert channel().findtext('description') == '説明 & <記事>'

    disabled = run(rss='disable', base=sized)
    build()
    assert not (out / 'rss.xml').exists()
    assert all('rss.xml' not in text(page) for page in (
        'index.html', 'guide.html', 'articles.html', 'article-1.html', 'manage.html',
    ))
    assert '<dt>RSS</dt><dd>無効' in text('manage.html')
    run(base=disabled, rss='disable', changed=False)
    run(base=disabled, rss_title='Title', rejected=True)
    run(base=disabled, rss='enable', rss_title='Title', rejected=True)
    run(base=disabled, rss='enable', rss_title='再開', rss_description='また配信', rss_limit='2')
    build()
    assert channel().findtext('title') == '再開' and len(channel().findall('item')) == 2
    assert 'href="rss.xml"' in text('guide.html')
    fresh = root / 'fresh'
    command(CLI, 'build', site, fresh)
    assert {p.name: p.read_bytes() for p in out.iterdir()} == {p.name: p.read_bytes() for p in fresh.iterdir()}

    run(changed=False)
    run(page_size='all', tag_page_size='all', rss_limit='all',
        collection_layout='default', tag_index='disable', changed=False)
    run(rss='disable', rss_description='矛盾', rejected=True)
    run(collection_layout='missing.html', rejected=True)
    run(collection_layout='../layout.html', rejected=True)
    for field in ('page_size', 'tag_page_size', 'rss_limit'):
        for value in ('0', '1001', '-1', '+1', '1.5'):
            run(**{field: value}, rejected=True)

print('Pages reading: independent pagination, archive layout, tag index, RSS, escaped discovery and isolated review branches.')
