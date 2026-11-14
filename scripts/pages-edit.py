"""Prepare a reviewed Pages edit in the Actions checkout."""
from html import escape
from pathlib import Path
import json
import os
import re
import subprocess
import sys
import tempfile
from unicodedata import category

from pages_schedule import publication_input
from pages_taxonomy import prepare as prepare_taxonomy

SITE = Path('site')
TEXT_FIELDS = {
    'title': 'title', 'excerpt': 'description', 'date': 'date',
    'slug': 'slug', 'tags': 'tags', 'categories': 'categories',
    'layout': 'layout', 'publish_at': 'publish_at',
}
CLEARABLE = TEXT_FIELDS.keys() - {'title'}
TRASH_OPERATIONS = {'trash', 'untrash'}


def filename(name):
    if (not name.endswith('.md') or len(name) <= 3 or name.startswith('.')
            or len(name.encode()) > 200 or any(
                char in '/\\,' or category(char) in {'Cc', 'Cf'} for char in name
            )):
        raise ValueError('原稿名には content 内の .md ファイル名を指定してください。')
    return name


def git(*args, **kwargs):
    return subprocess.run(
        ['git', '--literal-pathspecs', *args], check=True, **kwargs,
    )


def read_options(fields):
    names = [filename(name.strip()) for name in fields['files'].split(',')]
    if len(names) > 20 or len(names) != len(set(names)):
        raise ValueError('原稿は重複なしで最大20件まで指定できます。')

    operation = fields['operation']
    if operation not in {'edit', 'duplicate', 'restore'} | TRASH_OPERATIONS:
        raise ValueError('操作を選んでください。')
    if operation in {'duplicate', 'restore'} and len(names) != 1:
        raise ValueError('複製と復元の対象は1件です。')

    patch = {}
    for field, key in TEXT_FIELDS.items():
        value = fields.get(field, '').strip()
        if value:
            if field == 'publish_at':
                value = publication_input(value)
            if field in {'tags', 'categories'}:
                items = [item.strip() for item in value.split(',')]
                if not all(items):
                    raise ValueError(f'{field} は空の要素を含めず、カンマで区切ってください。')
                value = '\n'.join(items)
            patch[key] = value

    clear = fields.get('clear', '').strip()
    if clear:
        for field in clear.split(','):
            field = field.strip()
            if field not in CLEARABLE or TEXT_FIELDS[field] in patch:
                raise ValueError('値と消去は同時に指定できません。消去欄の項目名も確認してください。')
            patch[TEXT_FIELDS[field]] = ''

    for field, key, choices in [
        ('kind', 'kind', {'post': 'post', 'page': 'page'}),
        ('listing', 'listed', {'list': True, 'unlist': False}),
        ('visibility', 'draft', {'draft': True, 'ready': False}),
    ]:
        value = fields.get(field, 'keep')
        if value != 'keep':
            if value not in choices:
                raise ValueError(f'{field} の値を選び直してください。')
            patch[key] = choices[value]

    stem = fields.get('copy_to', '').strip()
    revision = fields.get('revision', '').strip()
    if operation in TRASH_OPERATIONS:
        if fields.get('confirm_trash') is not True:
            raise ValueError('ゴミ箱操作の確認欄を選んでください。')
        if patch or stem or revision:
            raise ValueError('ゴミ箱操作では原稿名と確認欄だけを指定してください。')
    elif operation == 'duplicate':
        if (not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', stem)
                or len(stem) > 64 or patch.keys() != {'title'} or revision):
            raise ValueError('複製には新しいタイトルと複製先のURL名だけを指定してください。')
    elif operation == 'restore':
        if not re.fullmatch(r'[0-9a-f]{40}', revision) or patch or stem:
            raise ValueError('復元には対象の原稿名と40桁のコミットSHAだけを指定してください。')
    elif stem or revision or (len(names) > 1 and {'title', 'slug'} & patch.keys()):
        raise ValueError('タイトルとURL名の編集は1件ずつ行ってください。')

    return names, operation, patch, stem, revision


def relocate(cli, names, operation):
    content, trash = SITE / 'content', SITE / 'trash'
    if SITE.is_symlink() or content.is_symlink() or not content.is_dir():
        raise ValueError('正規の原稿フォルダを使用してください。')
    if trash.is_symlink() or (trash.exists() and not trash.is_dir()):
        raise ValueError('ゴミ箱フォルダを確認してください。')

    from_dir, to_dir = (content, trash) if operation == 'trash' else (trash, content)
    moves = [(from_dir / name, to_dir / name) for name in names]
    for source, target in moves:
        if source.is_symlink() or not source.is_file():
            raise ValueError(f'原稿が見つからないか、安全に操作できません: {source}')
        if target.exists() or target.is_symlink():
            raise ValueError(f'同名の原稿があります: {target}')
        git('ls-files', '--error-unmatch', '--', str(source), stdout=subprocess.DEVNULL)
        if operation == 'trash':
            subprocess.check_output([cli, 'read', SITE, source.name, '--json'])

    to_dir.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        patch = Path(temp) / 'draft.json'
        patch.write_text('{"draft":true}', encoding='utf-8')
        for source, target in moves:
            source.rename(target)
            if operation == 'untrash':
                result = json.loads(subprocess.check_output([cli, 'read', SITE, target.name, '--json']))
                digest = result['report']['digest']
                subprocess.check_output([cli, 'pages-patch', SITE, target.name, digest, patch, '--json'])
    return [path for move in moves for path in move]


def prepare_edit(cli, names, operation, patch, stem, revision):
    def native(*args):
        return subprocess.check_output([cli, *args])

    sources = {name: SITE / 'content' / name for name in names}
    versions = {}
    for name, path in sources.items():
        git('ls-files', '--error-unmatch', '--', str(path), stdout=subprocess.DEVNULL)
        report = json.loads(native('read', SITE, name, '--json'))['report']
        versions[name] = report['digest']

    with tempfile.TemporaryDirectory() as temp:
        payload = Path(temp) / 'source'
        if operation == 'restore':
            git('merge-base', '--is-ancestor', revision, 'HEAD')
            name, path = next(iter(sources.items()))
            entry = git('ls-tree', '-z', revision, '--', str(path), stdout=subprocess.PIPE).stdout
            if not entry.startswith((b'100644 blob ', b'100755 blob ')):
                raise ValueError('指定した履歴に復元できる原稿がありません。')
            with payload.open('wb') as output:
                git('show', f'{revision}:{path.as_posix()}', stdout=output)
            native('save', SITE, name, versions[name], payload, '--json')
        elif operation == 'duplicate':
            name = names[0]
            native('duplicate', SITE, name, versions[name], stem, patch['title'], '--json')
            sources = {stem: SITE / 'content' / f'{stem}.md'}
        elif patch:
            payload.write_text(json.dumps(patch, ensure_ascii=False), encoding='utf-8')
            for name in names:
                native('pages-patch', SITE, name, versions[name], payload, '--json')
        else:
            return []

    return list(sources.values())


def prepare(cli, fields, taxonomy=False):
    if git('status', '--porcelain', stdout=subprocess.PIPE).stdout:
        raise ValueError('編集を始める前に、作業ディレクトリをクリーンにしてください。')
    if taxonomy:
        paths = prepare_taxonomy(cli, SITE, fields, git, filename)
    else:
        names, operation, patch, stem, revision = read_options(fields)
        if operation in TRASH_OPERATIONS:
            paths = relocate(cli, names, operation)
        else:
            paths = prepare_edit(cli, names, operation, patch, stem, revision)
    if not paths:
        return []
    git('add', '-A', '--', *map(str, paths))
    changed = git('diff', '--cached', '--name-only', '--no-renames', '-z', stdout=subprocess.PIPE).stdout
    if not changed:
        return []
    subprocess.check_output([cli, 'check', SITE, '--include-drafts'])
    subprocess.check_output([cli, 'check', SITE])
    return changed.decode().rstrip('\0').split('\0')


def publish(cli, fields, context, taxonomy=False):
    if context['GITHUB_REF'] != 'refs/heads/main':
        raise ValueError('Run workflow のブランチに main を選んでください。')
    repo = context['GITHUB_REPOSITORY']
    run_id = context['GITHUB_RUN_ID']
    attempt = context['GITHUB_RUN_ATTEMPT']
    if (not re.fullmatch(r'[\w.-]+/[\w.-]+', repo, flags=re.ASCII)
            or not re.fullmatch(r'[0-9]+', run_id)
            or not re.fullmatch(r'[0-9]+', attempt)):
        raise ValueError('GitHub Actions の実行情報を確認できません。')

    changed = prepare(cli, fields, taxonomy)
    with Path(context['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as summary:
        if not changed:
            summary.write('## 変更なし\n\n作業ブランチは作成されませんでした。\n')
            return

        branch = f'moonpress-edit-{run_id}-{attempt}'
        ref = f'refs/heads/{branch}'
        git(
            '-c', 'user.name=github-actions[bot]',
            '-c', 'user.email=41898282+github-actions[bot]@users.noreply.github.com',
            'commit', '-m', 'Prepare Pages content changes',
        )
        git(
            '-c', 'credential.helper=!gh auth git-credential', 'push',
            f'--force-with-lease={ref}:', 'origin', f'HEAD:{ref}',
        )
        if taxonomy:
            details = f'変更した原稿 {len(changed)} 件。'
        else:
            paths = escape('\n'.join(changed))
            details = f'<pre>{paths}</pre>'
        title = {
            'trash': 'ゴミ箱への移動を作業ブランチに保存しました',
            'untrash': '下書きへの復元を作業ブランチに保存しました',
        }.get(fields['operation'], '作業ブランチに保存しました')
        summary.write(
            f'## {title}\n\n{details}\n\n'
            f'[PRを作成する](https://github.com/{repo}/compare/main...{branch}?expand=1)\n\n'
            'PRの公開差分を確認し、マージしてからPagesの公開結果を確認してください。\n'
        )


if __name__ == '__main__':
    try:
        publish(sys.argv[1], json.loads(os.environ['PAGES_EDIT_INPUTS']), os.environ,
                taxonomy=sys.argv[2:] == ['--taxonomy'])
    except subprocess.CalledProcessError as error:
        if sys.argv[2:] == ['--taxonomy']:
            sys.exit('分類の検証に失敗しました。原稿・分類名・公開リンクを確認してください。')
        sys.exit(str(error))
    except (OSError, ValueError, KeyError) as error:
        sys.exit(str(error))
