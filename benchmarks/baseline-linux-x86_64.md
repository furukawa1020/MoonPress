# MoonPress benchmark

- Measured UTC: 2026-09-26T20:43:43Z
- OS / architecture: Linux 6.18.44 x86_64
- CPU: AMD EPYC 9V74 80-Core Processor
- Revision: dd4618ef425407b336e1e3085c87e0d2ca28bc6a
- Moon: moon 0.1.20260920 (914d7da 2026-09-20)
- Moonc: v0.10.14+7d59c7ec9 (2026-09-18)
- Repetitions: 5
- Native executable: 772992 bytes
- gzip -n executable: 309690 bytes

| Pages | Scenario | Mean (ms) | Min (ms) | Max (ms) |
| ---: | --- | ---: | ---: | ---: |
| 0 | startup | 0.838 | 0.762 | 0.956 |
| 10 | clean | 1.815 | 1.566 | 2.067 |
| 10 | noop | 1.355 | 1.334 | 1.380 |
| 10 | one_page | 1.570 | 1.453 | 1.673 |
| 100 | clean | 6.360 | 6.065 | 7.050 |
| 100 | noop | 4.785 | 4.438 | 5.233 |
| 100 | one_page | 5.483 | 4.810 | 6.515 |
| 1000 | clean | 48.362 | 44.358 | 51.128 |
| 1000 | noop | 40.305 | 38.494 | 42.948 |
| 1000 | one_page | 40.919 | 40.002 | 42.514 |

Method: Bash EPOCHREALTIME around each native process. Includes process startup and shell invocation overhead. Microsecond units do not imply microsecond accuracy. Filesystem caches are NOT flushed. Clean means a fresh output directory, not a cold OS cache. Tiny synthetic pages; no assets beyond shared CSS. Edits append to one source page between repetitions. Incremental builds still hash inputs and verify every generated output. These numbers are host-specific, not a comparison with other SSGs. Native binary uses system runtime libraries; gzip bytes are not a packaged distribution size.
