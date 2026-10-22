"""Repeated native generation timings and Linux wait4 peak RSS on shared corpora."""
import argparse
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile
import time
from fixture import generate, sha256

ROOT = Path(__file__).resolve().parents[2]


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def environment(cli):
    cpu = next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text(encoding="utf-8").splitlines() if line.startswith('model name')), 'unknown')
    return {'source_revision': command('git', 'rev-parse', 'HEAD'),
            'source_tree': command('git', 'rev-parse', 'HEAD^{tree}'),
            'worktree_dirty': bool(command('git', 'status', '--porcelain')),
            'os': platform.platform(), 'cpu': cpu, 'logical_cpus': os.cpu_count(),
            'compiler': command('moonc', '-v'), 'moon': command('moon', 'version'),
            'executable_sha256': sha256(cli.read_bytes()), 'executable_bytes': cli.stat().st_size}


def measure(helper, cli, site, output, rss):
    start = time.perf_counter_ns()
    run = subprocess.run([str(helper), str(rss), str(cli), 'build', str(site), str(output), '--json'], capture_output=True, text=True, check=True)
    report_text = run.stdout
    elapsed = (time.perf_counter_ns() - start) / 1_000_000
    report = json.loads(report_text)['report']
    return {'elapsed_ms': elapsed, 'peak_rss_kib': int(rss.read_text(encoding="utf-8")),
            'pages': report['pages'], 'written': report['written'], 'skipped': report['skipped'], 'deleted': report['deleted']}


def summarize(values):
    ordered = sorted(values)
    import math
    return {'median': statistics.median(ordered), 'p95': ordered[max(0, math.ceil(.95 * len(ordered)) - 1)], 'min': ordered[0], 'max': ordered[-1]}


def native_benchmark(cli, repeats=5, counts=(10, 100, 1000)):
    cli = Path(cli).resolve()
    result = {'schema': 1, 'workload': 'native-generation', 'environment': environment(cli),
              'clock': 'perf_counter_ns; full subprocess including startup and small C wait4 wrapper',
              'memory': 'Linux wait4 peak RSS KiB per native subprocess', 'repeats': repeats,
              'cache': 'warm OS caches; no cache flush; serial; fsync publication enabled', 'fixtures': [], 'samples': []}
    with tempfile.TemporaryDirectory(prefix='moonpress-native-benchmark-') as directory:
        directory = Path(directory)
        helper = directory / 'measure'
        subprocess.run(['cc', '-O2', '-Wall', '-Wextra', str(Path(__file__).with_name('measure.c')), '-o', str(helper)], check=True)
        result['environment']['measurement_helper_sha256'] = sha256(helper.read_bytes())
        result['environment']['cc'] = command('cc', '--version').splitlines()[0]
        for count in counts:
            fixture = directory / str(count)
            result['fixtures'].append(generate(fixture, count))
            site = fixture / 'site'
            source = site / 'content/p-000001.md'
            original = source.read_bytes()
            for repetition in range(1, repeats + 1):
                output = fixture / f'out-{repetition}'
                for scenario in ('clean', 'noop', 'one-edit'):
                    if scenario == 'one-edit':
                        source.write_bytes(original + b'\nOne synthetic body edit.\n')
                    sample = measure(helper, cli, site, output, fixture / 'rss.txt')
                    sample.update(count=count, repeat=repetition, scenario=scenario)
                    if sample['pages'] != count or (scenario == 'noop' and sample['written'] != 0) or (scenario == 'one-edit' and sample['written'] != 1):
                        raise ValueError(f'Unexpected build work: {sample}')
                    result['samples'].append(sample)
                clean = fixture / f'verify-{repetition}'
                subprocess.run([str(cli), 'build', str(site), str(clean)], stdout=subprocess.DEVNULL, check=True)
                actual = {str(p.relative_to(output)): sha256(p.read_bytes()) for p in output.rglob('*') if p.is_file()}
                expected = {str(p.relative_to(clean)): sha256(p.read_bytes()) for p in clean.rglob('*') if p.is_file()}
                if actual != expected:
                    raise ValueError('Incremental output differs from clean build')
                source.write_bytes(original)
    result['summary'] = [{'count': count, 'scenario': scenario,
                          'elapsed_ms': summarize([s['elapsed_ms'] for s in result['samples'] if s['count'] == count and s['scenario'] == scenario]),
                          'peak_rss_kib': summarize([s['peak_rss_kib'] for s in result['samples'] if s['count'] == count and s['scenario'] == scenario])}
                         for count in counts for scenario in ('clean', 'noop', 'one-edit')]
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--cli', type=Path, default=ROOT / '_build/native/release/build/cmd/main/main.exe')
    parser.add_argument('--repeats', type=int, default=5)
    parser.add_argument('--counts', type=int, nargs='+', choices=[10, 100, 1000], default=[10, 100, 1000])
    args = parser.parse_args()
    if not 1 <= args.repeats <= 100:
        parser.error('repeats must be 1..100')
    with args.output.open('x') as file:
        json.dump(native_benchmark(args.cli, args.repeats, args.counts), file, indent=2, sort_keys=True)
        file.write('\n')
