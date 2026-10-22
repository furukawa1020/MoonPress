#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/good/content" "$tmp/file/content" "$tmp/link/content" "$tmp/open/content" "$tmp/outside"
MOONPRESS_VAULT_FIXTURE="$tmp/good" moon test --target native --filter 'private vault preparation filesystem probe'
test "$(stat -c %a "$tmp/good/.moonpress-history")" = 700
test "$(stat -c %a "$tmp/good/.moonpress-history/sample.backup")" = 600
printf foreign > "$tmp/file/.moonpress-history"
ln -s "$tmp/outside" "$tmp/link/.moonpress-history"
mkdir -m 755 "$tmp/open/.moonpress-history"
for name in file link open; do
  MOONPRESS_VAULT_FIXTURE="$tmp/$name" MOONPRESS_VAULT_REJECT=1 moon test --target native --filter 'private vault preparation filesystem probe'
done
test "$(cat "$tmp/file/.moonpress-history")" = foreign
test -z "$(find "$tmp/outside" -mindepth 1 -print -quit)"
echo 'Private vault preparation passed: owner-only directories, durable exclusive records, foreign entry/symlink/permission refusal.'
