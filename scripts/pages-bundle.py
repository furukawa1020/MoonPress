"""Inspect the expected public bundle before publication verification."""
import hashlib,json,os,pathlib,stat,sys
try:
    root=pathlib.Path(sys.argv[1])
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Expected a regular bundle directory.')
    entries=sorted(root.iterdir(),key=lambda entry:entry.name)
    if not entries:
        raise ValueError('Expected a nonempty public bundle.')
    if any(entry.is_symlink() or not entry.is_file() for entry in entries):
        raise ValueError('Public bundle entries must be regular files.')
    index=root/'index.html'
    if not index.is_file() or index.stat().st_size==0:
        raise ValueError('Public bundle requires a nonempty index.html.')
    if any(entry.name.startswith('.') and entry.name!='.nojekyll' for entry in entries):
        raise ValueError('Internal files must not appear in the public bundle.')
    snapshot=pathlib.Path(sys.argv[2]) if len(sys.argv)==3 else None
    if snapshot is not None:
        snapshot.mkdir()
    records=[]
    for entry in entries:
        digest=hashlib.sha256()
        descriptor=os.open(entry,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
        with os.fdopen(descriptor,'rb') as source:
            before=os.fstat(source.fileno())
            if not stat.S_ISREG(before.st_mode):
                raise ValueError('Bundle entry changed type.')
            target=open(snapshot/entry.name,'xb') if snapshot is not None else None
            try:
                while True:
                    chunk=source.read(65536)
                    if not chunk:break
                    digest.update(chunk)
                    if target is not None:target.write(chunk)
            finally:
                if target is not None:target.close()
            after=os.fstat(source.fileno())
            if (before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns):
                raise ValueError('Bundle changed during inspection.')
        records.append([entry.name,digest.hexdigest()])
    print(json.dumps(records))
except (OSError,ValueError,IndexError) as error:
    raise SystemExit(str(error))
