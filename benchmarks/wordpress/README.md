# Shared WordPress comparison

`python3 benchmarks/wordpress/fixture.py NEW_DIRECTORY 10` creates synthetic article JSON and native Markdown from one canonical source. Sizes are 10, 100 and 1000. The manifest hashes corpus bytes and all native inputs. Heading/paragraph equality is checked from rendered HTML, including escaping and Unicode; fixture creation refuses an existing destination. No personal articles or private history/trash records are used.

See [measurement boundaries](../../docs/wordpress-parity.md#measurement-contract). Native generation and HTTP serving are separate workloads; cached WordPress HTML is a required static control.

`python3 benchmarks/wordpress/native.py NEW_RESULT.json` measures five repeated
clean/no-op/one-body-edit builds of each shared corpus. It records raw elapsed
milliseconds, Linux wait4 process peak RSS, hashes, compiler/host provenance and
actual work counts. Every incremental edited output is compared byte-for-byte
against a clean build. A body-only edit must write one page; no-op writes zero.
This measures native generation, not HTTP response latency or WordPress import.

The `WordPress comparable benchmark` workflow runs on a disposable Ubuntu runner.
It verifies WordPress 7.1.3's official archive SHA-1 over HTTPS and records its
SHA-256 and runtime version, creates an isolated synthetic database, and uses no
plugins or JavaScript. The minimal PHP theme returns only equivalent article
text. Every dynamic article and native output is validated before timing.

For each corpus, three representative articles receive five warmups per variant
and 50 interleaved serial samples per variant. WordPress cached HTML means an
actual captured response served statically, not a named cache plugin. Native and
cached HTML use the same static PHP server; dynamic WordPress uses another
instance of the same executable, with CLI opcache explicitly disabled for both.
Response header availability and complete-body clocks, bytes, hashes, PHP RSS
snapshots and separate MySQL-service RSS are retained. No production throughput,
concurrency, cold-cache or language-only conclusion is justified.

The native memory helper is a small C `fork`/`wait4` wrapper so Python's pre-exec
resident-memory floor is not attributed to the native executable. Its hash and
C compiler are recorded. Timing includes process startup and wrapper overhead.

Raw JSON is gzip/base64-encoded into the job log with an uncompressed SHA-256,
using only Python/shell and GitHub APIs rather than Node artifact actions. This
is synthetic public test data; no credentials are emitted. Decode the marker
`MOONPRESS_WORDPRESS_RAW_GZIP_BASE64` and verify `MOONPRESS_WORDPRESS_RAW_SHA256`.
