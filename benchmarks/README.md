# Reproduce the measurements

```sh
bash scripts/check.sh
REPEATS=5 bash scripts/benchmark.sh bench-results
```

The report directory must be new. `raw.csv` keeps each process measurement;
`report.md` records environment, versions, binary/gzip size and mean/min/max.
Datasets contain 10, 100, 1000 tiny Markdown pages, shared layout and CSS.
Scenarios: process startup, fresh output, unchanged rebuild, one-page edit.
Bash timing includes process startup and invocation overhead. OS caches are
not flushed. Interpret results as warm-cache synthetic workloads, not a
promise about larger real-world sites or superiority to another compiler.
The shell-only Benchmark workflow runs manually and puts results in the job
summary/log. No npm, Node, JavaScript Actions, or TS are used.

The checked-in baseline is one local measurement, not a performance gate.

## Shared Markdown analysis

[Comparison report](analysis-reuse-linux-x86_64/report.md) and
[raw samples](analysis-reuse-linux-x86_64/raw.csv) record the #69 change on
100 pages with 24 sections each. `scripts/compare-analysis.sh` alternates two
native executables across five repetitions and checks output/JSON byte equality.
The report identifies both source revisions, executable hashes and toolchain.

On that host/fixture, mean check/clean/no-op wall time decreased by about 27–30%.
The native executable increased by 5,000 bytes (979,840 to 984,840). This is a
scoped CPU-work tradeoff, not a memory reduction claim or a general speed guarantee.
Frontmatter/title discovery still parses separately; public standalone helpers
retain their original semantics and site planning reuses its own block model.
