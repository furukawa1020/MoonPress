from release_archive_fixture import *
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp)
    for name in ['../outside','/tmp/outside',ROOT+'/../outside','other/file',ROOT+'//file',ROOT+'/./file']:
        path=archive(root,[(name,b'x')]);assert validate(path).returncode!=0,name
    blocked_extraction(root,path.parent)
    path=archive(root,[(ROOT+'/moonpress',b'x'),(ROOT+'/licenses/LICENSE',b'x')])
    assert validate(path).returncode==0
