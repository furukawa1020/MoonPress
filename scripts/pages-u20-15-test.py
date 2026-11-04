from release_archive_fixture import *
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp);path=archive(root,[(ROOT+'/file',b'x')]);record=path.parent/'SHA256SUMS'
    good=record.read_text();digest=good[:64]
    for value in [digest+'  other\n',good+good,digest+'  ../outside\n',digest+'  /tmp/outside\n',digest+' *'+path.name+'\n']:
        record.write_text(value)
        result=subprocess.run(['python3','scripts/check-release-checksum.py',str(record),path.name],capture_output=True)
        assert result.returncode!=0
    record.write_text(good)
    assert subprocess.run(['python3','scripts/check-release-checksum.py',str(record),path.name]).returncode==0
    (path.parent/'other').write_bytes(path.read_bytes());record.write_text(digest+'  other\n')
    blocked_extraction(root,path.parent)
