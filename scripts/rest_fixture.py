"""Private disposable native REST fixture shared by HTTP regression scripts."""
import base64,http.client,json,pathlib,socket,subprocess,tempfile,time
CLI=pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
def run(*args,ok=True):
    result=subprocess.run([CLI,*map(str,args),'--json'],capture_output=True,text=True)
    assert (result.returncode==0)==ok,result.stderr
    return json.loads(result.stdout)['report'] if ok else None
class NativeSite:
    def __enter__(self):
        self.temporary=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.temporary.name);self.site=self.root/'site'
        run('init',self.site)
        for path in (self.site/'content').glob('*.md'):path.unlink()
        self.tokens={};self.ids={};self.secrets=[];self.revision='absent'
        for role in ['administrator','author','contributor','subscriber','editor']:
            change=run('access-change',self.site,self.revision,'grant',role,role);self.revision=change['report']['revision']
            self.ids[role]=len(self.ids)+1;self.secrets.append(change['secret'])
            self.tokens[role]='Basic '+base64.b64encode((role+':'+change['secret']).encode()).decode()
        listener=socket.socket();listener.bind(('127.0.0.1',0));self.port=listener.getsockname()[1];listener.close()
        self.start()
        return self
    def start(self):
        self.process=subprocess.Popen([CLI,'rest',self.site,str(self.port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                if self.request('/wp-json/')[0]==200:return
            except OSError:time.sleep(.02)
        self.__exit__(None,None,None);raise AssertionError('Listener unavailable')
    def restart(self):
        self.process.terminate();self.process.wait(timeout=8)
        listener=socket.socket();listener.bind(('127.0.0.1',0));self.port=listener.getsockname()[1];listener.close();self.start()
    def request(self,path,method='GET',data=None,role=None,etag=None,headers=None):
        selected=dict(headers or {})
        if role:selected['Authorization']=self.tokens[role]
        if etag:selected['If-Match']=etag
        payload=None if data is None else json.dumps(data)
        if data is not None:selected['Content-Type']='application/json'
        connection=http.client.HTTPConnection('127.0.0.1',self.port,timeout=8);connection.request(method,path,payload,selected)
        response=connection.getresponse();raw=response.read();connection.close()
        assert not any(secret.encode() in raw for secret in self.secrets)
        return response.status,dict(response.getheaders()),json.loads(raw) if raw else None
    def __exit__(self,*args):
        self.process.terminate();self.process.wait(timeout=8);self.temporary.cleanup()
