"""Create one new MoonPress draft in a GitHub Actions checkout."""
import json
import os
from pathlib import Path
import re
import sys


def write_draft(site, slug, title, kind, excerpt):
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
    metadata = {'title': title.strip(), 'kind': kind, 'draft': True}
    if excerpt:
        metadata['description'] = excerpt
    with name.open('x', encoding='utf-8') as output:
        output.write('---\n' + json.dumps(metadata, ensure_ascii=False) + '\n---\n\n本文をここに入力します。\n')
    return name


if __name__ == '__main__':
    try:
        target = write_draft(
            Path(sys.argv[1]), os.environ['DRAFT_SLUG'], os.environ['DRAFT_TITLE'],
            os.environ['DRAFT_KIND'], os.environ.get('DRAFT_EXCERPT', ''),
        )
    except (OSError, ValueError) as error:
        raise SystemExit(str(error)) from error
    print(target.as_posix())
