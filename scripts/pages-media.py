"""Prepare one reviewed raster replacement from a GitHub upload branch."""
from html import escape
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from unicodedata import category

LIMIT = 8 * 1024 * 1024
FORMATS = {'.png': 'png', '.jpg': 'jpeg', '.jpeg': 'jpeg', '.gif': 'gif', '.webp': 'webp'}


def git(*args, **kwargs):
    return subprocess.run(['git', '--literal-pathspecs', *args], check=True, **kwargs)


def image_name(name):
    if (not name or name.startswith('.') or len(name.encode()) > 255
            or any(c in '/\\' or category(c) in {'Cc', 'Cf'} for c in name)
            or Path(name).suffix.lower() not in FORMATS):
        raise ValueError('PNG、JPEG、GIF、WebP のファイル名を指定してください。')
    return name


def prepare(cli, fields):
    target = image_name(fields['target'])
    source = image_name(fields['source'])
    expected = fields['version'].strip()
    branch = fields['upload_branch'].strip()
    if FORMATS[Path(source).suffix.lower()] != FORMATS[Path(target).suffix.lower()]:
        raise ValueError('公開画像と候補の形式を揃えてください。')
    if not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise ValueError('管理画面に表示された SHA-256 を入力してください。')
    if (branch in {'main', 'gh-pages'} or
            not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]{0,140}', branch)):
        raise ValueError('候補をアップロードした作業ブランチ名を入力してください。')
    ref = 'refs/heads/' + branch
    git('check-ref-format', ref)
    if git('status', '--porcelain', stdout=subprocess.PIPE).stdout:
        raise ValueError('作業ディレクトリはクリーンである必要があります。')

    path = f'site/public/{target}'
    git('ls-files', '--error-unmatch', '--', path, stdout=subprocess.DEVNULL)
    current = json.loads(subprocess.check_output([cli, 'media-read', 'site', target, '--json']))['report']
    if current['digest'] != expected:
        raise ValueError('画像が更新されています。管理画面から最新の SHA-256 を確認してください。')

    git('fetch', '--depth=1', 'origin', ref)
    revision = git('rev-parse', 'FETCH_HEAD', stdout=subprocess.PIPE, text=True).stdout.strip()
    entry = git('ls-tree', '-z', revision, '--', f'site/media-inbox/{source}', stdout=subprocess.PIPE).stdout
    header, _, _ = entry.partition(b'\t')
    if not re.fullmatch(rb'100(?:644|755) blob [0-9a-f]{40}', header):
        raise ValueError('作業ブランチの差し替え候補に通常の画像ファイルが必要です。')
    blob = header.split()[-1].decode()
    size = int(git('cat-file', '-s', blob, stdout=subprocess.PIPE).stdout)
    if not 0 < size <= LIMIT:
        raise ValueError('差し替え画像は 8 MiB 以下にしてください。')
    with tempfile.TemporaryDirectory() as directory:
        replacement = Path(directory) / 'candidate'
        with replacement.open('wb') as handle:
            git('cat-file', 'blob', blob, stdout=handle)
        report = json.loads(subprocess.check_output([
            cli, 'pages-media-replace', 'site', target, expected, replacement, '--json',
        ]))['report']

    if report['changed']:
        subprocess.check_output([cli, 'check', 'site', '--include-drafts'])
        subprocess.check_output([cli, 'check', 'site'])
        git('add', '--', path)
    return path, revision, report


def publish(cli, fields, context):
    if context['GITHUB_REF'] != 'refs/heads/main':
        raise ValueError('Run workflow のブランチに main を選んでください。')
    repo = context['GITHUB_REPOSITORY']
    run_id, attempt = context['GITHUB_RUN_ID'], context['GITHUB_RUN_ATTEMPT']
    if not (re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo)
            and re.fullmatch(r'[0-9]+', run_id) and re.fullmatch(r'[0-9]+', attempt)):
        raise ValueError('GitHub Actions の実行情報を確認できません。')
    path, revision, report = prepare(cli, fields)
    with Path(context['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as summary:
        if not report['changed']:
            summary.write('## 変更なし\n\n同じ画像のため、作業ブランチは作成されませんでした。\n')
            return
        branch = f'moonpress-media-{run_id}-{attempt}'
        ref = f'refs/heads/{branch}'
        git('-c', 'user.name=github-actions[bot]',
            '-c', 'user.email=41898282+github-actions[bot]@users.noreply.github.com',
            'commit', '-m', 'Replace one published image')
        git('-c', 'credential.helper=!gh auth git-credential', 'push',
            f'--force-with-lease={ref}:', 'origin', f'HEAD:{ref}')
        summary.write(
            f'## 差し替えを作業ブランチに保存しました\n\n<pre>{escape(path)}</pre>\n\n'
            f'- 候補コミット: `{revision}`\n'
            f'- 変更前 SHA-256: `{report["previous_digest"]}`\n'
            f'- 変更後 SHA-256: `{report["item"]["digest"]}`\n\n'
            f'[差し替えのPRを作る](https://github.com/{repo}/compare/main...{branch}?expand=1)\n\n'
            'PRで画像と公開差分を確認し、マージ後に同じURLから確認してください。\n'
        )


if __name__ == '__main__':
    try:
        publish(sys.argv[1], json.loads(os.environ['PAGES_MEDIA_INPUTS']), os.environ)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
