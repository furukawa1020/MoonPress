"""Disposable source and production output for publication regressions."""
import contextlib,pathlib,subprocess,tempfile
CLI=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
def cli(*args):
    return subprocess.run([CLI,*map(str,args)],check=True,capture_output=True,text=True)
def script(name,*args,ok=True):
    result=subprocess.run(['bash','scripts/'+name,*map(str,args)],capture_output=True,text=True)
    assert (result.returncode==0)==ok,(name,result.returncode,result.stdout,result.stderr)
    return result
@contextlib.contextmanager
def source():
    with tempfile.TemporaryDirectory() as tmp:
        root=pathlib.Path(tmp)
        cli('init',root/'site')
        cli('build',root/'site',root/'public')
        yield root
