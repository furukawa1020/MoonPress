"""Disposable public files with independently computed native media identities."""
import hashlib,urllib.parse
from rest_fixture import NativeSite
ROUTE='/wp-json/wp/v2/media'
FILES={'alpha.png':b'\x89PNG\r\n\x1a\nA','beta.gif':b'GIF89a'+b'B'*20,'fake.png':b'not an image'}
def ident(name):return (int(hashlib.sha256(('media\n'+name).encode()).hexdigest()[:8],16)&0x7fffffff) or 1
def slug(name):return 'media-'+name.encode().hex()
def names(rows):return [next(n for n in FILES if ident(n)==r['id']) for r in rows]
class MediaSite(NativeSite):
    def __enter__(self):
        super().__enter__();assets=self.site/'public';assets.mkdir()
        for name,raw in FILES.items():(assets/name).write_bytes(raw)
        return self
