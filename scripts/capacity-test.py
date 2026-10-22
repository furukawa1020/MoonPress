#!/usr/bin/env python3
"""Validate real concurrent requests and failure accounting independently of WP."""
import hashlib
import http.server
import pathlib
import sys
import threading
sys.path.insert(0, str(pathlib.Path('benchmarks/wordpress').resolve()))
from capacity import load

body = b'capacity fixture\x00\xff'
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200 if self.path == '/ok' else 503)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *_):
        pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    target = [('/ok', hashlib.sha256(body).hexdigest())]
    row = load(*server.server_address, target, 4, 16)
    assert row['errors'] == 0 and row['valid_rps'] == row['completed_rps']
    assert [r['request'] for r in row['samples']] == list(range(16))
    assert len({r['worker'] for r in row['samples']}) == 4
    assert row['p99_ms'] >= row['p95_ms'] >= row['median_ms'] > 0
    for target in ([('/ok', 'wrong-hash')], [('/unavailable', hashlib.sha256(body).hexdigest())]):
        row = load(*server.server_address, target, 2, 8)
        assert row['errors'] == 8 and row['error_rate'] == 1 and row['valid_rps'] == 0
    for concurrency, requests in ((0, 16), (65, 128), (8, 4), (1, 4097)):
        try:
            load(*server.server_address, target, concurrency, requests)
        except ValueError:
            pass
        else:
            raise AssertionError('Missing load bound')
finally:
    server.shutdown()
    server.server_close()
    thread.join()
print('Capacity harness passed: concurrency, byte identity, errors, quantiles and load bounds.')
