#!/usr/bin/env bash
# Verify build identity before executing an unpacked release candidate.
set -euo pipefail
bundle="${1:?bundle directory required}"
expected="${2:?expected revision required}"
[[ "$expected" =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected source revision must be a full lowercase commit SHA.' >&2; exit 1; }
record="$bundle/BUILD.txt"
[[ -f "$record" && ! -L "$record" ]] || { echo 'Missing regular build provenance record.' >&2; exit 1; }
[[ "$(grep -c '^source_commit=' "$record")" = 1 && "$(grep -c '^source_tree=' "$record")" = 1 ]] || { echo 'Ambiguous build provenance.' >&2; exit 1; }
grep -Fxq "source_commit=$expected" "$record" || { echo 'Candidate source revision mismatch.' >&2; exit 1; }
grep -Fxq 'source_tree=clean' "$record" || { echo 'Candidate was not built from a clean source tree.' >&2; exit 1; }
printf 'Candidate source identity verified: %s\n' "$expected"
