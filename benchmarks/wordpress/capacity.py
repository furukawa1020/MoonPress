"""Bounded closed-loop load against NGINX and a dedicated PHP-FPM pool."""
import concurrent.futures
import contextlib
import hashlib
import http.client
import itertools
import json
import math
import os
import pathlib
import socket
import statistics
import subprocess
import time

VARIANTS = ('wordpress-dynamic', 'wordpress-cached-html', 'moonpress-static')


def load(host, port, targets, concurrency, requests=192):
    if not 1 <= concurrency <= 64 or not concurrency <= requests <= 4096:
        raise ValueError('Load bounds exceeded')
    # Each worker owns one blocking connection at a time, no request queue in an
    # executor. Timing includes connect, headers and entire verified response.
    def worker(worker_id):
        records = []
        for index in range(worker_id, requests, concurrency):
            path, expected = targets[index % len(targets)]
            start = time.perf_counter_ns()
            connection = http.client.HTTPConnection(host, port, timeout=10)
            record = {'request': index, 'worker': worker_id, 'path': path}
            try:
                connection.request('GET', path, headers={'Connection': 'close', 'Accept-Encoding': 'identity'})
                response = connection.getresponse()
                body = response.read()
                digest = hashlib.sha256(body).hexdigest()
                record.update(status=response.status, bytes=len(body), sha256=digest,
                              valid=response.status == 200 and digest == expected)
            except (OSError, http.client.HTTPException) as error:
                record.update(status=None, bytes=0, valid=False, error=type(error).__name__)
            finally:
                connection.close()
            record['ms'] = (time.perf_counter_ns() - start) / 1e6
            records.append(record)
        return records
    start = time.perf_counter_ns()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        records = sorted(itertools.chain.from_iterable(pool.map(worker, range(concurrency))), key=lambda r: r['request'])
    elapsed = (time.perf_counter_ns() - start) / 1e9
    latency = sorted(record['ms'] for record in records)
    valid = sum(record['valid'] for record in records)
    return {'concurrency': concurrency, 'requests': requests, 'elapsed_s': elapsed,
            'completed_rps': requests / elapsed, 'valid_rps': valid / elapsed,
            'errors': requests - valid, 'error_rate': (requests - valid) / requests,
            'median_ms': statistics.median(latency), 'p95_ms': latency[math.ceil(.95 * requests)-1],
            'p99_ms': latency[math.ceil(.99 * requests)-1], 'samples': records}


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def quoted(path):
    text = str(path)
    if any(c in text for c in '\n\r"\\$'):
        raise ValueError('Unsafe configuration path')
    return '"' + text + '"'


@contextlib.contextmanager
def production_server(work, wordpress, static):
    port, fpm_port = free_port(), free_port()
    while port == fpm_port:
        fpm_port = free_port()
    fpm = work / 'fpm.conf'
    fpm.write_text(f'''[global]
error_log = {work}/fpm.log
daemonize = no
[benchmark]
listen = 127.0.0.1:{fpm_port}
pm = static
pm.max_children = 4
clear_env = no
catch_workers_output = yes
php_admin_value[opcache.enable] = 1
php_admin_value[opcache.validate_timestamps] = 0
php_admin_value[xdebug.mode] = off
''', encoding='utf-8')
    config = work / 'nginx.conf'
    config.write_text(f'''worker_processes 2;
pid {quoted(work / 'nginx.pid')};
error_log {quoted(work / 'nginx.log')} warn;
events {{ worker_connections 1024; }}
http {{
  access_log off;
  sendfile on;
  default_type application/octet-stream;
  client_body_temp_path {quoted(work / 'body')};
  fastcgi_temp_path {quoted(work / 'fastcgi')};
  server {{
    listen 127.0.0.1:{port};
    root {quoted(static)};
    location = / {{
      include /etc/nginx/fastcgi_params;
      fastcgi_param SCRIPT_FILENAME {quoted(wordpress / 'index.php')};
      fastcgi_pass 127.0.0.1:{fpm_port};
    }}
    location = /runtime {{
      include /etc/nginx/fastcgi_params;
      fastcgi_param SCRIPT_FILENAME {quoted(wordpress / 'moonpress-benchmark-runtime.php')};
      fastcgi_pass 127.0.0.1:{fpm_port};
    }}
    location ~ /\\. {{ return 404; }}
    location / {{ try_files $uri =404; }}
  }}
}}
''', encoding='utf-8')
    subprocess.run(['php', '-r', "require $argv[1]; update_option('home', $argv[2]); update_option('siteurl', $argv[2]);", str(wordpress/'wp-load.php'), f'http://127.0.0.1:{port}'], check=True)
    subprocess.run(['nginx', '-t', '-c', str(config)], check=True)
    with (work / 'process.log').open('wb') as log:
        processes = []
        try:
            processes.append(subprocess.Popen(['php-fpm8.3', '-d', 'xdebug.mode=off', '-F', '-y', str(fpm)], stdout=log, stderr=log, env={**os.environ, 'XDEBUG_MODE':'off'}))
            processes.append(subprocess.Popen(['nginx', '-c', str(config), '-g', 'daemon off;'], stdout=log, stderr=log))
            for endpoint in (fpm_port, port):
                for _ in range(100):
                    if any(p.poll() is not None for p in processes):
                        raise RuntimeError('Serving process exited: ' + (work / 'process.log').read_text())
                    try:
                        with socket.create_connection(('127.0.0.1', endpoint), timeout=.1):
                            break
                    except OSError:
                        time.sleep(.05)
                else:
                    raise RuntimeError('Serving process did not become ready')
            yield port
        finally:
            for process in reversed(processes):
                process.terminate()
                try:
                    process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()


def compare_capacity(work, wordpress, static, articles, mapping):
    work.mkdir()
    records = []
    with production_server(work, wordpress, static) as port:
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=10)
        connection.request('GET', '/runtime')
        response = connection.getresponse()
        runtime = json.loads(response.read())
        connection.close()
        if response.status != 200 or runtime['opcache_enabled'] is not True or runtime['xdebug_active_modes'] != []:
            raise ValueError('Unexpected FPM runtime: ' + str(runtime))
        targets = {variant: [] for variant in VARIANTS}
        for article in articles:
            slug = article['slug'] + '.html'
            targets['wordpress-dynamic'].append(('/?p=' + str(mapping[str(article['id'])]), hashlib.sha256((static/'cache-1000'/slug).read_bytes()).hexdigest()))
            for variant, folder in (('wordpress-cached-html','cache-1000'), ('moonpress-static','native-1000')):
                targets[variant].append(('/'+folder+'/'+slug, hashlib.sha256((static/folder/slug).read_bytes()).hexdigest()))
        for variant in VARIANTS:
            warm = load('127.0.0.1', port, targets[variant], 1, 12)
            if warm['errors']:
                raise ValueError('Warmup failed: '+str(warm))
        # Three rounds rotate each variant through every position at each load.
        for concurrency in (1, 8, 32):
            for repeat in range(3):
                order = VARIANTS[repeat:] + VARIANTS[:repeat]
                for variant in order:
                    row = load('127.0.0.1', port, targets[variant], concurrency)
                    row.update(variant=variant, repeat=repeat+1, order=list(order))
                    records.append(row)
    return {'schema':1, 'articles':1000, 'workload':'bounded closed-loop, loopback HTTP/1.1, new connections, identity encoding',
            'limitations':'Client shares host and may bottleneck; no coordinated-omission correction, TLS, CDN, network, cold cache or production maximum claim.',
            'nginx_version':subprocess.check_output(['nginx','-v'],stderr=subprocess.STDOUT,text=True).strip(),
            'fpm_version':subprocess.check_output(['php-fpm8.3','-v'],text=True).splitlines()[0],
            'php_runtime':runtime, 'nginx_workers':2, 'fpm_children':4, 'groups':records}
