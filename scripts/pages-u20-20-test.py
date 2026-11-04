from release_archive_fixture import *
import gzip
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp)
    path=archive(root,[(ROOT+'/f'+str(i),b'') for i in range(1025)])
    assert validate(path).returncode!=0
    large=tarfile.TarInfo(ROOT+'/large');large.size=64*1024*1024+1
    # A deliberately truncated header declares an oversized entry without
    # allocating its payload or relying on TarFile.addfile accepting no data.
    path=root/'package'/(ROOT+'.tar.gz')
    with gzip.open(path,'wb') as compressed:
        compressed.write(large.tobuf(format=tarfile.GNU_FORMAT))
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    (path.parent/'SHA256SUMS').write_text(digest+'  '+path.name+'\n')
    assert validate(path).returncode!=0
    blocked_extraction(root,path.parent)
    path=archive(root,[(ROOT+'/moonpress',b'normal')]);assert validate(path).returncode==0
