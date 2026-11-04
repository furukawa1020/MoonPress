"""Require the expected single checksum target before invoking sha256sum."""
import pathlib,re,sys
try:
    record=pathlib.Path(sys.argv[1]);name=sys.argv[2]
    if record.is_symlink() or not record.is_file() or record.stat().st_size>4096:
        raise ValueError('Invalid checksum record file.')
    text=record.read_text(encoding='ascii')
    if re.fullmatch(r'[0-9a-f]{64}  '+re.escape(name)+r'\n?',text) is None:
        raise ValueError('Checksum must name exactly the expected file once.')
except (OSError,UnicodeError,ValueError,IndexError) as error:
    raise SystemExit(str(error))
