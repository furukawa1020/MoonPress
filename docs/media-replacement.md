# Versioned media replacement

`read_media(site, name)` reads one existing regular file in `public/` and returns
its source name, encoded article URL, byte count, SHA-256 digest and extension
classification as a `MediaItem`. It reads binary bytes without decoding them and
writes nothing. It does not require valid articles or a successful site build.

Use an exact flat asset filename, for example `月 &a.PNG`, not a URL or source
path. Missing files, reserved compiler filenames, symlinks and special files are
rejected. Reading one item does not validate all other public files or the site.
Classification by extension does not validate an image or sanitize its content.

## Replacement API

`replace_media(site, name, expected_digest, bytes)` replaces an existing asset at
the same filename. `replace_media_from_file(site, name, expected_digest, path)`
reads replacement bytes from a regular local file. The report contains the new
`item`, `previous_digest` and `changed`. Expected digests must be lowercase
SHA-256 values from the asset you reviewed. A stale or invalid version fails.

The operation locks the public directory cooperatively, rereads the asset under
that lock, stages all new bytes exclusively in `public/.moonpress-media-edit`,
copies ordinary permission bits, and rechecks the asset digest before renaming.
Identical bytes return unchanged without replacing the inode or modifying mtime.
An occupied staging path is refused, including on no-op attempts. Import/upload
remain create-only operations; replacement never creates a missing target.

Caught preparation or rename errors preserve the old target and attempt to
remove only the staging file this call created. Cleanup failures are explicit.
Interruption may leave a staging remnant; it is not silently removed on retry.
Keep the remnant for inspection and use a fresh copy of the site if uncertain.
This is not a media undo history, crash-recovery journal or power-loss guarantee.

Noncooperating editors do not share the lock. Changes observed at the final
digest check are preserved; an external writer can still race after that check.
The digest checks bytes, not inode identity, timestamps or permission history.
There is no whole-site transaction or lock across builds and source changes.

Replacement does not modify article links, validate image contents, recompile
the site, change existing generated output or deploy. Inspect references and
review a subsequent build separately. External browser/CDN caches may still
retain bytes at the unchanged URL.
