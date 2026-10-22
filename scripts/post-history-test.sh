#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '# Original\n\nPrivate history text.\n' > "$tmp/site/content/a.md"
MOONPRESS_HISTORY_FIXTURE="$tmp/site" moon test --target native --filter 'immutable checkpoint filesystem probe'
test "$(find "$tmp/site/.moonpress-history" -name '*.json' | wc -l)" = 1
record="$(find "$tmp/site/.moonpress-history" -name '*.json')"
test "$(stat -c %a "$record")" = 600
jq -e '.schema == 1 and .name == "a.md" and .created > 0' "$record" >/dev/null
grep -Fq 'Private history text.' "$tmp/site/content/a.md"
mkdir -p "$tmp/transitions/content"
printf '# Original\n' > "$tmp/transitions/content/a.md"
MOONPRESS_HISTORY_TRANSITIONS="$tmp/transitions" moon test --target native --filter 'enabled history save and restore filesystem probe'
echo 'Immutable checkpoints passed: exact private bytes, deduplication, source-version refusal and bounded content.'

mkdir -p "$tmp/isolation/content" "$tmp/isolation/.moonpress-history" "$tmp/isolation/foreign/.moonpress-history"
chmod 700 "$tmp/isolation/.moonpress-history" "$tmp/isolation/foreign/.moonpress-history"
MOONPRESS_HISTORY_FOREIGN="$tmp/isolation" moon test --target native --filter 'vault must share retained content parent'
