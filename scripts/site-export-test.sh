#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
MOONPRESS_EXPORT_PROBE="$tmp" moon test --target native --filter 'verified production export filesystem probe'
unzip -t "$tmp/site.zip"
LC_ALL=C.UTF-8 unzip -q "$tmp/site.zip" -d "$tmp/unpacked"
test -f "$tmp/unpacked/月.html"
test ! -e "$tmp/unpacked/private.html"
test ! -e "$tmp/unpacked/.moonpress.json"
echo 'Verified export passed: current review, byte integrity, deterministic archive, draft exclusion, stale source and edited output refusal.'
