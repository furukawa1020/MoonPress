#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
MOONPRESS_ZIP_PROBE="$tmp/site.zip" moon test --target native --filter 'ZIP interoperability fixture'
unzip -t "$tmp/site.zip"
mkdir "$tmp/unpacked"
LC_ALL=C.UTF-8 unzip -q "$tmp/site.zip" -d "$tmp/unpacked"
printf '<h1>月</h1>\n' > "$tmp/html"
printf '\000\377\200abc' > "$tmp/binary"
cmp "$tmp/html" "$tmp/unpacked/月.html"
cmp "$tmp/binary" "$tmp/unpacked/binary.png"
test -f "$tmp/unpacked/.nojekyll"
test ! -s "$tmp/unpacked/.nojekyll"
test "$(find "$tmp/unpacked" -type f | wc -l)" = 3
MOONPRESS_ZIP_PROBE="$tmp/again.zip" moon test --target native --filter 'ZIP interoperability fixture'
cmp "$tmp/site.zip" "$tmp/again.zip"
echo 'ZIP interoperability passed: independent CRC/extraction, Unicode/binary/empty entries and deterministic archive bytes.'
