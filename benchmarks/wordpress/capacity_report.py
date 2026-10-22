"""Regenerate measured capacity tables; refuse inconsistent raw groups."""
import argparse
import gzip
import hashlib
import json
import math
from pathlib import Path
import statistics

VARIANTS = ('wordpress-dynamic', 'wordpress-cached-html', 'moonpress-static')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(evidence):
    http = evidence['http']
    native = evidence['native']
    capacity = http['capacity']
    require(http['environment']['worktree_dirty'] is False and native['environment']['worktree_dirty'] is False, 'Dirty measured source')
    for field in ('source_revision','source_tree','executable_sha256'):
        require(http['environment'][field] == native['environment'][field], 'Measured identity differs')
    require(capacity['articles'] == 1000 and capacity['nginx_workers'] == 2 and capacity['fpm_children'] == 4, 'Serving setup differs')
    require(capacity['php_runtime']['opcache_enabled'] is True and capacity['php_runtime']['xdebug_active_modes'] == [], 'FPM runtime differs')
    groups = capacity['groups']
    expected = {(c,v,r) for c in (1,8,32) for v in VARIANTS for r in (1,2,3)}
    require(len(groups) == len(expected) and {(g['concurrency'],g['variant'],g['repeat']) for g in groups} == expected, 'Group coverage differs')
    identities = {}
    for group in groups:
        n = group['requests']
        require(n == 192 and len(group['samples']) == n, 'Request count differs')
        require([r['request'] for r in group['samples']] == list(range(n)), 'Request IDs differ')
        require(group['order'] == list(VARIANTS[group['repeat']-1:] + VARIANTS[:group['repeat']-1]), 'Variant order differs')
        elapsed = group['elapsed_s']
        require(math.isfinite(elapsed) and elapsed > 0, 'Invalid group elapsed time')
        for sample in group['samples']:
            require(math.isfinite(sample['ms']) and sample['ms'] > 0, 'Invalid request latency')
            require(sample['worker'] == sample['request'] % group['concurrency'], 'Worker assignment differs')
            require(type(sample['valid']) is bool, 'Invalid validity flag')
            if sample['valid']:
                require(sample['status'] == 200 and sample['bytes'] > 0 and not sample.get('error'), 'Invalid successful response')
                digest = sample['sha256']
                require(len(digest) == 64 and all(c in '0123456789abcdef' for c in digest), 'Invalid response digest')
                key = (group['variant'],sample['path'])
                identity = (sample['bytes'],digest)
                require(identities.setdefault(key,identity) == identity, 'Response identity changed under load')
        latency = sorted(s['ms'] for s in group['samples'])
        good = sum(s['valid'] for s in group['samples'])
        calculated = {'errors': n-good, 'error_rate':(n-good)/n, 'completed_rps':n/elapsed, 'valid_rps':good/elapsed,
                      'median_ms':statistics.median(latency), 'p95_ms':latency[math.ceil(.95*n)-1], 'p99_ms':latency[math.ceil(.99*n)-1]}
        for field,value in calculated.items():
            require(group[field] == value, 'Summary differs from raw requests: '+field)
    return capacity


def render(raw_file):
    raw = gzip.decompress(raw_file.read_bytes())
    evidence = json.loads(raw)
    capacity = validate(evidence)
    ci = evidence['ci']
    environment = evidence['http']['environment']
    lines = ['# Concurrent WordPress / MoonPress capacity — 2026-10-22', '',
             f"Measured [CI run](https://github.com/{ci['GITHUB_REPOSITORY']}/actions/runs/{ci['GITHUB_RUN_ID']}); 1,000 synthetic articles, warm caches, shared NGINX (2 workers), PHP-FPM (4 children), MySQL for dynamic WordPress.", '',
             'Each cell is the median of three measured groups; each group contains 192 full-response requests. p95/p99 cells are medians of group quantiles, not pooled quantiles. Errors are totals across the three groups.', '',
             '| Concurrent | Variant | Valid req/s | Full response p95 ms | p99 ms | Errors / 576 |',
             '| --- | --- | --- | --- | --- | --- |']
    for concurrency in (1,8,32):
        for variant in VARIANTS:
            groups = [g for g in capacity['groups'] if g['concurrency'] == concurrency and g['variant'] == variant]
            values = [statistics.median(g[field] for g in groups) for field in ('valid_rps','p95_ms','p99_ms')]
            lines.append(f'| {concurrency} | {variant} | {values[0]:.1f} | {values[1]:.3f} | {values[2]:.3f} | {sum(g["errors"] for g in groups)} |')
    lines.extend(['', '## Conditions and limits', '',
        'Closed-loop HTTP/1.1 over loopback with a new connection per request, identity encoding, no TLS/CDN. The Python load generator shares the server host and can bottleneck. Rotated variant order, exact response-byte hashes, status/errors and every latency are retained. Static WordPress snapshots are the cache control. This does not establish maximum sustainable arrival rate, internet visitor capacity, or language-only superiority; there is no coordinated-omission correction or production soak.', '',
        f"Runtime: {capacity['nginx_version']}; {capacity['fpm_version']}; WordPress {evidence['http']['wordpress']['wordpress_version']}. FPM OPcache enabled, Xdebug active modes empty.",
        f"Host: {environment['cpu']}; {environment['logical_cpus']} visible CPUs; {environment['os']}.", '',
        'Per-group serving process CPU ticks and RSS snapshots are in the raw file. RSS includes shared pages, is not peak memory, and excludes the separate MySQL service. Do not compare it with native generation peak RSS.', '',
        'Security changes reduce exposed functionality and validate boundaries; this performance experiment is not a penetration test or proof of overall security superiority.', '',
        '## Provenance', '',
        f"- Measured source: `{environment['source_revision']}`; tree `{environment['source_tree']}`; clean worktree.",
        f"- Native executable SHA256: `{environment['executable_sha256']}`.",
        f"- Decompressed raw SHA256: `{hashlib.sha256(raw).hexdigest()}`.",
        f"- Evidence: `benchmarks/wordpress/results/{raw_file.name}`.", '',
        'Regenerate from repository root:', '', '```sh',
        f'python3 benchmarks/wordpress/capacity_report.py benchmarks/wordpress/results/{raw_file.name} docs/wordpress-capacity-2026-10-22.md', '```', ''])
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('raw', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    text = render(args.raw)  # Validate everything before opening destination.
    args.output.write_text(text, encoding='utf-8')
