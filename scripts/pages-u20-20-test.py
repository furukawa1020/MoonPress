from release_archive_fixture import *
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp)
    path=archive(root,[(ROOT+'/f'+str(i),b'') for i in range(1025)])
    assert validate(path).returncode!=0
    large=tarfile.TarInfo(ROOT+'/large');large.size=64*1024*1024+1
    path=archive(root,[(large.name,large)]);assert validate(path).returncode!=0
    blocked_extraction(root,path.parent)
    path=archive(root,[(ROOT+'/moonpress',b'normal')]);assert validate(path).returncode==0
