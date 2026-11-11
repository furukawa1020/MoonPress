"""Verify the Pages composer and review excerpt against real generated output."""
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

compose = runpy.run_path('scripts/create-pages-draft.py')
preview = runpy.run_path('scripts/pages-preview.py')
review = runpy.run_path('scripts/pages-review.py')
cli = Path('_build/native/release/build/cmd/main/main.exe').resolve()


def native(*args, ok=True):
    run = subprocess.run([cli, *args], capture_output=True, text=True)
    assert (run.returncode == 0) == ok, run.stderr
    return run.stdout


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    site = root / 'site'
    shutil.copytree('site', site)
    before, after, drafts = [root / name for name in ('before', 'after', 'drafts')]
    native('build', site, before)

    def create(slug, **fields):
        return compose['write_draft'](site, slug, '月の便り', 'post', '抜粋', **fields)

    article = create(
        'moon-letter', body=r'## 本文\n\n一段落。\n\n[ガイド](guide.html)',
        image='publishing-rooms.webp', alt='月の工房', visibility='ready',
        tags='月, 記事, 月', categories='制作, 日記', date='2025-11-02',
    )
    source = article.read_text()
    meta = json.loads(source.splitlines()[1])
    assert meta['draft'] is False and meta['date'] == '2025-11-02'
    assert meta['tags'] == ['月', '記事'] and meta['categories'] == ['制作', '日記']
    assert meta['description'] == '抜粋' and '## 本文\n\n一段落。' in source
    assert '![月の工房](publishing-rooms.webp)' in source
    hidden = create('secret-draft', body='独立した下書き')
    native('check', site)
    native('check', site, '--include-drafts')
    native('build', site, after)
    native('build', site, drafts, '--include-drafts')
    routes = json.loads(native('routes', site, '--include-drafts', '--json'))['report']['routes']
    assert (after / 'moon-letter.html').exists() and not (after / 'secret-draft.html').exists()
    assert (drafts / 'secret-draft.html').exists()
    base = 'https://example.test/project/'
    output = preview['render_reviews'](
        before, after, drafts, routes,
        {f'site/content/{article.name}', f'site/content/{hidden.name}'}, base,
    )
    assert '公開候補' in output and '下書き・予約など（公開対象外）' in output
    assert '月の便り' in output and '独立した下書き' in output
    assert f'<img src="{base}publishing-rooms.webp"' in output
    assert f'<a href="{base}guide.html">' in output
    assert f'<a href="{base}moon-letter.html">公開後のURL</a>' in output
    assert f'{base}secret-draft.html' not in output
    assert preview['render_reviews'](before, after, drafts, routes, set(), base) == ''
    assert 'moon-letter.html' in review['summary'](review['inventory'](after), review['inventory'](before))

    parser = preview['ReviewMarkup'](base, {'guide.html'}, {'publishing-rooms.webp'})
    parser.feed('<title>安全 &lt;例&gt;</title><main><p onclick="bad()">ok</p>'
                '<script>EXCLUDED</script><a href="javascript:x">A</a>'
                '<img src="//external.test/x" alt="代替"><img src="publishing-rooms.webp" onerror="bad()">'
                '<a href="guide.html">B</a></main>')
    safe = parser.content()
    assert 'EXCLUDED' not in safe and 'bad()' not in safe and 'javascript:' not in safe
    assert 'external.test' not in safe and '代替' in safe and f'{base}guide.html' in safe

    cases = [
        {'visibility': 'ready'}, {'body': 'a' * 16001},
        {'body': 'a\x01'}, {'tags': 'a,,b'}, {'image': '../bad.png', 'alt': 'x'},
        {'image': 'publishing-rooms.webp'}, {'alt': 'x'},
    ]
    for idx, fields in enumerate(cases):
        slug = f'bad-{idx}'
        try:
            create(slug, **fields)
        except ValueError:
            assert not (site / 'content' / f'{slug}.md').exists()
        else:
            raise AssertionError(fields)

    invalid = create('invalid-date', date='2025-02-29', body='test', visibility='ready')
    native('check', site, ok=False)
    invalid.unlink()
    pending = create('pending', body='未公開')
    invalid = create('bad-link', body='[下書き](pending.html)', visibility='ready')
    native('check', site, '--include-drafts')
    native('check', site, ok=False)
    assert pending.exists() and invalid.exists()

print('Pages compose: body, image, classification, public and draft checks, safe review excerpts and invalid inputs.')
