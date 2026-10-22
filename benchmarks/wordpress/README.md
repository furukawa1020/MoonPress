# Shared WordPress comparison

`python3 benchmarks/wordpress/fixture.py NEW_DIRECTORY 10` creates synthetic article JSON and native Markdown from one canonical source. Sizes are 10, 100 and 1000. The manifest hashes corpus bytes and all native inputs. Heading/paragraph equality is checked from rendered HTML, including escaping and Unicode; fixture creation refuses an existing destination. No personal articles or private history/trash records are used.

See [measurement boundaries](../../docs/wordpress-parity.md#measurement-contract). Native generation and HTTP serving are separate workloads; cached WordPress HTML is a required static control.

`python3 benchmarks/wordpress/native.py NEW_RESULT.json` measures five repeated
clean/no-op/one-body-edit builds of each shared corpus. It records raw elapsed
milliseconds, Linux wait4 process peak RSS, hashes, compiler/host provenance and
actual work counts. Every incremental edited output is compared byte-for-byte
against a clean build. A body-only edit must write one page; no-op writes zero.
This measures native generation, not HTTP response latency or WordPress import.
