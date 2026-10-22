#!/usr/bin/env python3
"""Raw sockets exercise segmentation, binary suffixes and absolute deadlines."""
import pathlib
import socket
import subprocess
import tempfile
import time

CLI = pathlib.Path('_build/native/release/build/cmd/main/main.exe').resolve()
with tempfile.TemporaryDirectory(prefix='moonpress-http-buffer-') as temporary:
    site = pathlib.Path(temporary) / 'site'
    subprocess.run([CLI, 'init', site], check=True, stdout=subprocess.DEVNULL)
    for _ in range(100):
        with socket.socket() as admin_port, socket.socket() as preview_port:
            admin_port.bind(('127.0.0.1', 0))
            port = admin_port.getsockname()[1]
            if port >= 65535:
                continue
            try:
                preview_port.bind(('127.0.0.1', port + 1))
            except OSError:
                continue
            break
    else:
        raise RuntimeError('No free admin/preview port pair')
    server = subprocess.Popen([CLI, 'admin', site, str(port)], stdout=subprocess.PIPE)
    try:
        assert b'MoonPress admin:' in server.stdout.readline()
        host = f'127.0.0.1:{port}'
        def exchange(parts):
            with socket.create_connection(('127.0.0.1', port), timeout=8) as connection:
                for part in parts:
                    connection.sendall(part)
                connection.shutdown(socket.SHUT_WR)
                result = bytearray()
                while True:
                    try:
                        data = connection.recv(65536)
                    except ConnectionResetError:
                        break  # Rejected oversized requests can leave unread bytes.
                    if not data:
                        break
                    result.extend(data)
                return bytes(result)
        prefix = f'GET / HTTP/1.1\r\nHost: {host}\r\n'.encode()
        for parts in ([prefix + b'\r\n'], [bytes([byte]) for byte in prefix + b'\r\n']):
            assert exchange(parts).startswith(b'HTTP/1.1 200 OK')
        page = exchange([prefix + b'\r\n'])
        import re
        token = re.search(rb'name="token" value="([a-f0-9]{64})"', page)[1]
        body = b'token=' + token + b'&slug=buffered&title=Buffered'
        headers = (f'POST /new HTTP/1.1\r\nHost: {host}\r\nOrigin: http://{host}\r\n'
                   f'Content-Type: application/x-www-form-urlencoded\r\nContent-Length: {len(body)}\r\n\r\n').encode()
        assert exchange([headers + body]).startswith(b'HTTP/1.1 200 OK')
        assert (site / 'content/buffered.md').exists()
        assert exchange([prefix + b'X-Padding: ' + b'x' * 17000 + b'\r\n\r\n']).startswith(b'HTTP/1.1 400')
        assert exchange([headers + body[:-1]]).startswith(b'HTTP/1.1 400')
        # Continued activity must not renew the deadline. Stop sending before
        # expiry, then verify closure around five seconds after accept.
        for initial in (b'GET / HTTP/1.1\r\nX-Trickle: ', headers):
            with socket.create_connection(('127.0.0.1', port), timeout=8) as connection:
                start = time.monotonic()
                connection.sendall(initial)
                for _ in range(6):
                    time.sleep(.5)
                    connection.sendall(b'x')
                response = connection.recv(65536)
                elapsed = time.monotonic() - start
                assert response.startswith(b'HTTP/1.1 400'), response
                assert 4 <= elapsed < 7, elapsed
            assert exchange([prefix + b'\r\n']).startswith(b'HTTP/1.1 200 OK')
        print('Buffered HTTP tests passed: segmentation, coalesced body, limits, header/body absolute deadlines and recovery.')
    finally:
        server.terminate()
        server.wait(timeout=8)
