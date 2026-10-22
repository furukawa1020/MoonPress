# Concurrent WordPress / MoonPress capacity — 2026-10-22

Measured [CI run](https://github.com/furukawa1020/MoonPress/actions/runs/39742372033); 1,000 synthetic articles, warm caches, shared NGINX (2 workers), PHP-FPM (4 children), MySQL for dynamic WordPress.

Each cell is the median of three measured groups; each group contains 192 full-response requests. p95/p99 cells are medians of group quantiles, not pooled quantiles. Errors are totals across the three groups.

| Concurrent | Variant | Valid req/s | Full response p95 ms | p99 ms | Errors / 576 |
| --- | --- | --- | --- | --- | --- |
| 1 | wordpress-dynamic | 68.7 | 15.699 | 16.525 | 0 |
| 1 | wordpress-cached-html | 3345.1 | 0.335 | 0.343 | 0 |
| 1 | moonpress-static | 3951.7 | 0.285 | 0.339 | 0 |
| 8 | wordpress-dynamic | 176.0 | 51.095 | 54.136 | 0 |
| 8 | wordpress-cached-html | 3060.9 | 4.222 | 5.319 | 0 |
| 8 | moonpress-static | 3068.8 | 4.200 | 5.099 | 0 |
| 32 | wordpress-dynamic | 171.2 | 200.725 | 205.048 | 0 |
| 32 | wordpress-cached-html | 2942.0 | 11.771 | 16.615 | 0 |
| 32 | moonpress-static | 2936.8 | 10.932 | 14.653 | 0 |

## Conditions and limits

Closed-loop HTTP/1.1 over loopback with a new connection per request, identity encoding, no TLS/CDN. The Python load generator shares the server host and can bottleneck. Rotated variant order, exact response-byte hashes, status/errors and every latency are retained. Static WordPress snapshots are the cache control. This does not establish maximum sustainable arrival rate, internet visitor capacity, or language-only superiority; there is no coordinated-omission correction or production soak.

Runtime: nginx version: nginx/1.24.0 (Ubuntu); PHP 8.3.6 (fpm-fcgi) (built: Oct 19 2026 15:16:58); WordPress 7.1.3. FPM OPcache enabled, Xdebug active modes empty.
Host: AMD EPYC 7763 64-Core Processor; 4 visible CPUs; Linux-6.17.0-1022-azure-x86_64-with-glibc2.39.

Per-group serving process CPU ticks and RSS snapshots are in the raw file. RSS includes shared pages, is not peak memory, and excludes the separate MySQL service. Do not compare it with native generation peak RSS.

Security changes reduce exposed functionality and validate boundaries; this performance experiment is not a penetration test or proof of overall security superiority.

## Provenance

- Measured source: `c1cb6d44af17ce26c0e1b673b7f6657c5d513668`; tree `f94152bffe1161450286579ada1905dd26da3c06`; clean worktree.
- Native executable SHA256: `b27647c963d248e2b6465f31f7d4b88e1af7ba4d26467cf3ad7b994224b7fe2b`.
- Decompressed raw SHA256: `a9c9f4af0fc704465fd93808ef3b4ee056910392f49abf284c2a4fc9b6d37d37`.
- Evidence: `benchmarks/wordpress/results/2026-10-22-capacity.json.gz`.

Regenerate from repository root:

```sh
python3 benchmarks/wordpress/capacity_report.py benchmarks/wordpress/results/2026-10-22-capacity.json.gz docs/wordpress-capacity-2026-10-22.md
```
