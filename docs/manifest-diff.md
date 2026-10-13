# Dependency and manifest differences

`dependency_changes(old, next)` returns every added, removed and changed direct
dependency with optional old/new SHA-256 values. Records have deterministic name
order; ordering-only changes produce no differences. Both lists use the same
name/digest validation as ownership manifests, and input arrays are preserved.
This compares recorded keys and digests, not hypothetical future edits.

`compare_manifests(old_text, next_text)` validates both schema-1 manifests and
compares every output, including unchanged ones. Counts classify added, removed,
changed and unchanged outputs. Each record has `action`, optional old/new content
digests, `content_changed`, and complete `dependencies` deltas. Dependency-only
changes are `changed` with `content_changed: false`. Added/removed outputs have
`content_changed: true` because only one side has content. Reordering manifest
records or dependency lists has no effect. Invalid paths, versions, duplicate
names and malformed digests fail rather than produce a partial comparison.

This pure service compares snapshots; it does not inspect current source files,
verify output bytes, publish files or forecast a rebuild. Use `audit` for output
integrity and `explain` for the actual protected incremental plan.

Compare saved snapshots without rebuilding:

```sh
moonpress diff before.json after.json
moonpress diff before.json after.json --json
```

Both files must be regular UTF-8 files (no symlinks or special files). Reports
include unchanged outputs and always exit 0 on a valid comparison, even when
different. `--json` uses the common schema-1 envelope with command `diff`,
`include_drafts: false` and the comparison in `report`. Validation/I/O failures
exit 1 with empty stdout; incorrect arguments exit 2. There is no
`--include-drafts` option: each snapshot already records its chosen build scope.
Keep snapshots outside managed output directories to avoid foreign-file refusal.
Snapshot files need not sit beside their original generated output.
