"""Render a bounded Pages review excerpt without importing page markup or remote media."""
from html import escape
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit
import json
import sys

TAGS = {
    'a', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'strong', 'em', 'del',
    'blockquote', 'pre', 'code', 'ul', 'ol', 'li', 'table', 'thead', 'tbody',
    'tr', 'th', 'td', 'br', 'hr',
}
VOID = {'br', 'hr'}
RASTER = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.avif'}
LIMIT = 6


class ReviewMarkup(HTMLParser):
    def __init__(self, base, live, images):
        super().__init__(convert_charrefs=True)
        self.base, self.live, self.images = base, live, images
        self.title, self.html, self.stack = [], [], []
        self.main = self.in_title = False
        self.hidden = None

    def local_url(self, url, allowed):
        try:
            parts = urlsplit(url)
        except ValueError:
            return None
        name = unquote(parts.path)
        if parts.scheme or parts.netloc or name not in allowed:
            return None
        return self.base + quote(name, safe='') if self.base else None

    def handle_starttag(self, tag, pairs):
        if self.hidden:
            return
        if tag in {'script', 'style', 'template', 'iframe'}:
            self.hidden = tag
            return
        if tag == 'title':
            self.in_title = True
        if tag == 'main':
            self.main = True
        if not self.main:
            return
        attrs = dict(pairs)
        if tag == 'img':
            alt = escape(attrs.get('alt') or '画像')
            url = self.local_url(attrs.get('src') or '', self.images)
            self.html.append(
                f'<img src="{escape(url)}" alt="{alt}" width="480">' if url else f'<em>画像: {alt}</em>'
            )
        if tag not in TAGS:
            return
        if tag == 'a':
            url = self.local_url(attrs.get('href') or '', self.live)
            self.html.append(f'<a href="{escape(url)}">' if url else '<span>')
            self.stack.append((tag, 'a' if url else 'span'))
        else:
            self.html.append(f'<{tag}>')
            if tag not in VOID:
                self.stack.append((tag, tag))

    def handle_endtag(self, tag):
        if self.hidden:
            if tag == self.hidden:
                self.hidden = None
            return
        if tag == 'title':
            self.in_title = False
        if tag == 'main':
            self.main = False
        if self.main and self.stack and self.stack[-1][0] == tag:
            self.html.append(f'</{self.stack.pop()[1]}>')

    def handle_data(self, data):
        if self.hidden:
            return
        if self.in_title:
            self.title.append(data)
        if self.main:
            self.html.append(escape(data).replace('\n', '&#10;').replace('\r', '&#13;'))

    def content(self):
        return ''.join(self.html) + ''.join(f'</{tag}>' for _, tag in reversed(self.stack))


def safe_base(config):
    url = config.get('base_url', '')
    try:
        parts = urlsplit(url)
        if (parts.scheme == 'https' and parts.hostname and not parts.username
                and not parts.password and not parts.query and not parts.fragment):
            return url.rstrip('/') + '/'
    except (ValueError, AttributeError):
        pass
    return ''


def render_reviews(before, after, drafts, routes, paths, base):
    live = {p.name for p in before.iterdir() if p.suffix == '.html'}
    images = {
        p.name for p in before.iterdir()
        if p.suffix.lower() in RASTER and (drafts / p.name).is_file()
        and p.read_bytes() == (drafts / p.name).read_bytes()
    }
    changes = sorted(
        (row['source'], row['name'])
        for row in routes if row['kind'] == 'page' and 'site/' + row['source'] in paths
    )
    if not changes:
        return ''
    lines = [
        '', '## 記事プレビュー', '',
        '変更した原稿をMoonPressでレンダリングした確認用の本文です。GitHubの表示形式を使用します。',
        '既存の公開画像だけを表示し、新規画像や外部画像は代替テキストで示します。',
    ]
    for _, name in changes[:LIMIT]:
        # Filenames originate from the compiler, but keep all reads within the verified build.
        if Path(name).name != name or name.startswith('.') or not name.endswith('.html'):
            continue
        public = (after / name).is_file()
        page = (after if public else drafts) / name
        status = '公開候補' if public else '下書き・予約など（公開対象外）'
        parser = None
        label = name
        if page.stat().st_size <= 128000:
            parser = ReviewMarkup(base, live, images)
            parser.feed(page.read_text(encoding='utf-8'))
            parser.close()
            title = ' '.join(''.join(parser.title).split())
            if title:
                label = f'{title[:180]} · {name}'
        lines.extend(['', f'<details><summary>{escape(label)} · {status}</summary>', ''])
        if base and public:
            url = escape(base + quote(name, safe=''))
            destination = '現在の公開版' if name in live else '公開後のURL'
            lines.append(f'<p><a href="{url}">{destination}</a></p>')
        if parser is not None:
            body = parser.content()
            if len(body.encode()) <= 48000:
                lines.append('<div>' + body + '</div>' if body else '<p>本文を抽出できませんでした。</p>')
            else:
                lines.append('<p>本文が長いため、原稿と公開差分で確認してください。</p>')
        else:
            lines.append('<p>ページが長いため、原稿と公開差分で確認してください。</p>')
        lines.extend(['', '</details>'])
    if len(changes) > LIMIT:
        lines.extend(['', f'ほか {len(changes) - LIMIT}件はPRのファイル差分で確認できます。'])
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    before, after, drafts, routes, paths, config = map(Path, sys.argv[1:])
    print(render_reviews(
        before, after, drafts, json.loads(routes.read_bytes())['report']['routes'],
        set(paths.read_bytes().decode().split('\0')), safe_base(json.loads(config.read_bytes())),
    ), end='')
