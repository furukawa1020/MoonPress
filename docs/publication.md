# Staged publication and failure semantics

After source/output validation and planning, MoonPress prepares every changed
artifact and the next manifest inside a newly-created `.moonpress-stage/`
directory in the output. It does not replace or delete an existing artifact until
all these writes succeed. Preparation is implemented in MoonBit using native
filesystem I/O.

Publication then renames each changed file to its final path, removes stale
tracked files, and replaces `.moonpress.json` last. Rename is within the same
filesystem: readers of an individual file see its complete old or new contents,
not truncation while new content is written. A reader following multiple files
can still observe a mixed version.

## Ordinary failures

If preparation fails (for example a short write or failure writing the staged
manifest), existing artifact contents and manifest stay unchanged. MoonPress
attempts to remove only the staging files it created and then the empty staging
directory. For a newly-created output, it also attempts to remove the empty output
directory. A cleaned preparation failure can be retried.

If rename, stale-file deletion or final manifest replacement fails after
publication starts, some artifacts may already have changed. There is no rollback.
The diagnostic reports possible partial publication and directs the caller to a
fresh output directory. Output-integrity checks reject mismatched artifacts on
later builds rather than silently trusting them.

Cleanup is best-effort after an error and never recursively removes unknown
entries. A preexisting `.moonpress-stage` entry is always rejected without
deletion, whether it is genuine crash debris or unrelated user data. Investigate
it separately and rebuild into a fresh directory. Do not delete a staging entry
while another build could be running.

## Guarantees and remaining work

- Unchanged files keep their inode and mtime. A completely unchanged build creates
  no staging directory and rewrites no manifest.
- Successful output contains no staging directory and remains byte-identical to a
  clean build, including the manifest.
- Changed files receive the normal permissions/ownership of newly-created files
  under the invoking user's umask. Manually changed mode bits on replaced files
  are not preserved; unchanged files retain theirs.
- Staging requires additional disk space for all changed artifacts and the next
  manifest. Only generated output, not source files, is staged.
- This is **not a multi-file transaction**, a durable commit protocol or automatic
  crash recovery. No fsync/power-loss guarantee is made. SIGKILL or power loss may
  leave staging entries or partial publication. [#49](https://github.com/furukawa1020/MoonPress/issues/49)
  remains open for recovery.
- Directory locks protect cooperating build/explain processes; they do not make
  external readers observe a whole-build snapshot. See [concurrency](concurrency.md).

Tests inject a partial staged write, staged-manifest creation failure, artifact
rename failure, stale-file deletion failure and manifest rename failure into the
real native CLI. They verify preservation before publication, complete per-file
contents and uncommitted old manifests on failures, cleanup, and rejection of
partial state. Test injection code is separate from the shipped executable. The staged writer owns its stdio handle in MoonBit and closes it on every
raised-error path. Fault probes reproduce 16 leaked descriptors after 16 legacy
short-write/flush failures; the new writer shows zero growth for write, flush
and close failures. Reader cleanup remains tracked in
[#54](https://github.com/furukawa1020/MoonPress/issues/54).
