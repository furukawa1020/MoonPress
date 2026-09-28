# Publication and recovery

After source/output validation and planning, MoonPress writes changed artifacts
and the next manifest into a newly-created `.moonpress-stage/` directory.
Before publication, it preserves existing files that will be changed or deleted
as hard links in `.moonpress-stage/backup/`. The filesystem must support hard
links within the output directory; backup failures abort before publication.

After preparation, MoonPress writes a versioned `journal` in the staging
directory, containing exact old/next manifests, planned writes and prior file
presence. The journal is validated and fully closed before any public artifact
is changed. Journal write failures abort publication; owned cleanup removes the
journal last. A journal is a recovery prerequisite, not permission for `build`
to overwrite crash remnants. Journals are integrity records, not authenticated
proof of ownership against deliberate tampering.

MoonBit records each successful artifact rename or stale-file deletion.
The manifest is replaced last. Its successful replacement is the commit point;
when the manifest bytes are unchanged, completion of the artifact operations
is the commit point.

## Caught failures before commit

A preparation/backup failure leaves existing artifact contents unchanged.
A rename, deletion or manifest replacement error triggers reverse-order rollback:
old files are renamed back from backup, and newly-created files are removed.
Previously missing tracked files return to absence. The old manifest is untouched.

Successful rollback preserves the old files' contents, inode, mode and mtime.
Hard-link creation/removal can change link counts and ctime; directory timestamps
are not preserved. The original error is still returned with exit code 1, but the
diagnostic states that the previous output was restored. After the underlying
failure is resolved, a normal build can be retried.

Cleanup removes only staging entries owned by that invocation, then empty staging
directories. A fresh output is removed if preparation or rollback completes
before commit. Unknown entries are never recursively removed.

## Failed rollback and post-commit cleanup

If rollback itself fails, remaining backups and staging entries are retained.
The diagnostic includes the original publication error and rollback failure.
The next build/explain refuses the staging entry. Run `moonpress recover` as
described below; retain the directory for investigation if preflight rejects it.

If the manifest has committed, a cleanup failure **does not trigger rollback**:
the generated files and committed manifest describe the new build. The command
still fails with an explicit committed/cleanup diagnostic. Staging remnants are
not silently removed on a later invocation.

Build/explain reject any preexisting `.moonpress-stage` entry without deletion.
They never run recovery automatically. Do not remove staging directories while
another build or recovery could be running.

## Explicit restart recovery

```sh
moonpress recover dist
moonpress recover dist --json
```

Recovery requires no source directory. It holds the same exclusive parent lock
as build and first validates the entire journal, output tree, remaining staged
payloads and backups. Unknown entries, modified bytes, symlinks, non-regular
files, invalid manifests and missing required backup data cause failure before
any mutation. A journal does not authenticate deliberately forged state.

Before commit, recovery restores prior files from their preserved inodes and
removes artifacts that were previously absent. Missing tracked artifacts return
to absence; a fresh unpublished output returns to absence. If the next manifest
has committed and **every** new artifact matches with no stale outputs, recovery
only removes owned staging data. It never rolls a committed new manifest back.
When old and new manifest bytes are identical (for example, missing-file repair),
a fully matching new tree is finalized; otherwise prior presence is restored.

Recovery can be retried after a process interruption or an I/O error while the
complete journal remains: already restored files are recognized by their old
digests and remaining backups are checked before more changes. Successful
restoration preserves content, inode, mode and mtime; ctime and directory times
are excluded. Once cleanup starts, the selected state is already complete.

Reports use `action`: `rolled_back`, `finalized`, `clean` (managed output with no
stage), or `absent` (no output directory). `restored` counts backup renames and
`removed` counts newly-created artifacts removed by this invocation, not staging
cleanup. The JSON envelope uses schema 1, command `recover`, `include_drafts:
false`, and `report`. `--include-drafts` is not accepted. Exit codes match other
commands: 0 success, 1 validation/I/O error, 2 invalid arguments. On failure,
stdout is empty; errors go to stderr. Resolve I/O errors before retrying.

**Limits:** recovery refuses a missing, partial or unsupported journal. A kill
before journal completion, after its final removal but before staging `rmdir`,
or during final fresh-output directory removal can leave remnants with no
sufficient ownership record. Use a fresh output directory and keep the old one
for inspection in those cases. Legacy pre-journal builds are also unsupported.
There is no automatic cleanup of unrecognized remnants and no fsync guarantee.
The supported contract is process interruption on the tested local Linux
filesystem, not filesystem corruption or power loss.

## Limits and resource behavior

This is **not a multi-file transaction** or a power-loss durability protocol. An individual rename exposes complete old or
new file contents, but readers of several files can observe mixed versions, even
during rollback. SIGKILL, power loss or interruption during rollback can leave
partial output. No fsync/power-loss guarantee is made.
[#49](https://github.com/furukawa1020/MoonPress/issues/49) tracks the remaining
pre-journal/final-cleanup windows and durability work.

Directory locks coordinate cooperating build/explain processes. External edits,
old binaries without locking and hostile concurrent path changes are outside
the contract. See [concurrency](concurrency.md).

Unchanged files keep their inode and mtime; a no-op creates no staging directory.
Changed files receive new-file permissions/ownership under the invoking user's
umask on a successful build. Preparation needs space for changed artifacts and
the new manifest; backups preserve old inodes without copying their bytes, and
keep replaced/deleted data allocated until commit cleanup.

Successful output has no staging directory and remains byte-identical to a clean
build, including the manifest.

## Verification

Real-CLI fault injection covers partial staged writes, staging/backup failures,
artifact rename, stale deletion, manifest rename, rollback failure and cleanup
after commit. Tests compare previous bytes and inode/mode/mtime, verify new-file
removal and deleted/missing-file restoration, and exercise a normal retry.
SIGKILL tests also verify complete journals immediately before and after the
first public rename, including fresh outputs and missing tracked files.

File readers and staged writers own their stdio handles in MoonBit and close them
on raised-error paths. The fault probes from [#54](https://github.com/furukawa1020/MoonPress/issues/54)
show zero descriptor growth across repeated I/O failures. Test injection code is
separate from the shipped executable.

Recovery tests kill actual processes around artifact writes, stale deletion,
manifest replacement, backup cleanup and recovery itself. They cover prior file
metadata, repeated recovery, equal manifests, fresh outputs, clean-build parity,
preflight rejection without mutation and real competing recovery locks.
