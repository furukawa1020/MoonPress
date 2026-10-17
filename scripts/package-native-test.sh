#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bash scripts/package-native.sh "$tmp/package" > "$tmp/log"
(cd "$tmp/package" && sha256sum -c SHA256SUMS)
mkdir "$tmp/unpacked"
tar -xzf "$tmp/package/moonpress-linux-x86_64.tar.gz" -C "$tmp/unpacked"
bundle="$tmp/unpacked/moonpress-linux-x86_64"
(cd "$bundle" && sha256sum -c EXECUTABLE.sha256)
test -s "$bundle/licenses/MoonBit-NOTICE"
grep -Fq "source_commit=$(git rev-parse HEAD)" "$bundle/BUILD.txt"
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" --help > "$tmp/help"
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" init "$tmp/site" >/dev/null
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" check "$tmp/site" >/dev/null
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" build "$tmp/site" "$tmp/output" >/dev/null
test -s "$tmp/output/index.html"
cp "$tmp/package/SHA256SUMS" "$tmp/before"
if bash scripts/package-native.sh "$tmp/package" >/dev/null 2>&1; then exit 1; fi
cmp "$tmp/before" "$tmp/package/SHA256SUMS"
echo 'Native package tests passed: checksums/provenance/notices, unpacked CLI without MoonBit, init/check/build and occupied destination protection.'
