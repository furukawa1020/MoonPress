# Versioned media replacement

`read_media(site, name)` reads one existing regular file in `public/` and returns
its source name, encoded article URL, byte count, SHA-256 digest and extension
classification as a `MediaItem`. It reads binary bytes without decoding them and
writes nothing. It does not require valid articles or a successful site build.

Use an exact flat asset filename, for example `月 &a.PNG`, not a URL or source
path. Missing files, reserved compiler filenames, symlinks and special files are
rejected. Media reads walk directory components with no-follow opens, anchor
public/ and the asset to directory descriptors, and validate the opened descriptor
as a regular file. Symlinked ancestors in the supplied site path are also refused;
use the real directory path. Reading one item does not validate all other public files or the site.
Classification by extension does not validate an image or sanitize its content.

## Replacement API

`replace_media(site, name, expected_digest, bytes)` replaces an existing asset at
the same filename. `replace_media_from_file(site, name, expected_digest, path)`
reads replacement bytes from a regular local file. The report contains the new
`item`, `previous_digest` and `changed`. Expected digests must be lowercase
SHA-256 values from the asset you reviewed. A stale or invalid version fails.

The operation locks the public directory cooperatively, rereads the asset under
that lock, stages all new bytes exclusively in `public/.moonpress-media-edit`,
copies ordinary permission bits, verifies that the closed staging path is still a
regular file with the exact requested bytes, and rechecks the asset digest before
renaming. Observed staging edits, substitutions and missing paths are refused;
unverifiable remnants are retained for inspection rather than removed.
Identical bytes return unchanged without replacing the inode or modifying mtime.
An occupied staging path is refused, including on no-op attempts. Import/upload
remain create-only operations; replacement never creates a missing target.

Caught preparation or rename errors preserve the old target and attempt to
remove only the staging file this call created. Cleanup failures are explicit.
Interruption may leave a staging remnant; it is not silently removed on retry.
Keep the remnant for inspection and use a fresh copy of the site if uncertain.
This is not a media undo history, crash-recovery journal or power-loss guarantee.

Noncooperating editors do not share the lock. Changes observed at the staging/target checks are refused; an external writer
can still change either path after its final check. These are observed-state
checks, not an atomic inode-bound publication guarantee against arbitrary
same-user filesystem mutation.
The digest checks bytes, not inode identity, timestamps or permission history.
There is no whole-site transaction or lock across builds and source changes.

Replacement does not modify article links, validate image contents, recompile
the site, change existing generated output or deploy. Inspect references and
review a subsequent build separately. External browser/CDN caches may still
retain bytes at the unchanged URL.

## CLI

```sh
moonpress media-read my-site photo.png --json
moonpress media-replace my-site photo.png <expected-digest> /path/to/new-photo.png --json
```

Use the digest returned by the read command after reviewing the asset.
Both commands accept `--json` once, after all positional arguments; neither
accepts `--include-drafts` because public assets have no draft status.
JSON uses the schema-1 command envelope. Text output quotes names.
Exit 0 is success, 1 is validation/I/O failure and 2 is an argument error.
Failures write stderr with empty stdout. No binary contents are printed.

The replacement file's filename does not rename the destination. The URL and
extension classification stay those of the existing asset. Keep a backup if
you need to undo the change.

## Tested failure boundaries

The native integration suite injects stage open/write/flush/close failures,
rename failures, partial-write cleanup failure and stage read failures. It also
creates a competing stage at exclusive open, changes the target after lock or
during staging, runs competing cooperative replacements, and sends SIGKILL
immediately before rename. Tests verify original bytes/metadata where unchanged,
retained foreign or unverifiable staging, explicit retry refusal, correct
reported digests and unchanged replacement input files.

These are process/fault tests, not power-loss durability tests. A refused
staging remnant is intentionally visible rather than silently discarded.
Normal successful replacements are checked against fresh versus incremental
build output. The operation never deletes an asset; reference counts remain
inspection evidence, not permission to delete files.

Guarded reads prevent following substituted symlinks; they do not freeze file
contents against in-place external writes or make replacement publication atomic
with directory renames. Source/root selection remains a trusted local operation.
The guard is used for single-media snapshots and replacement target/stage checks;
it does not change all compiler or inventory filesystem reads. Tests inject
asset/public-directory substitutions at open and verify descriptor cleanup on
stream-construction failure.
