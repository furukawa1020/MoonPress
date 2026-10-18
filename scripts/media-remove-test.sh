#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
MOONPRESS_REMOVAL_PROBE="$tmp" moon test --target native --filter 'reviewed media removal filesystem probe'
diff -r "$tmp/out" "$tmp/clean"
echo 'Reviewed removal passed: acknowledgement, known references, stale source/bytes, repeated removal refusal and explicit rebuild parity.'
