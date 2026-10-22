#!/usr/bin/env python3
"""Syntax and live boundary checks for the shipped production origin config."""
import http.client
import pathlib
import socket
import subprocess
import tempfile
import time

with tempfile.TemporaryDirectory(prefix='moonpress-origin-') as temporary:
    work = pathlib.Path(temporary)
    public = work / 'public'
    public.mkdir()
    (public / 'index.html').write_bytes(b'<!doctype html><h1>Public</h1>')
    (public / '.nojekyll').write_bytes(b'')
    (public / 'style.css').write_bytes(b'body{color:navy}')
    for name in ('.moonpress.json', '.env', 'source.md', 'dump.sql', 'index.php', 'INDEX.PHP', 'config.ini', 'source.mbt'):
        (public / name).write_bytes(b'PRIVATE SENTINEL')
    private = work / 'secret'
    private.write_bytes(b'PRIVATE SENTINEL')
    (public / 'symlink.txt').symlink_to(private)
    hidden = public / '.moonpress-history'
    hidden.mkdir()
    (hidden / 'revision.json').write_bytes(b'PRIVATE SENTINEL')
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    origin = pathlib.Path('deploy/nginx/moonpress.conf').read_text(encoding='utf-8')
    origin = origin.replace('listen 8080;', f'listen 127.0.0.1:{port};').replace('/srv/moonpress/public', str(public))
    config = work / 'nginx.conf'
    config.write_text(f'pid {work}/nginx.pid;\nerror_log {work}/error.log warn;\nevents {{}}\nhttp {{ include /etc/nginx/mime.types; access_log off; client_body_temp_path {work}/body;\n'+origin+'\n}\n', encoding='utf-8')
    subprocess.run(['nginx', '-t', '-c', config], check=True)
    with (work / 'process.log').open('wb') as log:
        server = subprocess.Popen(['nginx', '-c', config, '-g', 'daemon off;'], stdout=log, stderr=log)
        try:
            for _ in range(100):
                if server.poll() is not None:
                    raise RuntimeError((work / 'process.log').read_text())
                try:
                    with socket.create_connection(('127.0.0.1', port), timeout=.1):
                        break
                except OSError:
                    time.sleep(.05)
            else:
                raise RuntimeError('Origin did not start')
            def request(path, verb='GET'):
                client = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
                try:
                    client.request(verb, path)
                    response = client.getresponse()
                    body = response.read()
                    assert response.getheader('X-Content-Type-Options') == 'nosniff'
                    assert response.getheader('X-Frame-Options') == 'DENY'
                    assert "default-src 'none'" in response.getheader('Content-Security-Policy', '')
                    assert b'PRIVATE SENTINEL' not in body
                    return response.status, body
                finally:
                    client.close()
            assert request('/')[0] == 200
            assert request('/.nojekyll') == (200, b'')
            assert request('/style.css')[0] == 200
            assert request('/', 'HEAD') == (200, b'')
            for path in ('/.moonpress.json', '/%2eenv', '/source.md', '/dump.sql', '/index.php', '/INDEX.PHP', '/config.ini', '/source.mbt', '/.moonpress-history/revision.json', '/index.php/path', '/missing'):
                assert request(path)[0] == 404, path
            assert request('/symlink.txt')[0] in (403, 404)
            for verb in ('POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS', 'TRACE'):
                assert request('/', verb)[0] == 405
            assert (public / 'index.html').read_bytes() == b'<!doctype html><h1>Public</h1>'
        finally:
            server.terminate()
            server.wait(timeout=8)
print('Static origin passed: real NGINX headers, private/source/runtime/symlink refusal, GET/HEAD and method restrictions.')
