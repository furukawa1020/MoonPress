"""Validate a public deployment base URL before it enters commands or logs."""
import sys,urllib.parse
try:
    value=sys.argv[1]
    parsed=urllib.parse.urlsplit(value)
    valid=(parsed.scheme in ('http','https') and bool(parsed.hostname)
           and parsed.username is None and parsed.password is None
           and '?' not in value and '#' not in value
           and not any(char.isspace() or ord(char)<32 or ord(char)==127 for char in value)
           and (parsed.port is None or 1<=parsed.port<=65535))
except (IndexError,ValueError):
    valid=False
if not valid:
    raise SystemExit('Invalid public base URL.')
