#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
expected=0123456789abcdef0123456789abcdef01234567
check() { bash scripts/verify-package-provenance.sh "$tmp" "$expected"; }
reject() { if check >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
printf 'source_commit=%s\nsource_tree=clean\n' "$expected" > "$tmp/BUILD.txt"
check > /dev/null
cp "$tmp/BUILD.txt" "$tmp/good"
for value in different modified; do
  cp "$tmp/good" "$tmp/BUILD.txt"
  if [[ "$value" = different ]]; then sed -i "s/$expected/ffffffffffffffffffffffffffffffffffffffff/" "$tmp/BUILD.txt"; else sed -i 's/clean/modified/' "$tmp/BUILD.txt"; fi
  reject
done
for key in source_commit source_tree; do
  cp "$tmp/good" "$tmp/BUILD.txt"
  grep "^$key=" "$tmp/good" >> "$tmp/BUILD.txt"
  reject
done
rm "$tmp/BUILD.txt"
reject
ln -s "$tmp/good" "$tmp/BUILD.txt"
reject
if bash scripts/verify-package-provenance.sh "$tmp" main >/dev/null 2>&1; then exit 1; fi
echo 'Package provenance: exact clean revision required; mismatches, duplicate fields, missing/linked records and invalid expected revisions refused.'
