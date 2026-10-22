"""Shared synthetic corpus. Python standard library; no package installation."""
import argparse
import hashlib
import html.parser
import json
from pathlib import Path


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def corpus(count):
    if count not in (10, 100, 1000):
        raise ValueError('Corpus size must be 10, 100 or 1000')
    return {'schema': 1, 'articles': [
        {'id': n, 'slug': f'p-{n:06d}', 'title': f'Article {n:06d}',
         'paragraphs': [f'Article {n:06d}, paragraph {p}. Identical synthetic publishing content for MoonPress and WordPress. Readable text, escaped ampersands & Unicode 日本語. ' + 'A reproducible paragraph makes the comparison inspectable. ' * 3
                        for p in range(1, 5)]}
        for n in range(1, count + 1)]}


def generate(destination, count):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    data = corpus(count)
    encoded = (json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode()
    (destination / 'dataset.json').write_bytes(encoded)
    site = destination / 'site'
    (site / 'content').mkdir(parents=True)
    (site / 'layout.html').write_text('<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{{title}}</title></head><body><main><h1>{{title}}</h1>{{content}}</main></body></html>\n')
    (site / 'style.css').write_text('body { font-family: sans-serif; }\n')
    for article in data['articles']:
        header = json.dumps({'title': article['title']}, sort_keys=True, separators=(',', ':'))
        (site / 'content' / (article['slug'] + '.md')).write_text('---\n' + header + '\n---\n' + '\n\n'.join(article['paragraphs']) + '\n')
    manifest = {'schema': 1, 'count': count, 'dataset_sha256': sha256(encoded),
                'site_files': {str(p.relative_to(site)): sha256(p.read_bytes()) for p in sorted(site.rglob('*')) if p.is_file()}}
    (destination / 'fixture-manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    return manifest


class ArticleParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.main = False
        self.active = None
        self.parts = []
        self.headings = []
        self.paragraphs = []

    def handle_starttag(self, tag, attrs):
        if tag == 'main':
            self.main = True
        if self.main and tag in ('h1', 'p'):
            self.active = tag
            self.parts = []

    def handle_data(self, data):
        if self.active:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag == self.active:
            value = ''.join(self.parts)
            (self.headings if tag == 'h1' else self.paragraphs).append(value)
            self.active = None
        if tag == 'main':
            self.main = False


def verify_html(body, article):
    parser = ArticleParser()
    parser.feed(body.decode('utf-8'))
    if parser.headings != [article['title']] or parser.paragraphs != article['paragraphs']:
        raise ValueError(f"Response content differs from canonical article {article['id']}")


if __name__ == '__main__':
    args = argparse.ArgumentParser()
    args.add_argument('destination')
    args.add_argument('count', type=int, choices=[10, 100, 1000])
    options = args.parse_args()
    print(json.dumps(generate(options.destination, options.count), sort_keys=True))
