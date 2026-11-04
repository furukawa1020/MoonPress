from pages_poll_fixture import *
for row in [{},{'commit':COMMIT,'status':'unknown'},{'commit':None,'status':'built'}]:
    result=poll([row]);assert result.returncode==1 and 'Invalid Pages build response' in result.stderr
assert poll([{'status':'queued','commit':COMMIT},{'status':'building','commit':COMMIT},{'status':'built','commit':COMMIT}],4).returncode==0
