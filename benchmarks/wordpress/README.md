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
and 60 interleaved serial samples per variant. WordPress cached HTML means an
actual captured response served statically, not a named cache plugin. Native and
cached HTML use the same static PHP server; dynamic WordPress uses another
instance of the same executable, with OPcache enabled and Xdebug disabled for both. A live PHP probe verifies
the settings. All six request orders are counterbalanced equally; each raw
sample records its order.
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

Actual October 22, 2026 results and complete raw records: [measured comparison](../../docs/wordpress-benchmark-2026-10-22.md). The cached WordPress control is explicitly retained even when it has a lower median than MoonPress.

Concurrent capacity is also measured with NGINX (two workers), a dedicated
PHP-FPM pool (four children), and the same 1,000-article corpus. Static WordPress
snapshots and MoonPress output share the exact NGINX process. Dynamic WordPress
uses that process plus FPM/MySQL. No page/object cache plugin is installed.
The harness uses 192 requests per group at concurrency 1, 8 and 32, three rounds
rotating variant order. It records every status, response hash, byte count and
full-response latency, plus valid/completed throughput, p95/p99 and error rate.
Connections are new for each request, caches are warm, transport is loopback
without compression/TLS. The Python client shares the host and can bottleneck.
This is a bounded closed-loop experiment: it does not measure maximum sustainable
production arrival rate, correct coordinated omission, or establish DDoS capacity.
Version/configuration, FPM runtime OPcache/Xdebug checks, raw groups and requests
are retained in the same compressed evidence as serial/build measurements.
`python3 scripts/capacity-test.py` validates accounting against an actual HTTP
fixture including wrong hashes and HTTP failures.
Each load group also records `/proc` RSS and user/system CPU tick snapshots for
NGINX/FPM and their descendants before/after measurement. Tick frequency is
recorded. RSS can double-count shared pages, is not peak memory, and excludes
the separate MySQL service; it must not be compared with native generation peak.

Published concurrent evidence: [2026-10-22 report](../../docs/wordpress-capacity-2026-10-22.md), including raw records and deterministic regeneration.


Comment compatibility oracle: `comment-oracle.php` calls the real core REST controller;
`comment-oracle.py` compares 27 independently seeded query cases with native HTTP.
It maps fixture IDs, checks parent/post relationships, rendered text and total headers,
and compares authenticated reply creation with core configured to hold all comments.
The comparison includes offset=0/page precedence, empty high pages and include order
in both directions. It is not a claim of complete WordPress compatibility.

MoonPress comment policy: generated credentials are required for creation, every new
comment is held for moderation, article and approved ancestor visibility constrain
public reads, and replies allow at most eight ancestors. Content is bounded plain
text (HTML is escaped literally), with string or `{ "raw": "text" } input on the
WordPress-shaped collection. Public view/embed and authenticated creation responses
are supported; WordPress edit reads, item writes, anonymous comments, rich HTML intake,
author impersonation, email/IP/URL metadata, pingbacks and trackbacks remain unsupported.
A pending creation Location identifies the resource but public GET stays 404 until
approval; the native edit Location is available only to the owner or moderator.

The core oracle compares multiline plain raw creation. Paragraph/break normalization has separate native HTTP regressions. Core rejects comment orderby=author_name: native retains that ordering, while the WordPress-shaped route supports parent/post/include and rejects author_name.


`comment-management-oracle.php` / `.py` compare actual core edit authority and
responses across five roles plus anonymous requests, four post/page ownership
and draft/publish fixtures, 48 detail read/write probes, six private collections,
eight update/trash/restore transitions and two type orders. The fixture provides
registered users with valid disposable email values. Native fixture identities
are explicitly mapped; only supported public author/raw/status/content fields
are compared, never copied private metadata. Native If-Match, immutable identity,
hold-only restoration and ordinary approved-only reads are documented extensions.


The media oracle seeds three disposable attachment records and original files in
actual core, then compares 35 collection queries and six view/embed details with
native public files. Queries cover MIME/type unions, ID/include/slug mapping,
selection, title/request ordering, counts and offset/page edge cases. Identity and
source URL namespaces are compared explicitly rather than pretending to share a
WordPress database. No attachment dates/owners/image derivatives are inferred.
The oracle runs after measured experiments, only inside the existing disposable
GitHub-hosted runner guard.
