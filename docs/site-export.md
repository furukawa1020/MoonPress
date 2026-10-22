# Public site ZIP format

The native `encode_site_zip` API writes deterministic ZIP stored entries (no
compression, encryption, symlinks, directories or ZIP64). Filenames are flat
UTF-8 with the ZIP language flag; timestamps are fixed at 1980-01-01. Entries
are sorted, CRC32-protected and limited to 10000 files and 64 MiB including
headers. Unsafe/duplicate names and hidden state are refused; `.nojekyll` is
allowed. The encoder does not read a project or decide what is publishable.

Format reference: [PKWARE APPNOTE 6.3.10](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT),
local headers, central directory and end-of-central-directory records. Native
unit vectors and independent `unzip` extraction verify compatibility. CRC32 and
SHA-256 digests are integrity checks, not signatures or deployment receipts.

`export_site(input, output, review_id)` requires an existing, current normal
production build and a fresh `review_build_plan` ID using the same path spelling.
It revalidates sources and the review under a shared output lock, reads regular
files through a retained no-follow directory handle, verifies every manifest
digest, and excludes `.moonpress.json`. It never builds or writes files.
Draft-inclusive output, pending changes, unknown files and manual edits fail.
The report includes archive SHA-256, byte count and included names.

Output reads are bounded before allocation: 4 MiB manifest, 64 MiB complete ZIP.
This is not a total compiler memory limit: source validation has its own costs.
The lock coordinates MoonPress operations, not hostile external writers, and a
review ID is neither a reservation nor authentication.

## CLI handoff

After a normal build, request a **fresh** review (the pre-build ID is stale):

```sh
moonpress review site dist --json
moonpress export site dist REVIEW_ID release.zip --json
```

Use the returned `report.review_id` and identical site/output path spellings.
The archive parent must already exist; `.zip` destinations must be new, visible
files outside both the source site tree and managed output, including directory
aliases. This prevents an archive from becoming an unsupported public asset or
otherwise changing compiler inputs. Existing files,
symlinks and directories are preserved. The writer uses an anonymous inode in
the retained destination directory. Data is flushed, fsynced and closed before
exclusive link publication, then the directory is fsynced. Pre-install errors or
process interruption leave no named partial ZIP. If the directory barrier fails
after installation, a complete ZIP remains visible with unconfirmed durability;
the command reports failure and does not delete it. No server upload or implicit
build occurs. Filesystems without O_TMPFILE support fail closed.

The local admin also serves `POST /export-production` with exactly the current
form token and `review_id`, through the existing same-origin form parser. It
returns a fixed `moonpress-site.zip` attachment, `no-store`, restrictive CSP and
an `X-MoonPress-SHA256` header. No archive is saved on the server. A stale review
returns an HTML error with links to recheck readiness and review production.

## Verification and recovery

The regression suite independently extracts archives with Info-ZIP, compares
public files with a clean build and follows the browser create/edit/preview/
ready/build/download journey. It exercises stale reviews, manual edits,
unknown/missing files, symlinks, FIFOs and oversize manifest/output refusal.
Injected write, flush, sync, close and install failures verify absent final names
and stream closure. Directory replacement at open/lock/create boundaries verifies
that writes remain attached to the retained destination, not a substituted path.

After interruption, an existing final ZIP must be complete, but a reported failed
directory barrier does not prove durability. Inspect and retain it; use a new
filename for a fresh verified export. Successful ZIP
creation does not replace the host's deployment/removal procedure. Review and
build again after changing saved sources; unsaved editor text is never included.

The ZIP attachment's CSP uses `sandbox allow-downloads`: download navigation is
permitted while scripts/forms remain disabled. See the
[MDN sandbox policy reference](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/sandbox).
HTTP regression asserts this exact policy. Cross-browser download/visual testing
remains a release gate; HTTP tests alone do not establish browser usability.

Source path identity follows the compiler's existing policy: ancestor aliases
are accepted, but the final source root must be a real directory. This is a
read-only identity lookup for source-tree exclusion. Destination/output handles
still reject symlink ancestors. Review IDs continue to bind exact path spelling.

Before archive creation, the writer reopens the source identity after taking the
retained destination lock and rejects observed identity/ancestry changes. A
retargeted source ancestor is therefore refused before mutation. This is an
observed-state recheck, not a transaction against arbitrary external writers.
