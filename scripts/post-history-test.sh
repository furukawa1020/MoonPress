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
echo 'Immutable checkpoints passed: exact private bytes, deduplication, source-version refusal and bounded content.'
