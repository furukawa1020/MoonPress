"""Disposable archive fixtures, with extraction intercepted on rejection paths."""
import hashlib,io,os,pathlib,subprocess,tarfile,tempfile
ROOT='moonpress-linux-x86_64'
def archive(root,entries):
    package=root/'package';package.mkdir(exist_ok=True)
    path=package/(ROOT+'.tar.gz')
    with tarfile.open(path,'w:gz') as output:
        for name,value in entries:
            info=tarfile.TarInfo(name)
            if isinstance(value,tarfile.TarInfo):
                output.addfile(value)
            else:
                info.size=len(value);info.mode=0o755 if name==ROOT+'/moonpress' else 0o644
                output.addfile(info,io.BytesIO(value))
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    (package/'SHA256SUMS').write_text(digest+'  '+path.name+'\n')
    return path
def validate(path):
    return subprocess.run(['python3','scripts/validate-release-archive.py',str(path)],capture_output=True,text=True)
def blocked_extraction(root,package):
    binary=root/'bin';binary.mkdir();marker=root/'extracted'
    command=binary/'tar';command.write_text('#!/usr/bin/env bash\ntouch "$EXTRACTION_MARKER"\nexit 1\n');command.chmod(0o755)
    env=dict(os.environ,PATH=str(binary)+':'+os.environ['PATH'],EXTRACTION_MARKER=str(marker))
    env.pop('MOONPRESS_EXPECT_REVISION',None)
    result=subprocess.run(['bash','scripts/release-smoke.sh',str(package)],env=env,capture_output=True,text=True)
    assert result.returncode!=0 and not marker.exists(),result.stderr
