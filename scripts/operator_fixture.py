import http.client,re,socket,subprocess,time,urllib.parse
from rest_fixture import CLI
class Operator:
    def __init__(self,site):self.site=site
    def __enter__(self):
        for _ in range(100):
            a=socket.socket();b=socket.socket();a.bind(('127.0.0.1',0));self.port=a.getsockname()[1]
            try:b.bind(('127.0.0.1',self.port+1))
            except OSError:a.close();b.close();continue
            a.close();b.close();break
        else:raise AssertionError('No admin port pair')
        self.process=subprocess.Popen([CLI,'admin',self.site,str(self.port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                if self.request('/comments')[0]==200:return self
            except OSError:pass
            time.sleep(.02)
        self.__exit__();raise AssertionError('Operator listener unavailable')
    def request(self,path,method='GET',fields=None,headers=None):
        h={'Accept-Language':'en',**(headers or {})};payload=None
        if fields is not None:payload=urllib.parse.urlencode(fields);h['Content-Type']='application/x-www-form-urlencoded'
        c=http.client.HTTPConnection('127.0.0.1',self.port,timeout=8);c.request(method,path,payload,h);r=c.getresponse();body=r.read().decode();c.close();return r.status,body
    def token(self,body):return re.search(r'name="token" value="([a-f0-9]{64})"',body)[1]
    def __exit__(self,*args):self.process.terminate();self.process.wait(timeout=8)
