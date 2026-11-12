"""Normalize Pages form input and decide whether the scheduled build is due."""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import sys

DATE = r'[0-9]{4}-[0-9]{2}-[0-9]{2}'
UTC = re.compile(DATE + r'T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')
JST_MINUTE = re.compile(DATE + r'[ T][0-9]{2}:[0-9]{2}')
JST = timezone(timedelta(hours=9))


def publication_input(value):
    value = value.strip()
    try:
        if UTC.fullmatch(value):
            return datetime.fromisoformat(value[:-1] + '+00:00').isoformat().replace('+00:00', 'Z')
        if JST_MINUTE.fullmatch(value):
            local = datetime.fromisoformat(value).replace(tzinfo=JST)
            return local.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')
    except (ValueError, OverflowError):
        pass
    raise ValueError('予約日時は JST の YYYY-MM-DD HH:MM または UTC の YYYY-MM-DDTHH:MM:SSZ で入力してください。')


def due_candidates(site, now):
    """Read only the JSON front matter convention used by the native compiler."""
    content = site / 'content'
    if site.is_symlink() or content.is_symlink() or not content.is_dir():
        raise ValueError('予約確認には正規の原稿フォルダが必要です。')
    for path in sorted(content.glob('*.md')):
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'通常の原稿ファイルが必要です: {path.name}')
        raw = path.read_bytes().decode('utf-8').replace('\r\n', '\n')
        if not raw.startswith('---\n'):
            continue
        header, separator, _ = raw[4:].partition('\n---\n')
        if not separator:
            if not header.endswith('\n---'):
                raise ValueError(f'原稿の先頭に閉じていない設定欄があります: {path.name}')
            header = header[:-4]
        metadata = json.loads(header)
        value = metadata.get('publish_at')
        if value is None or metadata.get('draft', False) is not False:
            continue
        if not isinstance(value, str) or not UTC.fullmatch(value):
            raise ValueError(f'原稿の publish_at は UTC 形式で保存してください: {path.name}')
        if datetime.fromisoformat(value[:-1] + '+00:00') <= now:
            yield path.name


if __name__ == '__main__':
    try:
        count = sum(1 for _ in due_candidates(Path(sys.argv[1]), datetime.now(timezone.utc)))
        print('true' if count else 'false')
    except (OSError, ValueError, AttributeError) as error:
        sys.exit(str(error))
