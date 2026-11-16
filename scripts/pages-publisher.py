"""Import signed, explicitly submitted articles into the Pages source checkout."""

import argparse
import base64
from datetime import datetime
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import unicodedata
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
STATE = 'public/publication-status.json'
VERIFICATION_KEY = ROOT / 'deploy/pages/publisher-public.pem'
QUEUE = 'https://moonpress-publication-queue.f-kotaro-0530.chatgpt.site/queue'
LIVE = 'https://furukawa1020.github.io/MoonPress/publication-status.json'


def read_json(response):
    raw = response.read(200_001)
    if len(raw) > 200_000:
        raise ValueError('Publication response too large')
    return json.loads(raw)


def receipt(site):
    path = site / STATE
    if path.is_symlink():
        raise ValueError('Publication receipt must not be a symlink')
    if path.exists():
        return json.loads(path.read_bytes())
    return {'cursor': 0, 'entries': {}}


def get_remote(url):
    request = Request(url, headers={
        'User-Agent': 'MoonPress-Pages/1', 'Accept': 'application/json',
    })
    for attempt in range(3):
        try:
            with urlopen(request, timeout=8) as response:
                if response.geturl() != url:
                    raise ValueError('Publication endpoint redirected')
                return read_json(response)
        except OSError as error:
            if attempt == 2 or (isinstance(error, HTTPError) and error.code == 404):
                raise
            time.sleep(attempt + 1)


def read_item(item, cursor, key):
    seq = item['seq']
    if type(seq) is not int or not cursor < seq <= 999_999_999_999:
        raise ValueError('Publication queue cursor is out of order')
    payload = item['payload'].encode('utf-8')
    signature = base64.b64decode(item['signature'], validate=True)
    if len(payload) > 24_000 or len(signature) != 256:
        raise ValueError('Invalid publication envelope size')
    with tempfile.TemporaryDirectory() as temp:
        sig = Path(temp) / 'signature'
        sig.write_bytes(signature)
        subprocess.run(
            ['openssl', 'dgst', '-sha256', '-verify', key, '-signature', sig],
            input=payload, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True,
        )
    value = json.loads(payload)
    slug = value['slug']
    if (not isinstance(slug, str) or not 1 <= len(slug) <= 64
            or len(slug.encode()) > 190 or not slug[0].isalnum() or slug.endswith('-')
            or not all(c.isalnum() or c == '-' or unicodedata.category(c).startswith('M') for c in slug)
            or re.match(r'^(index|articles(?:-|$)|manage|write|tags|categories|category-|tag-)', slug, re.I)):
        raise ValueError('Invalid publication URL')
    title, body, kind = value['title'], value['markdown'], value['kind']
    if (not isinstance(title, str) or not 1 <= len(title) <= 120
            or not isinstance(body, str) or not 1 <= len(body.encode()) <= 16000
            or kind not in ('post', 'page')):
        raise ValueError('Invalid publication document')
    return seq, slug, title, body, kind


def import_items(cli, site, items, key):
    state = receipt(site)
    cursor = state['cursor']
    if not isinstance(items, list) or len(items) > 6:
        raise ValueError('Invalid publication queue length')
    # Verify all signatures before creating any source file.
    documents = []
    for item in items:
        parsed = read_item(item, cursor, key)
        documents.append(parsed)
        cursor = parsed[0]
    if not documents:
        return

    date = datetime.now(ZoneInfo('Asia/Tokyo')).date().isoformat()
    for seq, slug, title, body, kind in documents:
        if slug in state['entries']:
            raise ValueError('Duplicate publication URL in a signed record')
        file = site / 'content' / f'published-{seq}.md'
        fields = {'title': title, 'kind': kind, 'slug': slug, 'date': date}
        text = '---\n' + json.dumps(fields, ensure_ascii=False) + '\n---\n' + body + '\n'
        try:
            with file.open('x', encoding='utf-8') as output:
                output.write(text)
        except FileExistsError:
            accepted = False
        else:
            builds = ([], ['--include-drafts'])
            accepted = all(subprocess.run([cli, 'check', site, *flags], capture_output=True).returncode == 0
                           for flags in builds)
            if not accepted:
                file.unlink()
        state['entries'][slug] = 'published' if accepted else 'rejected'
        state['cursor'] = seq
    (site / STATE).write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'import'])
    parser.add_argument('site', type=Path)
    parser.add_argument('incoming', type=Path)
    parser.add_argument('--cli', type=Path)
    args = parser.parse_args()
    if args.action == 'import':
        import_items(args.cli, args.site, json.loads(args.incoming.read_bytes()), VERIFICATION_KEY)
        return
    cursor = receipt(args.site)['cursor']
    try:
        incoming = get_remote(QUEUE + '?after=' + str(cursor))['items']
    except (OSError, ValueError, KeyError) as exc:
        # Reservations and normal Pages deployments still run if the queue is down.
        print('::warning::Publication queue unavailable: ' + type(exc).__name__, file=sys.stderr)
        incoming = []
    args.incoming.write_text(json.dumps(incoming), encoding='utf-8')
    pending_deploy = False
    if cursor:
        try:
            pending_deploy = get_remote(LIVE + '?cursor=' + str(cursor))['cursor'] < cursor
        except (OSError, ValueError, KeyError) as exc:
            pending_deploy = not isinstance(exc, HTTPError) or exc.code == 404
    print('true' if incoming or pending_deploy else 'false')


if __name__ == '__main__':
    main()
