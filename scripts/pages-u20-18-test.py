from release_archive_fixture import *
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp)
    for kind in [tarfile.SYMTYPE,tarfile.LNKTYPE,tarfile.FIFOTYPE,tarfile.CHRTYPE,tarfile.BLKTYPE]:
        info=tarfile.TarInfo(ROOT+'/entry');info.type=kind;info.linkname='/outside'
        path=archive(root,[(info.name,info)]);assert validate(path).returncode!=0,kind
    blocked_extraction(root,path.parent)
