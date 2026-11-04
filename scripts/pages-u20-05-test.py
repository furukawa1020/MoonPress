import subprocess
valid=['https://example.test/site/','http://127.0.0.1:8080/site','http://[::1]:8080/']
invalid=['','null','file:///tmp/site','https:///path','https://user:secret@example.test/','https://example.test/?x=1','https://example.test/#part','https://example.test:99999/','https://example.test/\n']
for value in valid+invalid:
    result=subprocess.run(['python3','scripts/pages-url.py',value],capture_output=True)
    assert (result.returncode==0)==(value in valid),value
from pages_preview_fixture import script
script('pages-deploy-preflight-test.sh')
