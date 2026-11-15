"""Prepare a reviewed change to the configured public navigation."""

import json
from pathlib import Path
import re
import subprocess
import tempfile


def updated_menu(menu, fields):
    action = fields['operation']
    target = fields.get('url', '').strip()
    label = fields.get('label', '').strip()
    link = fields.get('new_url', '').strip()
    position = fields.get('position', '').strip()
    if not target or action not in ('add', 'edit', 'remove', 'move'):
        raise ValueError('操作とリンク先を指定してください。')
    if position and not re.fullmatch(r'[1-9][0-9]?', position):
        raise ValueError('位置は1から始まる番号を指定してください。')

    matches = [i for i, item in enumerate(menu) if item.get('url') == target]
    if action == 'add':
        if matches or not label or link:
            raise ValueError('追加には未登録のリンク先と表示名を指定してください。')
        menu.insert(index_for(position, len(menu) + 1), {'label': label, 'url': target})
        return menu

    if len(matches) != 1:
        raise ValueError('現在のメニューからリンク先を正確にコピーしてください。')
    index = matches[0]
    item = menu[index]
    if action == 'edit':
        if position or not (label or link):
            raise ValueError('変更後の表示名かリンク先を指定してください。')
        menu[index] = {'label': label or item['label'], 'url': link or item['url']}
    elif action == 'move':
        if not position or label or link:
            raise ValueError('移動には現在のリンク先と移動先の位置を指定してください。')
        destination = index_for(position, len(menu))
        menu.insert(destination, menu.pop(index))
    else:
        if position or label or link:
            raise ValueError('削除には現在のリンク先だけを指定してください。')
        menu.pop(index)
    return menu


def index_for(position, limit):
    value = int(position) if position else limit
    if value > limit:
        raise ValueError(f'位置は1〜{limit}の範囲で指定してください。')
    return value - 1


def prepare(cli, site, fields, git):
    path = site / 'site.json'
    git('ls-files', '--error-unmatch', '--', str(path), stdout=subprocess.DEVNULL)
    snapshot = json.loads(subprocess.check_output(
        [cli, 'settings-read', site, '--json'],
    ))['report']
    settings = json.loads(snapshot['content'])
    original = settings.get('menu', [])
    menu = updated_menu(list(original), fields)
    if menu == original:
        return []

    settings['menu'] = menu
    with tempfile.TemporaryDirectory() as temp:
        replacement = Path(temp) / 'site.json'
        replacement.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        subprocess.check_output([
            cli, 'settings-save', site, snapshot['digest'], replacement, '--json',
        ])
    return [path]
