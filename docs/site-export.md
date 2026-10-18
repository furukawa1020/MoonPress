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
