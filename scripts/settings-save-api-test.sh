#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/site"
printf '{"tag_index":true}\n' > "$tmp/site/replacement"
cp "$tmp/site/replacement" "$tmp/before"
MOONPRESS_SETTINGS_SAVE_PROBE="$tmp/site" moon test --target native --filter 'site settings save filesystem probe'
cmp "$tmp/before" "$tmp/site/replacement"
cmp "$tmp/site/replacement" "$tmp/site/site.json"
test ! -e "$tmp/site/.moonpress-settings-edit"
echo 'Settings save API tests passed: exclusive creation, expected versions, exact no-op, invalid config refusal and file-source preservation.'
