"""Test Pages schedule inputs, cron eligibility, and native production output."""
from datetime import datetime, timezone
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

from pages_schedule import due_candidates, publication_input

compose = runpy.run_path('scripts/create-pages-draft.py')['write_draft']
cli = Path('_build/native/release/build/cmd/main/main.exe').resolve()

assert publication_input('2027-01-01 08:59') == '2026-12-31T23:59:00Z'
assert publication_input('2028-02-29T09:00') == '2028-02-29T00:00:00Z'
assert publication_input('2028-02-29T00:00:00Z') == '2028-02-29T00:00:00Z'
for bad in ['2027-02-29 09:00', '2027-01-01 24:00', '0001-01-01 00:00',
            '2027-01-01T09:00:00+09:00', '2027-01-01T00:00:60Z', '2027-01-01']:
    try:
        publication_input(bad)
    except ValueError:
        pass
    else:
        raise AssertionError(bad)

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    site = root / 'site'
    shutil.copytree('site', site)
    try:
        compose(site, 'draft-schedule', 'Draft', 'post', '', publish_at='2027-01-01 09:00')
    except ValueError:
        assert not (site / 'content/draft-schedule.md').exists()
    else:
        raise AssertionError('New scheduled source must be ready')

    for slug, kind, date in [('early', 'post', '2000-01-01 09:00'),
                             ('later', 'page', '9999-01-01 09:00')]:
        result = compose(site, slug, slug, kind, '', body='# Schedule',
                         visibility='ready', publish_at=date)
        assert json.loads(result.read_text().splitlines()[1])['publish_at'] == publication_input(date)

    draft = site / 'content/held.md'
    draft.write_text('---\r\n{"draft":true,"publish_at":"2000-01-01T00:00:00Z"}\r\n---\r\n# Held\r\n')
    escaped = site / 'content/escaped.md'
    escaped.write_text('---\r\n{"\\u0070ublish_at":"2000-01-01T00:00:00Z"}\r\n---')
    before = datetime(1999, 12, 31, 23, 59, 59, tzinfo=timezone.utc)
    exactly = datetime(2000, 1, 1, tzinfo=timezone.utc)
    assert list(due_candidates(site, before)) == []
    assert list(due_candidates(site, exactly)) == ['early.md', 'escaped.md']

    for target, extra in [('public', []), ('preview', ['--include-drafts'])]:
        subprocess.run([cli, 'build', site, root / target, *extra], check=True, capture_output=True)
    assert (root / 'public/early.html').exists()
    assert not (root / 'public/later.html').exists()
    assert not (root / 'public/held.html').exists()
    assert (root / 'preview/later.html').exists() and (root / 'preview/held.html').exists()
    escaped.unlink()
    (site / 'content/early.md').unlink()
    assert list(due_candidates(site, exactly)) == []

print('Pages schedules: JST and UTC, invalid dates, exact cron boundary, draft exclusion and native output.')
