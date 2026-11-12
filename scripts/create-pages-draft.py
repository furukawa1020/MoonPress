"""Create one new MoonPress draft in a GitHub Actions checkout."""
import json
import os
from pathlib import Path
import re
import sys
from urllib.parse import quote

from pages_schedule import publication_input


def compose_body(raw):
    raw = raw.replace('\r\n', '\n')
    body = re.sub(r'\\([n\\])', lambda m: '\n' if m[1] == 'n' else '\\', raw)
    if len(body.encode()) > 16000 or any(not c.isprintable() and c not in '\n\t' for c in body):
        raise ValueError('Use at most 16000 UTF-8 bytes of Markdown without control characters.')
    return body


def image_markdown(site, filename, alt):
    if (not filename or Path(filename).name != filename or filename.startswith('.')
            or '\\' in filename or any(not c.isprintable() for c in filename)):
        raise ValueError('Choose an existing image filename from Media.')
    image = site / 'public' / filename
    if (image.suffix.lower() not in {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.avif'}
            or image.parent.is_symlink() or image.is_symlink() or not image.is_file()):
        raise ValueError('Choose an existing raster image from Media.')
    if not alt.strip() or len(alt.encode()) > 256 or any(not c.isprintable() or c in '[]\\' for c in alt):
        raise ValueError('Enter image alt text without brackets or backslashes (256 UTF-8 bytes).')
    return f'![{alt}]({quote(filename, safe="")})'


def write_draft(site, slug, title, kind, excerpt, *, body='', image='', alt='',
                date='', tags='', categories='', visibility='draft', publish_at=''):
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', slug) or len(slug) > 64:
        raise ValueError('Use a slug of at most 64 lowercase letters, digits and hyphens.')
    if not title.strip() or len(title) > 160 or any(not c.isprintable() for c in title):
        raise ValueError('Use a printable title of 1–160 characters.')
    if len(excerpt) > 300 or any(not c.isprintable() for c in excerpt):
        raise ValueError('Use a printable excerpt of at most 300 characters.')
    if kind not in {'post', 'page'}:
        raise ValueError('Choose post or page.')
    content = site / 'content'
    if site.is_symlink() or content.is_symlink() or not content.is_dir():
        raise ValueError('Expected a real MoonPress content directory.')
    name = content / f'{slug}.md'
    body = compose_body(body)
    if visibility not in {'draft', 'ready'} or (visibility == 'ready' and not body.strip()):
        raise ValueError('A publication candidate requires a Markdown body.')
    if publish_at.strip() and visibility != 'ready':
        raise ValueError('新規作成で予約するには公開候補を選んでください。')
    if alt and not image:
        raise ValueError('Choose an image when entering alt text.')
    if not body.strip():
        body = '本文をここに入力します。'
    if image:
        body = image_markdown(site, image, alt) + '\n\n' + body

    metadata = {'title': title.strip(), 'kind': kind, 'draft': visibility == 'draft'}
    if publish_at.strip():
        metadata['publish_at'] = publication_input(publish_at)
    if date:
        metadata['date'] = date
    for field, value in [('tags', tags), ('categories', categories)]:
        if value:
            terms = [term.strip() for term in value.split(',')]
            if not all(terms) or any(not c.isprintable() for c in value):
                raise ValueError(f'{field}: use nonempty comma-separated terms.')
            metadata[field] = list(dict.fromkeys(terms))
    if excerpt:
        metadata['description'] = excerpt
    with name.open('x', encoding='utf-8') as output:
        output.write('---\n' + json.dumps(metadata, ensure_ascii=False) + '\n---\n\n' + body + ('' if body.endswith('\n') else '\n'))
    return name


if __name__ == '__main__':
    try:
        target = write_draft(
            Path(sys.argv[1]), os.environ['DRAFT_SLUG'], os.environ['DRAFT_TITLE'],
            os.environ['DRAFT_KIND'], os.environ.get('DRAFT_EXCERPT', ''),
            **{field: os.environ['DRAFT_' + field.upper()]
               for field in ('body', 'image', 'alt', 'date', 'tags', 'categories', 'visibility', 'publish_at')
               if 'DRAFT_' + field.upper() in os.environ},
        )
    except (OSError, ValueError) as error:
        raise SystemExit(str(error)) from error
    print(target.as_posix())
