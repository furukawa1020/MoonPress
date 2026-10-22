# Authoring filesystem boundary

MoonPress retains a no-follow directory descriptor for these operations:

| Operation | Retained directory | Lock / mutation scope |
| --- | --- | --- |
| Settings snapshot | Site root | Read and absence inspection only |
| Settings save | Site root | Lock, stage, version recheck, publish, cleanup |
| Post snapshot | content | Read only |
| Post save, draft status, article settings | content | Lock, stage verification, version recheck, rename, cleanup |
| New draft and duplicate | content | Lock, exclusive creation, failure cleanup; duplicate source recheck uses this handle |
| Media replacement | public | Lock, stage verification, version recheck, rename, cleanup |
| Media import and browser upload | public | Lock, exclusive creation, failure cleanup |

All path components are opened without following symlinks. A renamed directory
stays the target of an in-flight operation: replacing its former pathname cannot
redirect later mutations into another directory. The operation may succeed in
the renamed directory; its displayed source name is a logical relative name,
not proof that the original pathname still names the same directory. Reload via
the real directory path before continuing.

Locks belong to these directory inodes and are released on close/process exit.
Cooperative writers on the same directory conflict, including pre-existing
pathname-based writers that resolve to the same inode. Separate root/content/
public locks do not freeze an entire site or serialize authoring with builds.

Version checks compare observed bytes. They are not inode identity checks or an
atomic compare-and-swap against arbitrary uncooperative processes. Those can
still change directory entries or bytes after final checks. Authoring streams flush and fsync file contents and permissions before close.
A failed file sync prevents publication of replacement stages. This alone does
not make the directory entry durable. Replacement saves additionally fsync the
retained directory after rename/link, and cleanup fsyncs it after unlink. A
failed commit sync reports visible data with unconfirmed durability; it never
removes the published replacement. Reload before retrying. Partial-write cleanup is best effort; these operations do not promise an adversarial same-directory
transaction, undo history, crash recovery or power-loss durability. An occupied
or unverifiable replacement stage blocks retries until inspected.

Directory creation itself (`init`, preparing an absent public directory) remains
a separate pathname-based setup operation. Use trusted, stable parent directories
for setup. Read-only inventory/compiler traversal and reading a local replacement
or import source are also outside the retained mutation boundary. Build output
ownership, reviewed-plan checks and publication/recovery rules remain separate.

## Regression coverage

Deterministic native fault fixtures replace roots or content/public paths after
open and at lock, exclusive-create, rename/link publication and cleanup. They
verify original-directory behavior, unchanged foreign bytes/inodes/staging, and
preserved versions/modes. Repeated-failure probes cover snapshots, stream setup,
write/flush/close, stage read and publication, checking zero descriptor growth.
Existing CLI/browser, contention, interruption and incremental/fresh-build tests
continue to run in `scripts/check.sh`.
