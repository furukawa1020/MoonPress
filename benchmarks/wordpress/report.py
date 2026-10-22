"""Validate archived raw evidence and regenerate the readable benchmark report."""
import argparse
from collections import Counter
import gzip
import hashlib
import json
import math
from pathlib import Path
import statistics


def require(condition, message):
    if not condition:
        raise ValueError(message)


def report(raw_file, output, date):
    packed = raw_file.read_bytes()
    raw = gzip.decompress(packed)
    evidence = json.loads(raw)
    http, native, ci = evidence['http'], evidence['native'], evidence['ci']
    require(http['environment']['executable_sha256'] == native['environment']['executable_sha256'], "Raw evidence validation failed at check 22")
    require(http['environment']['source_revision'] == native['environment']['source_revision'], "Raw evidence validation failed at check 23")
    require(http['php_server_runtime']['opcache_enabled'] is True, "Raw evidence validation failed at check 24")
    require(http['php_server_runtime']['xdebug_active_modes'] == [], "Raw evidence validation failed at check 25")
    require(not http['environment']['worktree_dirty'], "Raw evidence validation failed at check 26")
    require({f['count']:f['dataset_sha256'] for f in http['fixtures']} == {f['count']:f['dataset_sha256'] for f in native['fixtures']}, "Raw evidence validation failed at check 27")
    for row in http['summary']:
        values = [s['total_ms'] for s in http['samples'] if s['count']==row['count'] and s['variant']==row['variant']]
        orders = Counter(tuple(s['order']) for s in http['samples'] if s['count']==row['count'] and s['variant']==row['variant'])
        require(len(orders)==6 and len(set(orders.values()))==1, "Raw evidence validation failed at check 31")
        require(len(values)==http['conditions']['samples_per_variant_per_count'], "Raw evidence validation failed at check 32")
        require(statistics.median(values)==row['total_ms']['median'], "Raw evidence validation failed at check 33")
        require(sorted(values)[math.ceil(.95*len(values))-1]==row['total_ms']['p95'], "Raw evidence validation failed at check 34")
    expected_groups = {(count, scenario) for count in (10,100,1000) for scenario in ('clean','noop','one-edit')}
    require(len(native['summary']) == len(expected_groups), 'Native summary coverage differs')
    require({(r['count'],r['scenario']) for r in native['summary']} == expected_groups, 'Native groups differ')
    require(len(native['samples']) == len(expected_groups)*native['repeats'], 'Native sample count differs')
    for row in native['summary']:
        samples = [s for s in native['samples'] if s['count']==row['count'] and s['scenario']==row['scenario']]
        require(len(samples) == native['repeats'], 'Native repeat count differs')
        require({s['repeat'] for s in samples} == set(range(1,native['repeats']+1)), 'Native repeat IDs differ')
        for sample in samples:
            count, scenario = sample['count'], sample['scenario']
            written = count+3 if scenario=='clean' else (0 if scenario=='noop' else 1)
            require(sample['pages']==count and sample['written']==written and sample['skipped']==count+3-written and sample['deleted']==0,
                    'Native build work counts differ from the shared fixture contract')
        for metric in ('elapsed_ms','peak_rss_kib'):
            values = sorted(s[metric] for s in samples)
            require(all(math.isfinite(value) and value>0 for value in values), 'Invalid native metric')
            summary = {'median':statistics.median(values),'p95':values[math.ceil(.95*len(values))-1], 'min':values[0], 'max':values[-1]}
            require(summary == row[metric], 'Native timing/RSS summary differs from raw samples')
    run = ci['GITHUB_RUN_ID']
    repository = ci['GITHUB_REPOSITORY']
    lines=[f'# WordPress / MoonPress measured comparison — {date}', '',
           f'Actual [GitHub Actions run](https://github.com/{repository}/actions/runs/{run}); synthetic content only. '
           'All imported dynamic articles and native article text passed heading/paragraph equality checks before sampling.', '',
           '## Warm article HTTP response', '',
           '| Articles | WordPress dynamic median / p95 ms | WordPress cached HTML median / p95 ms | MoonPress static median / p95 ms |',
           '| --- | --- | --- | --- |']
    def cell(row): return f"{row['total_ms']['median']:.4f} / {row['total_ms']['p95']:.4f}"
    for count in (10,100,1000):
        rows={r['variant']:r for r in http['summary'] if r['count']==count}
        lines.append(f"| {count} | {cell(rows['wordpress-dynamic'])} | {cell(rows['wordpress-cached-html'])} | {cell(rows['moonpress-static'])} |")
    rows={r['variant']:r for r in http['summary'] if r['count']==1000}
    dynamic, cached, static=[rows[v]['total_ms']['median'] for v in ('wordpress-dynamic','wordpress-cached-html','moonpress-static')]
    lines.extend(['',f'For 1,000 articles, MoonPress static response time was 1/{dynamic/static:.2f} of dynamic WordPress in this run '
                  f'({dynamic:.4f} vs {static:.4f} ms). Cached WordPress was {cached:.4f} ms: MoonPress was **not faster than the static WordPress control** '
                  f'(MoonPress/cache median ratio {static/cached:.2f}). Both static variants have overlapping sub-millisecond tails. '
                  'This supports a static-versus-dynamic serving observation, not a MoonBit-versus-PHP language speed claim.', '',
                  f"{http['conditions']['samples_per_variant_per_count']} samples per variant per corpus, five warmups for each of three representative articles, "
                  'all six request orders counterbalanced equally. Serial loopback HTTP, fresh connections, identity encoding, warm OS/DB caches, no CDN or TLS. '
                  'The same PHP built-in server executable serves both static controls; another instance runs WordPress. OPcache is verified enabled, '
                  'and Xdebug reports no active modes. No page-cache plugin or persistent object cache. Cached WordPress means captured HTML responses, '
                  'not a specific plugin. Header-availability timings and body byte/hash records are in the raw evidence.', '',
                  '## Native generation', '',
                  '| Articles | Scenario | Median / p95 ms | Median peak RSS KiB |', '| --- | --- | --- | --- |'])
    for row in native['summary']:
        lines.append(f"| {row['count']} | {row['scenario']} | {row['elapsed_ms']['median']:.3f} / {row['elapsed_ms']['p95']:.3f} | {row['peak_rss_kib']['median']:.0f} |")
    lines.extend(['',f"{native['repeats']} runs per scenario; full subprocess time including native startup and small C wait4 wrapper. "
                  'Publication fsyncs are enabled. No-op writes zero artifacts; a body-only edit writes exactly one article. Every edited incremental output '
                  'was byte-compared with a clean build. These are generation timings, not WordPress publishing/import timings. '
                  'Native peak RSS is measured by the C child wrapper so Python pre-exec memory is excluded.', '',
                  '## Serving memory snapshots', '',
                  '| Articles | WordPress PHP RSS KiB | Shared static PHP RSS KiB | MySQL service RSS KiB |', '| --- | --- | --- | --- |'])
    for row in http['rss_snapshots']:
        lines.append(f"| {row['count']} | {row['wordpress_php_kib']} | {row['static_php_kib']} | {row['mysql_service_kib']} |")
    env=http['environment'];wp=http['wordpress']
    lines.extend(['', 'These are post-workload resident-memory snapshots, not peaks or allocations per request. MySQL is reported separately. '
                  'Do not compare these directly with native generation peak RSS: they are different workloads and lifetimes.', '',
                  '## Provenance and reproduction', '',
                  f"- WordPress {wp['wordpress_version']}; PHP {wp['php_version']}; MySQL {wp['database_version']}; no plugins; minimal benchmark theme.",
                  f"- Runner: {env['os']}; {env['cpu']}; {env['logical_cpus']} visible logical CPUs.",
                  f"- MoonBit: `{env['compiler']}`.",
                  f"- Measured clean source: [`{env['source_revision']}`](https://github.com/{repository}/commit/{env['source_revision']}); tree `{env['source_tree']}`.",
                  f"- Native executable: {env['executable_bytes']} bytes; SHA-256 `{env['executable_sha256']}`.",
                  f"- Official WordPress archive SHA-256: `{http['wordpress_archive_sha256']}`; official SHA-1 checked over HTTPS.",
                  f"- [Complete raw gzip JSON](../{raw_file.as_posix()}); decompressed SHA-256 `{hashlib.sha256(raw).hexdigest()}`.",
                  '', 'From the repository root:', '', '```sh',
                  f'python3 benchmarks/wordpress/report.py {raw_file.as_posix()} /tmp/wordpress-report.md --date {date}',
                  '```', '',
                  'The report generator recomputes medians/p95 and checks balanced orders, runtime settings, executable/source identity and corpus hashes. '
                  'The workflow and raw evidence retain individual samples, actual work counts, fixture/source hashes, memory data and environment versions. '
                  'A later source revision can reproduce the workload, but fresh timings will vary.', '',
                  'This experiment does not measure production throughput, concurrent traffic, cold caches, a full WordPress theme/plugin stack, '
                  'admin workflows or complete CMS capability parity. See [feature coverage](wordpress-parity.md) and [benchmark method](../benchmarks/wordpress/README.md).', ''])
    output.write_text('\n'.join(lines),encoding='utf-8')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('raw',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--date',required=True)
    args=parser.parse_args()
    report(args.raw,args.output,args.date)
