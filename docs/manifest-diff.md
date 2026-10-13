# Dependency and manifest differences

`dependency_changes(old, next)` returns every added, removed and changed direct
dependency with optional old/new SHA-256 values. Records have deterministic name
order; ordering-only changes produce no differences. Both lists use the same
name/digest validation as ownership manifests, and input arrays are preserved.
This compares recorded keys and digests, not hypothetical future edits.
