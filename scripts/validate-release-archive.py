"""Inspect candidate members before extracting a downloaded release archive."""
import sys,tarfile
ROOT='moonpress-linux-x86_64'
try:
    with tarfile.open(sys.argv[1],'r:gz') as archive:
        seen=set()
        for member in archive:
            if not member.isfile() and not member.isdir():
                raise ValueError('Archive contains a link or special file.')
            name=member.name.rstrip('/')
            if name in seen:
                raise ValueError('Archive contains duplicate entry paths.')
            seen.add(name)
            parts=name.split('/')
            if not name or name.startswith('/') or any(part in ('','.','..') for part in parts) or parts[0]!=ROOT:
                raise ValueError('Archive entry is outside the expected root.')
except (OSError,ValueError,tarfile.TarError,IndexError) as error:
    raise SystemExit(str(error))
