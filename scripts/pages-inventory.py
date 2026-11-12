"""Render a read-only summary for the Pages editorial workflow."""

import argparse
from datetime import datetime, timedelta, timezone
from html import escape
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import quote, urlsplit

PAGE_SIZE = 50
STATUSES = {
    'published': '公開対象・掲載',
    'unlisted': '公開対象・一覧非掲載',
    'draft': '下書き',
    'scheduled': '予約済み',
}
KINDS = {'post': '投稿', 'page': '固定ページ'}
ORDERS = {'newest': '日付の新しい順', 'oldest': '日付の古い順', 'title': 'タイトル順'}
JST = timezone(timedelta(hours=9))


def select(rows, inputs):
    shared = inputs.get('share_unlisted_and_drafts', False)
    status = inputs.get('status', 'all')
    kind = inputs.get('kind', 'all')
    order = inputs.get('order', 'newest')
    page = inputs.get('page', '').strip() or '1'
    terms = {key: inputs.get(key, '').strip().casefold() for key in ('query', 'tag', 'category')}
    if (
        not isinstance(shared, bool)
        or status not in (*STATUSES, 'all')
        or kind not in (*KINDS, 'all')
        or order not in ORDERS
        or not re.fullmatch(r'[1-9][0-9]{0,4}', page)
        or any(len(term) > 160 for term in terms.values())
    ):
        raise ValueError('投稿一覧の絞り込み条件を確認してください。')
    if status in ('unlisted', 'draft', 'scheduled') and not shared:
        raise ValueError('この状態を集計するには、サマリーの共有範囲を確認してチェック欄を選択してください。')

    selected = [
        row for row in rows
        if (shared or row['status'] == 'published')
        and (status == 'all' or row['status'] == status)
        and (kind == 'all' or row['kind'] == kind)
        and any(terms['query'] in row[field].casefold() for field in ('title', 'source'))
        and (not terms['tag'] or any(terms['tag'] == tag.casefold() for tag in row['tags']))
        and (
            not terms['category']
            or any(terms['category'] == category.casefold() for category in row['categories'])
        )
    ]
    selected.sort(key=lambda row: row['source'])
    if order == 'title':
        selected.sort(key=lambda row: row['title'].casefold())
    else:
        dated = sorted(
            (row for row in selected if row.get('date')),
            key=lambda row: row['date'],
            reverse=order == 'newest',
        )
        selected = dated + [row for row in selected if not row.get('date')]
    return selected, int(page), order, shared


def timestamp(value):
    if not value:
        return '—'
    utc = datetime.fromisoformat(value[:-1] + '+00:00')
    try:
        local = utc.astimezone(JST)
    except OverflowError:
        # The compiler accepts all Gregorian years through 9999.
        return f'{value} (UTC)'
    return local.isoformat(sep=' ', timespec='seconds').removesuffix('+09:00') + ' JST'


def cell(value, limit=160):
    text = ' '.join(value.split())
    return escape(text[:limit] + ('…' if len(text) > limit else ''))


def link(url, label):
    return f'<a href="{escape(url, quote=True)}">{cell(label)}</a>'


def render(rows, inputs, repo, revision, base_url):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo) or not re.fullmatch(r'[a-f0-9]{40}', revision):
        raise ValueError('対象リポジトリまたはコミットを確認できません。')
    public = urlsplit(base_url)
    if public.scheme not in ('http', 'https') or not public.netloc or public.query or public.fragment:
        raise ValueError('サイトの base_url を確認してください。')
    repo_url = 'https://github.com/' + repo
    selected, page, order, shared = select(rows, inputs)
    start = (page - 1) * PAGE_SIZE
    visible = selected[start:start + PAGE_SIZE]
    total_pages = max(1, (len(selected) + PAGE_SIZE - 1) // PAGE_SIZE)
    lines = [
        '## 投稿一覧',
        '',
        f'<p>対象コミット {link(repo_url + "/commit/" + revision, revision)}</p>',
        f'表示順 {ORDERS[order]} · {len(selected)} 件 · {page} / {total_pages} ページ',
        '',
        ('一覧非掲載・下書き・予約の情報を含みます。' if shared else '掲載する公開対象のみを表示しています。'),
        '公開状態は対象コミットの原稿から判定します。実際の反映は Pages 公開結果で確認できます。',
        '',
    ]
    if not visible:
        lines.append('該当する項目がありません。絞り込み条件またはページ番号を変更して再実行してください。')
        return '\n'.join(lines) + '\n'

    lines.extend([
        f'{start + 1}〜{start + len(visible)} 件目を表示',
        '',
        '<table><thead><tr><th>タイトル・原稿</th><th>種類・状態</th><th>日付</th>'
        '<th>公開予約</th><th>カテゴリー・タグ</th><th>操作</th></tr></thead><tbody>',
    ])
    for row in visible:
        source = 'site/' + quote(row['source'], safe='/')
        actions = [
            link(f'{repo_url}/blob/{revision}/{source}', '原稿'),
            link(f'{repo_url}/edit/main/{source}', '編集'),
            link(f'{repo_url}/commits/main/{source}', '履歴'),
        ]
        if row['status'] in ('published', 'unlisted'):
            url = base_url.rstrip('/') + '/' + quote(row['output'], safe='')
            actions.append(link(url, '公開URL'))
        categories = cell('、'.join(row['categories'])) or '—'
        tags = cell('、'.join(row['tags'])) or '—'
        lines.append(
            f'<tr><th>{cell(row["title"])}<br><code>{cell(row["source"])}</code></th>'
            f'<td>{KINDS[row["kind"]]}<br>{STATUSES[row["status"]]}</td>'
            f'<td>{row.get("date") or "—"}</td><td>{timestamp(row.get("publish_at"))}</td>'
            f'<td>カテゴリー {categories}<br>タグ {tags}</td>'
            f'<td>{" · ".join(actions)}</td></tr>'
        )
    lines.append('</tbody></table>')
    if total_pages > 1:
        lines.extend(['', '次の範囲を見るには、フォームでページ番号を変更して再実行してください。'])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cli', type=Path)
    parser.add_argument('site', type=Path)
    args = parser.parse_args()
    result = subprocess.run(
        [args.cli.resolve(), 'pages-inventory', args.site, '--json'],
        capture_output=True, check=False,
    )
    if result.returncode:
        raise SystemExit('原稿の検証に失敗しました。対象コミットの site/content を確認してください。')
    rows = json.loads(result.stdout)['report']
    settings = json.loads((args.site / 'site.json').read_text(encoding='utf-8'))
    try:
        report = render(
            rows, json.loads(os.environ['PAGES_INVENTORY_INPUTS']),
            os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_SHA'], settings['base_url'],
        )
    except (ValueError, TypeError, AttributeError) as error:
        raise SystemExit(str(error)) from None
    with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as summary:
        summary.write(report)


if __name__ == '__main__':
    main()
