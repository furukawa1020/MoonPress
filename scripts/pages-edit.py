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

SITE = Path('site')
TEXT_FIELDS = {
    'title': 'title', 'excerpt': 'description', 'date': 'date',
    'slug': 'slug', 'tags': 'tags', 'categories': 'categories',
    'layout': 'layout', 'publish_at': 'publish_at',
}
CLEARABLE = TEXT_FIELDS.keys() - {'title'}


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
    if operation not in {'edit', 'duplicate', 'restore'}:
        raise ValueError('操作を選んでください。')
    if operation != 'edit' and len(names) != 1:
        raise ValueError('複製と復元の対象は1件です。')

    patch = {}
    for field, key in TEXT_FIELDS.items():
        value = fields.get(field, '').strip()
        if value:
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
    if operation == 'duplicate':
        if (not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', stem)
                or len(stem) > 64 or patch.keys() != {'title'} or revision):
            raise ValueError('複製には新しいタイトルと複製先のURL名だけを指定してください。')
    elif operation == 'restore':
        if not re.fullmatch(r'[0-9a-f]{40}', revision) or patch or stem:
            raise ValueError('復元には対象の原稿名と40桁のコミットSHAだけを指定してください。')
    elif stem or revision or (len(names) > 1 and {'title', 'slug'} & patch.keys()):
        raise ValueError('タイトルとURL名の編集は1件ずつ行ってください。')

    return names, operation, patch, stem, revision


def prepare(cli, fields):
    names, operation, patch, stem, revision = read_options(fields)
    if git('status', '--porcelain', stdout=subprocess.PIPE).stdout:
        raise ValueError('編集を始める前に、作業ディレクトリをクリーンにしてください。')

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

    git('add', '--', *map(str, sources.values()))
    changed = git('diff', '--cached', '--name-only', '-z', stdout=subprocess.PIPE).stdout
    if not changed:
        return []
    native('check', SITE, '--include-drafts')
    native('check', SITE)
    return changed.decode().rstrip('\0').split('\0')


def publish(cli, fields, context):
    if context['GITHUB_REF'] != 'refs/heads/main':
        raise ValueError('Run workflow のブランチに main を選んでください。')
    repo = context['GITHUB_REPOSITORY']
    run_id = context['GITHUB_RUN_ID']
    attempt = context['GITHUB_RUN_ATTEMPT']
    if (not re.fullmatch(r'[\w.-]+/[\w.-]+', repo, flags=re.ASCII)
            or not re.fullmatch(r'[0-9]+', run_id)
            or not re.fullmatch(r'[0-9]+', attempt)):
        raise ValueError('GitHub Actions の実行情報を確認できません。')

    changed = prepare(cli, fields)
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
        paths = escape('\n'.join(changed))
        summary.write(
            f'## 作業ブランチに保存しました\n\n<pre>{paths}</pre>\n\n'
            f'[PRを作成する](https://github.com/{repo}/compare/main...{branch}?expand=1)\n\n'
            'PRの公開差分を確認し、マージしてからPagesの公開結果を確認してください。\n'
        )


if __name__ == '__main__':
    try:
        publish(sys.argv[1], json.loads(os.environ['PAGES_EDIT_INPUTS']), os.environ)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
