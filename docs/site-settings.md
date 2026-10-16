# Versioned site settings

`read_site_settings(site)` reads the fixed `site.json` file without changing it.
The snapshot contains `exists`, raw UTF-8 `content` and optional SHA-256
`digest`. An absent file has `exists=false`, `digest=null` and suggested
editor text `{}\n`; this text is not an on-disk file. An existing empty or
malformed JSON file remains readable so it can be repaired. Invalid UTF-8 is
rejected rather than silently replaced.

Existing files are read through no-follow directory/file descriptors and checked
as regular files. Symlinks and special files are rejected. Use real site paths,
not symlinked ancestors. A read is an observed snapshot, not a reservation or an
atomic freeze against in-place edits. No article, layout, route or hosting
validation is implied.
