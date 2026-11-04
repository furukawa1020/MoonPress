from release_archive_fixture import *
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp);marker=root/'executed'
    fake=b'#!/usr/bin/env bash\ntouch "$EXECUTION_MARKER"\nexit 0\n'
    license=b'License';digest=hashlib.sha256(license).hexdigest()
    path=archive(root,[(ROOT+'/moonpress',fake),(ROOT+'/LICENSE',license),(ROOT+'/EXECUTABLE.sha256',(digest+'  LICENSE\n').encode())])
    env=dict(os.environ,EXECUTION_MARKER=str(marker));env.pop('MOONPRESS_EXPECT_REVISION',None)
    result=subprocess.run(['bash','scripts/release-smoke.sh',str(path.parent)],env=env,capture_output=True,text=True)
    assert result.returncode!=0 and not marker.exists(),result.stderr
