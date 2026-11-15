"""Prepare internal redirect changes for a Pages review branch."""

import json
from pathlib import Path
import subprocess
import tempfile
from unicodedata import category


def route(value):
    if (
        not value.endswith('.html') or len(value) <= 5 or value.startswith('.')
        or len(value.encode()) > 255 or any(
            char in '/\\:?#%' or category(char) in ('Cc', 'Cf') for char in value
        )
    ):
        raise ValueError('URLにはサイト内の .html ファイル名を指定してください。')
    return value


def update_settings(cli, site, git, edit):
    path = site / 'site.json'
    git('ls-files', '--error-unmatch', '--', str(path), stdout=subprocess.DEVNULL)
    snapshot = json.loads(subprocess.check_output(
        [cli, 'settings-read', site, '--json'],
    ))['report']
    settings = json.loads(snapshot['content'])
    original = settings.get('redirects', {})
    redirects = dict(original)
    edit(redirects)
    if redirects == original:
        return []

    if redirects:
        settings['redirects'] = dict(sorted(redirects.items()))
    else:
        settings.pop('redirects', None)
    with tempfile.TemporaryDirectory() as temp:
        replacement = Path(temp) / 'site.json'
        replacement.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        subprocess.check_output([
            cli, 'settings-save', site, snapshot['digest'], replacement, '--json',
        ])
    return [path]


def prepare(cli, site, fields, git):
    action = fields['operation']
    source = route(fields['source'].strip())
    target = fields.get('target', '').strip()
    if action == 'remove':
        if target:
            raise ValueError('削除では元のURLだけを指定してください。')
    elif action in ('add', 'update'):
        target = route(target)
        if source == target:
            raise ValueError('元のURLと転送先に異なる名前を指定してください。')
    else:
        raise ValueError('追加・転送先変更・削除を選んでください。')

    def edit(redirects):
        if action == 'add':
            if source in redirects:
                raise ValueError('登録済みのURLです。転送先の変更を選んでください。')
        elif source not in redirects:
            raise ValueError('元のURLが登録されていません。')
        if action == 'remove':
            del redirects[source]
        else:
            redirects[source] = target

    return update_settings(cli, site, git, edit)


def prepare_move(cli, site, name, patch, git):
    """Plan the alias against the original checkout before editing the article."""
    destination = route((patch['slug'] or name[:-3]) + '.html')
    rows = json.loads(subprocess.check_output([
        cli, 'pages-inventory', site, '--json',
    ]))['report']
    current = next((row for row in rows if row['source'] == 'content/' + name), None)
    if current is None or current['status'] not in ('published', 'unlisted'):
        raise ValueError('旧URLを保持できるのは公開対象の投稿・固定ページです。')
    source = route(current['output'])
    if source == destination:
        return []

    def edit(redirects):
        if source in redirects:
            raise ValueError('元のURLはすでに転送に使用されています。')
        if destination in redirects:
            # Reclaim a previous alias only when it already leads to this article.
            terminal = destination
            seen = set()
            while terminal in redirects and terminal not in seen:
                seen.add(terminal)
                terminal = redirects[terminal]
            if terminal != source:
                raise ValueError('変更先のURLは別の転送に使用されています。')
            del redirects[destination]
        redirects[source] = destination

    return update_settings(cli, site, git, edit)
