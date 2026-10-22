"""Real local HTTP comparison: identical corpus, shared server, cached control."""
import argparse
import contextlib
import json
import itertools
import math
import os
from pathlib import Path
import platform
import shutil
import socket
import statistics
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from fixture import generate, sha256, verify_html
from native import environment, native_benchmark, summarize

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def request(url):
    start = time.perf_counter_ns()
    with HTTP.open(urllib.request.Request(url, headers={'Accept-Encoding':'identity', 'Connection':'close'}), timeout=20) as response:
        headers = time.perf_counter_ns()
        body = response.read()
        end = time.perf_counter_ns()
        if response.status != 200:
            raise ValueError('Non-200 response')
        return body, {'headers_ms': (headers-start)/1e6, 'total_ms': (end-start)/1e6,
                      'response_bytes': len(body), 'response_sha256': sha256(body)}


@contextlib.contextmanager
def server(root, port):
    with tempfile.TemporaryFile() as log:
        process = subprocess.Popen(['php', '-d', 'opcache.enable_cli=1', '-d', 'opcache.enable=1', '-d', 'xdebug.mode=off', '-S', f'127.0.0.1:{port}', '-t', str(root)], stdout=log, stderr=log, env={**os.environ, 'XDEBUG_MODE':'off'})
        try:
            for _ in range(100):
                if process.poll() is not None:
                    log.seek(0)
                    raise RuntimeError(log.read().decode())
                try:
                    with socket.create_connection(('127.0.0.1',port), timeout=.1):
                        break
                except OSError:
                    time.sleep(.05)
            else:
                raise RuntimeError('Server did not start')
            yield process
        finally:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()


def rss_kib(pid):
    if pid is None:
        return None
    try:
        status = Path(f'/proc/{pid}/status').read_text(encoding="utf-8")
        return int(next(line for line in status.splitlines() if line.startswith('VmRSS:')).split()[1])
    except (OSError, StopIteration):
        return None


def compare(wordpress, archive, cli, samples):
    if not os.environ.get('MOONPRESS_BENCH_DB_PASSWORD'):
        raise ValueError('Disposable database password is required')
    wordpress = Path(wordpress).resolve()
    cli = Path(cli).resolve()
    result = {'schema':1, 'workload':'warm-serial-loopback-http', 'environment':environment(cli),
              'wordpress_archive_sha256':sha256(Path(archive).read_bytes()),
              'wordpress_archive_url':'https://wordpress.org/wordpress-7.1.3.tar.gz',
              'theme_sha256':sha256((HERE/'theme.php').read_bytes()),
              'conditions':{'warmup_per_variant_and_article':5, 'samples_per_variant_per_count':samples, 'order':'all six variant permutations repeated equally',
                            'variants':['wordpress-dynamic','wordpress-cached-html','moonpress-static'],
                            'server':'same PHP built-in server executable; OPcache enabled for CLI server; Xdebug mode off',
                            'cache':'warm OS/DB caches, no page cache plugin or persistent object cache; cached control is a static response snapshot',
                            'transport':'serial HTTP/1.1 loopback, new connection per request, identity encoding, no CDN/TLS',
                            'header_clock':'urlopen response headers available; not exact first-body-byte time',
                            'memory':'/proc VmRSS snapshots; database separate; not peak or per-request allocations'},
              'fixtures':[], 'samples':[], 'rss_snapshots':[]}
    try:
        mysql_pid = int(subprocess.check_output(['pgrep','-xo','mysqld'],text=True).strip())
    except (OSError, subprocess.CalledProcessError, ValueError):
        mysql_pid = None
    shutil.copyfile(HERE/'config.php', wordpress/'wp-config.php')
    theme = wordpress/'wp-content/themes/moonpress-benchmark'
    theme.mkdir(exist_ok=False)
    shutil.copyfile(HERE/'theme.php', theme/'index.php')
    (theme/'style.css').write_text('/*\nTheme Name: MoonPress benchmark\nVersion: 1\n*/\n', encoding="utf-8")
    probe = wordpress/'moonpress-benchmark-runtime.php'
    probe.write_text("<?php echo json_encode(['opcache_enabled'=>function_exists('opcache_get_status') && (opcache_get_status(false)['opcache_enabled'] ?? false), 'xdebug_loaded'=>extension_loaded('xdebug'), 'xdebug_active_modes'=>function_exists('xdebug_info') ? xdebug_info('mode') : [], 'xdebug_mode'=>ini_get('xdebug.mode'), 'php_version'=>PHP_VERSION]);", encoding="utf-8")
    dynamic_port, static_port = free_port(), free_port()
    if dynamic_port == static_port:
        static_port = free_port()
    dynamic_origin = f'http://127.0.0.1:{dynamic_port}'
    static_origin = f'http://127.0.0.1:{static_port}'
    with tempfile.TemporaryDirectory(prefix='moonpress-http-benchmark-') as temporary:
        temporary = Path(temporary)
        serve = temporary/'serve'; serve.mkdir()
        # Install and seed before serving; a re-seed is between complete sample groups.
        for index,count in enumerate((10,100,1000)):
            fixture = temporary/str(count)
            result['fixtures'].append(generate(fixture,count))
            articles = json.loads((fixture/'dataset.json').read_text(encoding="utf-8"))['articles']
            seed = subprocess.check_output(['php',str(HERE/'seed.php'),str(wordpress),str(fixture/'dataset.json'),dynamic_origin],text=True)
            metadata = json.loads(seed)
            if metadata['wordpress_version'] != '7.1.3' or metadata['plugins'] or metadata['count'] != count:
                raise ValueError('Unexpected WordPress setup: '+seed)
            result['wordpress'] = {key:value for key,value in metadata.items() if key != 'mapping'}
            native_out = serve/f'native-{count}'
            cache = serve/f'cache-{count}'; cache.mkdir()
            subprocess.run([str(cli),'build',str(fixture/'site'),str(native_out)],stdout=subprocess.DEVNULL,check=True)
            with server(wordpress,dynamic_port) as dynamic, server(serve,static_port) as static:
                probe_body,_ = request(dynamic_origin+'/moonpress-benchmark-runtime.php')
                runtime = json.loads(probe_body)
                if runtime['opcache_enabled'] is not True or runtime['xdebug_active_modes'] != []:
                    raise ValueError('Unexpected PHP benchmark runtime: '+str(runtime))
                result['php_server_runtime'] = runtime
                # Validate every imported dynamic article, cache the actual response and
                # verify every native article before sampling. This deliberately warms DB.
                snapshot_hashes=[]
                for article in articles:
                    body,_ = request(dynamic_origin+'/?p='+str(metadata['mapping'][str(article['id'])]))
                    verify_html(body,article)
                    (cache/(article['slug']+'.html')).write_bytes(body)
                    verify_html((native_out/(article['slug']+'.html')).read_bytes(),article)
                    snapshot_hashes.append(sha256(body))
                result['fixtures'][-1]['wordpress_snapshot_set_sha256']=sha256('\n'.join(snapshot_hashes).encode())
                selected = [articles[0],articles[count//2],articles[-1]]
                variants = result['conditions']['variants']
                def url(variant,article):
                    if variant=='wordpress-dynamic':
                        return dynamic_origin+'/?p='+str(metadata['mapping'][str(article['id'])])
                    folder = f'cache-{count}' if variant=='wordpress-cached-html' else f'native-{count}'
                    return static_origin+'/'+folder+'/'+article['slug']+'.html'
                for article in selected:
                    for _ in range(5):
                        for variant in variants:
                            body,_ = request(url(variant,article)); verify_html(body,article)
                orders = list(itertools.permutations(variants))
                for sample in range(samples):
                    article = selected[(sample//len(orders))%len(selected)]
                    order = orders[sample%len(orders)]
                    for variant in order:
                        body,record = request(url(variant,article))
                        verify_html(body,article)
                        record.update(count=count,variant=variant,sample=sample+1,article_id=article['id'],order=list(order))
                        result['samples'].append(record)
                result['rss_snapshots'].append({'count':count,'wordpress_php_kib':rss_kib(dynamic.pid),
                    'static_php_kib':rss_kib(static.pid),'mysql_service_kib':rss_kib(mysql_pid)})
    result['summary']=[{'count':count,'variant':variant,
                        'total_ms':summarize([s['total_ms'] for s in result['samples'] if s['count']==count and s['variant']==variant]),
                        'headers_ms':summarize([s['headers_ms'] for s in result['samples'] if s['count']==count and s['variant']==variant]),
                        'response_bytes':summarize([s['response_bytes'] for s in result['samples'] if s['count']==count and s['variant']==variant])}
                       for count in (10,100,1000) for variant in result['conditions']['variants']]
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('wordpress',type=Path)
    parser.add_argument('archive',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--cli',type=Path,default=ROOT/'_build/native/release/build/cmd/main/main.exe')
    parser.add_argument('--samples',type=int,default=60)
    args=parser.parse_args()
    if not 12<=args.samples<=996 or args.samples%6: parser.error('samples must be a multiple of six in 12..996')
    with args.output.open('x') as file:
        json.dump(compare(args.wordpress,args.archive,args.cli,args.samples),file,indent=2,sort_keys=True)
        file.write('\n')
