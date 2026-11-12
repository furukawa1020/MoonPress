"""Exercise the workflow entry point with the real native compiler and a source snapshot."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/release/build/cmd/main/main.exe'
SCRIPT = ROOT / 'scripts/pages-inventory.py'
REPO = 'example/MoonPress'
SHA = '3b' * 20
PUBLIC = 'https://example.github.io/MoonPress/'
BODY = 'body-marker-must-not-be-in-the-inventory'


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    site = root / 'site'
    content = site / 'content'
    content.mkdir(parents=True)
    (site / 'site.json').write_text(json.dumps({'base_url': PUBLIC}), encoding='utf-8')
    summary = root / 'summary.md'

    def post(name, **metadata):
        (content / name).write_text(
            '---\n' + json.dumps(metadata, ensure_ascii=False) + '\n---\n' + BODY + '\n',
            encoding='utf-8',
        )

    def run(ok=True, **inputs):
        summary.unlink(missing_ok=True)
        result = subprocess.run(
            [sys.executable, SCRIPT, CLI, site],
            env={
                **os.environ,
                'PAGES_INVENTORY_INPUTS': json.dumps(inputs),
                'GITHUB_REPOSITORY': REPO,
                'GITHUB_SHA': SHA,
                'GITHUB_STEP_SUMMARY': str(summary),
            },
            capture_output=True, text=True,
        )
        assert (result.returncode == 0) == ok, result.stderr
        if not ok:
            assert not summary.exists()
            return result.stderr
        assert not result.stdout and not result.stderr
        report = summary.read_text(encoding='utf-8')
        assert BODY not in report
        return report

    def snapshot():
        return {path.relative_to(site): path.read_bytes() for path in site.rglob('*') if path.is_file()}

    post('a.md', title='Zebra', date='2025-01-01')
    post('b.md', title='Zebra', date='2025-01-01')
    post('p.md', kind='page', title='Alpha 砂漠 <script>alert(1)</script>\nNext',
         date='2026-03-01', tags=['TAG甲'], categories=['運用'], slug='表紙')
    post('offline name.md', title='NONINDEX', listed=False)
    post('draft.md', title='DRAFTONLY', draft=True, publish_at='2090-01-02T00:00:00Z')
    post('future.md', title='FUTUREONLY', publish_at='2090-01-02T00:00:00Z')
    post('released.md', title='EARLIER', publish_at='2001-01-02T00:00:00Z')
    post('name-needle.md', title='OTHER')
    before = snapshot()

    native = json.loads(subprocess.check_output([CLI, 'pages-inventory', site, '--json']))
    assert native['schema'] == 1 and native['include_drafts']
    assert {row['title']: row['status'] for row in native['report'] if row['title'].isupper()} == {
        'NONINDEX': 'unlisted', 'DRAFTONLY': 'draft', 'FUTUREONLY': 'scheduled',
        'EARLIER': 'published', 'OTHER': 'published',
    }
    assert BODY not in json.dumps(native)
    default = run()
    assert '5 件 · 1 / 1 ページ' in default and 'EARLIER' in default
    assert all(value not in default for value in ('NONINDEX', 'DRAFTONLY', 'FUTUREONLY', '2090-01-02'))
    assert all(value not in run(query='FUTUREONLY') for value in ('FUTUREONLY', 'future.md'))
    assert run(ok=False, status='draft').count('チェック欄') == 1
    for bad in ({'page': '0'}, {'page': '1e2'}, {'status': 'missing'}, {'share_unlisted_and_drafts': 'true'}):
        run(ok=False, **bad)

    filtered = run(kind='page', status='published', query='ALPHA 砂漠', tag='tag甲', category='運用')
    assert '1 件 · 1 / 1 ページ' in filtered and '固定ページ' in filtered
    assert '&lt;script&gt;alert(1)&lt;/script&gt; Next' in filtered and '<script>' not in filtered
    assert PUBLIC + '%E8%A1%A8%E7%B4%99.html' in filtered
    assert f'/blob/{SHA}/site/content/p.md' in filtered
    assert f'/commit/{SHA}' in filtered
    assert '/edit/main/site/content/p.md' in filtered and '/commits/main/site/content/p.md' in filtered
    assert '該当する項目がありません。' in run(kind='post', query='砂漠')
    assert '該当する項目がありません。' in run(tag='TAG')
    assert '該当する項目がありません。' in run(category='別のカテゴリー')
    assert 'OTHER' in run(query='NEEDLE.MD')

    unlisted = run(status='unlisted', share_unlisted_and_drafts=True)
    assert 'NONINDEX' in unlisted and 'FUTUREONLY' not in unlisted
    assert PUBLIC + 'offline%20name.html' in unlisted
    assert '/edit/main/site/content/offline%20name.md' in unlisted
    draft = run(status='draft', share_unlisted_and_drafts=True)
    assert 'DRAFTONLY' in draft and 'FUTUREONLY' not in draft and '公開URL' not in draft
    future = run(status='scheduled', share_unlisted_and_drafts=True)
    assert 'FUTUREONLY' in future and 'DRAFTONLY' not in future and '公開URL' not in future
    assert '2090-01-02 09:00:00 JST' in future
    assert default.index('砂漠') < default.index('Zebra')
    oldest = run(order='oldest')
    assert oldest.index('Zebra') < oldest.index('砂漠') < oldest.index('EARLIER')
    titled = run(order='title')
    assert titled.index('Alpha') < titled.index('EARLIER') < titled.index('Zebra')
    for report in (default, oldest, titled):
        assert report.index('content/a.md') < report.index('content/b.md')
    assert snapshot() == before

    for n in range(51):
        post(f'listing-{n:02}.md', title=f'Listing {n:02}', tags=['pagination'])
    first = run(tag='pagination', order='title')
    second = run(tag='pagination', order='title', page='2')
    assert '51 件 · 1 / 2 ページ' in first and '1〜50 件目' in first
    assert 'Listing 49' in first and 'Listing 50' not in first
    assert '51 件 · 2 / 2 ページ' in second and '51〜51 件目' in second
    assert 'Listing 50' in second and 'Listing 49' not in second
    assert '該当する項目がありません。' in run(tag='pagination', page='3')

print('Pages inventory: exact snapshot, states, disclosure, search, sorting, pagination, URLs, read-only source.')
