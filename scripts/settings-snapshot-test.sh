#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for name in missing broken valid link pipe directory invalid-utf8; do mkdir "$tmp/$name"; done
printf '{ broken JSON\n' > "$tmp/broken/site.json"
printf '{}\n' > "$tmp/valid/site.json"
printf '\377' > "$tmp/invalid-utf8/site.json"
ln -s "$tmp/valid/site.json" "$tmp/link/site.json"
mkfifo "$tmp/pipe/site.json"
mkdir "$tmp/directory/site.json"
cp "$tmp/broken/site.json" "$tmp/before-broken"
cp "$tmp/valid/site.json" "$tmp/before-valid"
MOONPRESS_SETTINGS_PROBE="$tmp" timeout 30 moon test --target native --filter 'site settings snapshot filesystem probe'
cmp "$tmp/before-broken" "$tmp/broken/site.json"
cmp "$tmp/before-valid" "$tmp/valid/site.json"
test ! -e "$tmp/missing/site.json"
echo 'Settings snapshot tests passed: explicit absence, raw malformed repair text, exact version and unsafe file refusal.'
