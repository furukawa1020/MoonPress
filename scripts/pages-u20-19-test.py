from release_archive_fixture import *
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp)
    path=archive(root,[(ROOT+'/moonpress',b'first'),(ROOT+'/moonpress',b'last')])
    assert validate(path).returncode!=0
    blocked_extraction(root,path.parent)
