"""Plan and apply reviewed taxonomy changes to a clean Pages checkout."""

import json
from pathlib import Path
import subprocess
import tempfile
from unicodedata import category


def terms(value):
    items = [item.strip() for item in value.split(',')]
    if (
        not 1 <= len(items) <= 20 or len(items) != len(set(items))
        or any(
            not item or len(item.encode('utf-8')) > 96
            or any(category(char) in ('Cc', 'Cf') for char in item)
            for item in items
        )
    ):
        raise ValueError('分類名は空欄や重複を避け、各96バイト以下・最大20件で指定してください。')
    return items


def read_options(fields, filename):
    key = fields['taxonomy']
    action = fields['operation']
    names = fields.get('files', '').strip()
    requested = terms(fields['terms'])
    destination = fields.get('destination', '').strip()
    confirmed = fields.get('confirm_site') is True
    if key not in ('categories', 'tags') or action not in ('add', 'remove', 'rename', 'merge'):
        raise ValueError('分類と操作を選択してください。')
    targets = [filename(name.strip()) for name in names.split(',')] if names else []
    if len(targets) > 20 or len(targets) != len(set(targets)):
        raise ValueError('原稿名は重複なしで最大20件です。')
    if (action == 'add' and not targets) or (not targets and not confirmed):
        raise ValueError('原稿名を指定するか、全原稿への変更を確認してください。')
    if action in ('rename', 'merge'):
        required = len(requested) == 1 if action == 'rename' else len(requested) >= 2
        if targets or not required or len(terms(destination)) != 1 or destination in requested:
            raise ValueError('改名・統合では全原稿を対象にし、既存名と異なる変更先を一つ指定してください。')
    elif destination:
        raise ValueError('変更先を指定できるのは改名・統合です。')
    return key, action, targets, requested, destination


def updated_terms(current, action, requested, destination):
    if action == 'add':
        return sorted(set(current) | set(requested))
    kept = set(current) - set(requested)
    if action in ('rename', 'merge') and len(kept) != len(current):
        kept.add(destination)
    return sorted(kept)


def prepare(cli, site, fields, git, filename):
    key, action, targets, requested, destination = read_options(fields, filename)

    def native(*args):
        return json.loads(subprocess.check_output([cli, *args, '--json'], stderr=subprocess.PIPE))['report']

    rows = {row['source'].removeprefix('content/'): row for row in native('pages-inventory', site)}
    names = targets or list(rows)
    # Reject missing sources before modifying any file in the checkout.
    if any(name not in rows for name in names):
        raise ValueError('対象の原稿が見つかりません。原稿名を確認してください。')
    changes = []
    for name in names:
        current = rows[name][key]
        updated = updated_terms(current, action, requested, destination)
        if sorted(current) == updated:
            continue
        path = site / 'content' / name
        git('ls-files', '--error-unmatch', '--', str(path), stdout=subprocess.DEVNULL)
        digest = native('read', site, name)['digest']
        if key == 'categories' and len(updated) > 64:
            raise ValueError('1原稿のカテゴリーは64件までです。対象を減らすか既存の分類を整理してください。')
        changes.append((name, path, digest, updated))

    with tempfile.TemporaryDirectory() as temp:
        patch = Path(temp) / 'taxonomy.json'
        for name, _, digest, updated in changes:
            patch.write_text(json.dumps({key: updated}, ensure_ascii=False), encoding='utf-8')
            native('pages-patch', site, name, digest, patch)
    return [path for _, path, _, _ in changes]
