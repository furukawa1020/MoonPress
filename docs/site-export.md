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
