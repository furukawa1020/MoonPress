# WordPress / MoonPress measured comparison — 2026-10-22

Actual [GitHub Actions run](https://github.com/furukawa1020/MoonPress/actions/runs/39734311831); synthetic content only. All imported dynamic articles and native article text passed heading/paragraph equality checks before sampling.

## Warm article HTTP response

| Articles | WordPress dynamic median / p95 ms | WordPress cached HTML median / p95 ms | MoonPress static median / p95 ms |
| --- | --- | --- | --- |
| 10 | 9.9119 / 10.8922 | 0.2302 / 0.4017 | 0.2899 / 0.3892 |
| 100 | 9.5603 / 11.0152 | 0.2078 / 0.3641 | 0.2543 / 0.3825 |
| 1000 | 10.2772 / 10.7388 | 0.2211 / 0.4079 | 0.3161 / 0.4059 |

For 1,000 articles, MoonPress static response time was 1/32.51 of dynamic WordPress in this run (10.2772 vs 0.3161 ms). Cached WordPress was 0.2211 ms: MoonPress was **not faster than the static WordPress control** (MoonPress/cache median ratio 1.43). Both static variants have overlapping sub-millisecond tails. This supports a static-versus-dynamic serving observation, not a MoonBit-versus-PHP language speed claim.

60 samples per variant per corpus, five warmups for each of three representative articles, all six request orders counterbalanced equally. Serial loopback HTTP, fresh connections, identity encoding, warm OS/DB caches, no CDN or TLS. The same PHP built-in server executable serves both static controls; another instance runs WordPress. OPcache is verified enabled, and Xdebug reports no active modes. No page-cache plugin or persistent object cache. Cached WordPress means captured HTML responses, not a specific plugin. Header-availability timings and body byte/hash records are in the raw evidence.

## Native generation

| Articles | Scenario | Median / p95 ms | Median peak RSS KiB |
| --- | --- | --- | --- |
| 10 | clean | 12.434 / 24.807 | 4008 |
| 10 | noop | 2.886 / 2.979 | 3688 |
| 10 | one-edit | 7.086 / 145.112 | 4200 |
| 100 | clean | 64.195 / 84.842 | 5992 |
| 100 | noop | 11.072 / 17.970 | 5152 |
| 100 | one-edit | 17.424 / 33.201 | 6576 |
| 1000 | clean | 579.173 / 1594.470 | 20084 |
| 1000 | noop | 89.631 / 91.613 | 15664 |
| 1000 | one-edit | 118.989 / 125.690 | 21420 |

5 runs per scenario; full subprocess time including native startup and small C wait4 wrapper. Publication fsyncs are enabled. No-op writes zero artifacts; a body-only edit writes exactly one article. Every edited incremental output was byte-compared with a clean build. These are generation timings, not WordPress publishing/import timings. Native peak RSS is measured by the C child wrapper so Python pre-exec memory is excluded.

## Serving memory snapshots

| Articles | WordPress PHP RSS KiB | Shared static PHP RSS KiB | MySQL service RSS KiB |
| --- | --- | --- | --- |
| 10 | 77692 | 50396 | 415864 |
| 100 | 77880 | 50640 | 418488 |
| 1000 | 77952 | 50504 | 421992 |

These are post-workload resident-memory snapshots, not peaks or allocations per request. MySQL is reported separately. Do not compare these directly with native generation peak RSS: they are different workloads and lifetimes.

## Provenance and reproduction

- WordPress 7.1.3; PHP 8.3.6; MySQL 8.0.46-0ubuntu0.24.04.4; no plugins; minimal benchmark theme.
- Runner: Linux-7.0.0-1017-azure-x86_64-with-glibc2.39; AMD EPYC 9V45 96-Core Processor; 4 visible logical CPUs.
- MoonBit: `v0.10.14+7d59c7ec9 (2026-09-18)`.
- Measured clean source: [`a6627bd5ec5580c055f11d7e5bd0eaa918bfc7da`](https://github.com/furukawa1020/MoonPress/commit/a6627bd5ec5580c055f11d7e5bd0eaa918bfc7da); tree `7f221f5a901b90750dc2e2738f920a3ee3638a6b`.
- Native executable: 3294256 bytes; SHA-256 `400fc4dfcb34197d49026c2df81b437f1ec649aebb135d19348c10fdef5e80f5`.
- Official WordPress archive SHA-256: `d2a09acb6a15e3b9c471d72557753c266d6f41a79ed19bfe04cbfe49e283b2a5`; official SHA-1 checked over HTTPS.
- [Complete raw gzip JSON](../benchmarks/wordpress/results/2026-10-22.json.gz); decompressed SHA-256 `a2a8bd3e32965e07a2009f0f72fdb3363989b8b23a12d57f310ecfd601406ad9`.

From the repository root:

```sh
python3 benchmarks/wordpress/report.py benchmarks/wordpress/results/2026-10-22.json.gz /tmp/wordpress-report.md --date 2026-10-22
```

The report generator recomputes medians/p95 and checks balanced orders, runtime settings, executable/source identity and corpus hashes. The workflow and raw evidence retain individual samples, actual work counts, fixture/source hashes, memory data and environment versions. A later source revision can reproduce the workload, but fresh timings will vary.

This experiment does not measure production throughput, concurrent traffic, cold caches, a full WordPress theme/plugin stack, admin workflows or complete CMS capability parity. See [feature coverage](wordpress-parity.md) and [benchmark method](../benchmarks/wordpress/README.md).
