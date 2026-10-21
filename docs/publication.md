# Publication and recovery

After source/output validation and planning, MoonPress validates a versioned
journal containing exact old/next manifests, planned writes and prior presence.
It installs this complete journal in the output parent before creating output
or staging directories. The parent record is never overwritten. A second
complete copy is placed in `.moonpress-stage/journal` for legacy compatibility.

Changed artifacts and the next manifest are installed complete-or-absent in the
new `.moonpress-stage/` directory using anonymous files. Existing files that will
be changed or deleted are preserved as hard links in `.moonpress-stage/backup/`.
Backup failures abort before publication. The filesystem must support anonymous
temporary files and same-filesystem hard links.

A journal is a recovery prerequisite, not permission for `build` to overwrite
crash remnants. Journals are integrity records, not authenticated proof of
ownership against deliberate tampering. The parent record is removed only after
staging cleanup and any fresh-output rollback removal finish.

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

Before output or staging creation, a complete journal is installed exclusively in the
output's parent as `.moonpress-recovery-<SHA256 of canonical output basename>.json`.
The journal and staged payloads use Linux anonymous temporary files (`O_TMPFILE`)
and exclusive link installation: interrupted writes leave no named partial file.
Anonymous file bytes are flushed and fsynced before installation; interrupted
fsync calls are retried, while other synchronization failures abort before naming
the file. This synchronizes file contents only.
Unsupported filesystems fail closed before output changes. The record remains
until stage cleanup and fresh-output rollback removal finish.
Recovery validates this record and any remaining stage before mutation. A stopped
cleanup can be retried even after the stage or fresh output directory disappears.
Build refuses retained records; run `recovery-plan` and `recover` first. Do not
move/delete these records separately from interrupted outputs. Unknown or conflicting
records are refused, never overwritten. Successful cleanup leaves no parent record.

Legacy stage-only recovery of an existing output does not require a new parent
record, preserving compatibility with writable outputs in read-only parents.
A legacy first-build rollback must remove the output directory itself, so it
installs complete parent intent before any rollback mutation. Denied parent
writes leave that remnant unchanged; failed final removal remains retryable.
Legacy cleanup without a parent record cannot recover a second interruption
after its only journal has been removed. New builds always require a writable
parent and establish that requirement before public mutation.

**Limits:** legacy interruptions without a complete journal or retained record are
still refused. New builds can be retried after an interrupted initial anonymous
journal write (output is unchanged), or explicitly recovered after the parent
journal is installed, including preparation and final cleanup interruptions.
This requires Linux `O_TMPFILE`, `/proc/self/fd`, same-filesystem hard links and
cooperative local writers. Directory entries, backup links, commit/rollback
ordering and cleanup are not yet synchronized as a complete durability protocol.
File fsync alone does not establish power-loss recovery; no power-loss guarantee
is made.

## Limits and resource behavior

This is **not a multi-file transaction** or a power-loss durability protocol. An individual rename exposes complete old or
new file contents, but readers of several files can observe mixed versions, even
during rollback. SIGKILL, power loss or interruption during rollback can leave
partial output. File-data synchronization alone does not provide a complete
power-loss durability guarantee.
[#49](https://github.com/furukawa1020/MoonPress/issues/49) tracks the remaining
remaining durability work.

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

### State file size limits

Publication and recovery accept ownership manifests up to 4 MiB of UTF-8 bytes
and publication journals up to 64 MiB. Recovery checks on-disk sizes before
allocating text buffers, including a clean output without a staging directory.
Builds reject an oversized next manifest before creating staging or changing
output. These are state-file limits, not a total output or artifact-size budget.
Oversized state is refused without cleanup; keep the original directory intact
and build a separate output after reducing the site if necessary.

## Inspect before recovering

Run `moonpress recovery-plan OUTPUT --json` before `moonpress recover OUTPUT --json`.
Inspection uses the same full preflight, without changing output or staging files.
It takes a shared output-parent lock, allowing other shared readers on sibling
outputs while excluding cooperative writers. Actual recovery takes an exclusive
lock. A busy parent causes immediate refusal instead of waiting.
The schema-1 envelope identifies `command: "recovery-plan"`; `report.action` uses
these existing recovery result names as **prospective** outcomes:

| Action | Meaning during inspection |
| --- | --- |
| `rolled_back` | Recovery would restore the prior output state. |
| `finalized` | Recovery would keep the complete new tree and remove staging. |
| `clean` | No stage is present; ownership validation passed. |
| `absent` | Output does not exist; nothing needs recovery. |

`restored` and `removed` count planned public-file operations, excluding staging
cleanup. Restoring an available backup counts even when its bytes already match.
This is not a reservation or approval token. An inspection cannot guarantee later
I/O success; recovery reacquires its lock and revalidates all current state.
Source edits do not participate in recovery, and a clean result does not say that
output matches the latest sources. Review and build again after successful recovery.

The administration `/recovery` page inspects only `<site>/.moonpress-build`, with
no arbitrary output path or mutation endpoint. A blocked Publish page links to it.
It reports prospective actions and terminal instructions; unknown/edited state
still fails closed. The interruption and durability limits above are unchanged.
