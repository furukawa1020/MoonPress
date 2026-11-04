"""Inspect candidate members before extracting a downloaded release archive."""
import gzip,sys,tarfile
ROOT='moonpress-linux-x86_64'
MAX_MEMBERS=1024
MAX_FILE=64*1024*1024
MAX_EXPANDED=256*1024*1024
class ReadBudget:
    def __init__(self,source):
        self.source=source
        self.remaining=MAX_EXPANDED
    def read(self,size):
        if size<0 or size>self.remaining:
            raise ValueError('Archive decompression exceeds the byte limit.')
        data=self.source.read(size)
        self.remaining-=len(data)
        return data
try:
    with gzip.open(sys.argv[1],'rb') as compressed, tarfile.open(fileobj=ReadBudget(compressed),mode='r|') as archive:
        seen=set()
        total=0
        count=0
        for member in archive:
            count+=1
            total+=member.size
            if count>MAX_MEMBERS or member.size<0 or member.size>MAX_FILE or total>MAX_EXPANDED:
                raise ValueError('Archive member count or size exceeds the limit.')
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
