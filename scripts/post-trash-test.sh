#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '# Original\n\nTrash round trip.\n' > "$tmp/site/content/a.md"
MOONPRESS_TRASH_FIXTURE="$tmp/site" moon test --target native --filter 'article trash and restoration filesystem probe'
test "$(stat -c %a "$tmp/site/.moonpress-trash")" = 700
grep -Fq 'Trash round trip.' "$tmp/site/content/a.md"
echo 'Article trash passed: durable private backup, stale refusal, occupied-name preservation, exact restore and completed record cleanup.'
