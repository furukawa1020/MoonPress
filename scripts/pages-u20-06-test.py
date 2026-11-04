from pages_poll_fixture import *
assert poll([None,{'status':'built','commit':COMMIT}]).returncode==0
result=poll([None],1)
assert result.returncode==1 and 'timed out' in result.stderr
assert poll([{'status':'built','commit':'b'*40}],1).returncode==1
assert poll([{'status':'errored','commit':COMMIT,'error':{'message':'Failure'}}]).returncode==1
