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

## Save API

`save_site_settings(site, expected, content)` and
`save_site_settings_from_file(site, expected, replacement_path)` save exact
UTF-8 JSON text. Use the lowercase digest from the snapshot, or the literal
`absent` only when no file exists. Save validates the existing compiler settings
schema, including field types/ranges and the RSS base-URL requirement. It does
not resolve routes, load layouts, validate articles or build/deploy anything.
A valid settings file can still make the complete site fail validation.

The report has `digest`, `changed` and `created`. Identical existing bytes are
a no-op preserving inode/mtime. Valid replacement text can repair malformed
existing JSON because only the proposed content must parse successfully.

Writers cooperate through the site-directory lock. A fixed, exclusively created
`.moonpress-settings-edit` stage receives the bytes and existing ordinary
permission bits. Closed staging bytes and the target version are checked again
before publication. Existing files use per-file rename. Initial creation uses
an exclusive hard link so an unexpectedly appearing target is never overwritten.
The stage link is then removed. If this final cleanup fails, the error explicitly
states settings were saved and asks you to reload and inspect the remnant.

Occupied or unverifiable staging is refused/preserved. Caught pre-publication
failures attempt owned-stage cleanup. Process interruption can leave remnants;
there is no authoring undo journal, automatic recovery or power-loss guarantee.
Noncooperating processes can still race after final staging/target checks and
during final publication. This is not an atomic whole-site transaction.
Retain a backup, then validate the saved site and review the subsequent build.

## CLI

```sh
moonpress settings-read my-site --json
moonpress settings-save my-site absent /path/to/proposed-site.json --json
moonpress settings-save my-site <digest-from-read> /path/to/proposed-site.json --json
moonpress check my-site
moonpress review my-site dist --json
```

Use `absent` only for a missing configuration. Both commands accept `--json`
once after positional arguments and reject `--include-drafts`. JSON uses the
schema-1 command envelope; text quotes raw content to escape control characters.
Success exits 0, validation/I/O errors exit 1, argument errors exit 2. Failures
write stderr with empty stdout. Existing output remains unchanged until an
explicit build. The replacement file is read but never modified.

## Local administration

Open **Site settings** in the local admin navigation. The advanced JSON editor
supports every documented schema field and shows malformed saved JSON for repair.
A GET never creates a missing configuration. Saving uses the retained SHA-256 (or
explicit `absent`) and the existing form-token/origin checks. Failures retain the
submitted text and original version: reload and compare before retrying a conflict.
The editor escapes raw content and never treats it as HTML. Schema validation on
save is not a whole-site check: follow the workflow link to check, preview, review
production changes and explicitly build. Saving alone does not publish anything.

## Failure handling and verification

Before-publication I/O failures leave the original settings unchanged and attempt
to remove owned staging. If cleanup fails or the staged bytes/type change, the
remnant is retained and subsequent saves (including no-ops) refuse it. Inspect
both files and keep a backup before manual cleanup. Following initial creation,
the stage may be a second hard link to the saved file: do not edit that remnant.
Reload the settings snapshot to determine what was committed.

The native shell regression suites exercise write/flush/close/rename failures,
exclusive-create collisions, cleanup failures, replaced staging and cooperative
writer conflicts. Transition tests enable and remove sitemap/RSS/redirect/tag
outputs, reject stale reviewed plans, preserve manually edited outputs and
compare incremental output byte-for-byte with a fresh build. These checks do not
extend the concurrency or crash guarantees described above.

Settings reads and saves now retain a no-follow directory handle. Absence checks,
cooperative locking, staged writes, permission copying, publication and cleanup
all use that same directory. Renaming/replacing its original path cannot redirect
these operations into another directory: an in-flight operation can finish in the
original, now-renamed directory. Reload using its real path before further edits.
This does not freeze directory entries against uncooperative writers or promise
an atomic compare-and-swap of file contents. Broader authoring-path migration is
tracked in [#280](https://github.com/furukawa1020/MoonPress/issues/280).

The same retained-directory mutation boundary is also used by existing-media
replacement and post editing. Creation/import/duplication paths have separate
contracts; do not infer an atomic site-wide transaction from these guarantees.
