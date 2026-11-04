"""Loopback publication fixture with observable requests and controlled edits."""
import http.server,pathlib,shutil,subprocess,tempfile,threading,urllib.parse
class PublicFixture:
    def __enter__(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.root=pathlib.Path(self.temporary.name)
        self.expected=self.root/'expected';self.expected.mkdir()
        (self.expected/'index.html').write_text('<h1>Public</h1>')
        (self.expected/'.nojekyll').write_bytes(b'')
        self.served=self.root/'served';shutil.copytree(self.expected,self.served)
        self.requests=[];self.callback=None
        fixture=self
        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_GET(self):
                name=urllib.parse.unquote(urllib.parse.urlsplit(self.path).path).lstrip('/')
                fixture.requests.append(name)
                if fixture.callback:fixture.callback(name)
                path=fixture.served/name
                if not path.is_file():self.send_error(404);return
                data=path.read_bytes();self.send_response(200)
                self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        self.server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.url='http://127.0.0.1:'+str(self.server.server_port)+'/'
        return self
    def verify(self,url=None,bundle=None):
        return subprocess.run(['bash','scripts/verify-pages.sh',str(bundle or self.expected),url or self.url],capture_output=True,text=True,timeout=12)
    def __exit__(self,*args):
        self.server.shutdown();self.server.server_close();self.thread.join();self.temporary.cleanup()
