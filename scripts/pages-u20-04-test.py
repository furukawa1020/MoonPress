from pages_preview_fixture import *
import os,subprocess
with source() as root:
    env=dict(os.environ,GITHUB_REPOSITORY='example/moonpress',GITHUB_SHA='fixture',GH_TOKEN='fixture')
    result=subprocess.run(['bash','scripts/deploy-pages.sh','a','b','c'],env=env,capture_output=True,text=True)
    assert result.returncode==2 and 'Usage:' in result.stderr
script('pages-deploy-preflight-test.sh')
