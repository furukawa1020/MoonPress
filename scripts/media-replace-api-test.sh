#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/public"
printf '\000\377old' > "$tmp/site/public/a.png"
: > "$tmp/site/empty"
MOONPRESS_MEDIA_REPLACE_PROBE="$tmp/site" moon test --target native --filter 'media replacement filesystem probe'
test ! -s "$tmp/site/public/a.png"
test ! -s "$tmp/site/empty"
test ! -e "$tmp/site/public/.moonpress-media-edit"
test ! -e "$tmp/site/.moonpress-build"
echo 'Media replacement API tests passed: binary writes, no-op reports, stale/invalid versions, empty files, source preservation and staging cleanup.'
