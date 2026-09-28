# Publication and ordinary-error rollback

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
The next build/explain refuses the staging entry; use a fresh output directory
and retain the old directory for investigation. There is no automatic restart
recovery yet.

If the manifest has committed, a cleanup failure **does not trigger rollback**:
the generated files and committed manifest describe the new build. The command
still fails with an explicit committed/cleanup diagnostic. Staging remnants are
not silently removed on a later invocation.

Any preexisting `.moonpress-stage` entry is rejected without deletion, whether
it is genuine crash debris or unrelated data. Do not remove staging directories
while another build could be running.

## Limits and resource behavior

This is rollback for caught runtime errors, **not a multi-file transaction** or
a durable crash-recovery protocol. An individual rename exposes complete old or
new file contents, but readers of several files can observe mixed versions, even
during rollback. SIGKILL, power loss or interruption during rollback can leave
partial output. No fsync/power-loss guarantee is made.
[#49](https://github.com/furukawa1020/MoonPress/issues/49) tracks restart recovery.

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
