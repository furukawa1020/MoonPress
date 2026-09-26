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
