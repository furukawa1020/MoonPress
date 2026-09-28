# Build coordination

On the supported local Linux filesystem, `build` acquires an exclusive advisory
lock before reading previous output state and holds it until publication returns
or raises an error. `explain` uses a shared lock for the same interval: multiple
explain operations can coexist, but they cannot overlap a writer. `check` has no
output state and acquires no lock.

Acquisition is nonblocking. Conflicting access exits with code 1 and a diagnostic
on stderr; no report is printed to stdout and no output is changed. Retry after
the other process finishes.

## Scope and lifecycle

MoonPress locks the **canonical output parent directory**, not a generated file.
This also protects an output that does not exist yet, without creating an output
directory or lock metadata during explain. Relative/absolute paths, `.`, `..`
and symlinked parent aliases resolve to the same parent inode when they name the
same filesystem location. A symlink for the output itself remains invalid.

This is deliberately conservative: distinct outputs with the same parent also
conflict. Place outputs under separate parent directories for parallel builds.
The parent must already exist, be readable and support directory `flock`.
Unsupported or inaccessible lock targets fail explicitly; there is no unlocked
fallback.

The lock is held by an open file descriptor. Normal completion, raised errors and
process termination (including SIGKILL) release it; no stale lock files need
manual deletion. Do not delete/rename parent directories while builds run.

## Limits

Locks coordinate cooperating MoonPress processes, not editors, deploy tools,
older binaries without locking or hostile processes. Do not modify source/output
trees during a build. Local Linux is tested; network/distributed filesystem
locking semantics are not supported by this contract.

Locking does not make multi-file publication transactional. Caught publication
errors before commit attempt rollback. A process killed during publication or an
interrupted/failed rollback can still leave partial output; use a fresh directory
in that case. [Recovery work](https://github.com/furukawa1020/MoonPress/issues/49)
tracks that separate problem. Crash-release tests terminate a writer before
publication and do not claim crash consistency during publication.

The native boundary resolves/open-locks/closes directory descriptors and performs
per-file rename. [Staging semantics](publication.md) describe publication separately.
Planning, validation, report generation and artifact decisions remain MoonBit.
The tests use a separate LD_PRELOAD fixture to pause a real CLI after locking;
no test hooks or environment switches are linked into the product.
