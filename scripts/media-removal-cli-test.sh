#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
printf image > "$tmp/site/public/月.png"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/site" "$tmp/before"
cp -a "$tmp/out" "$tmp/output"
plan() { "$cli" media-removal-plan "$tmp/site" '月.png' --json > "$tmp/plan"; jq -r '.report.review_id' "$tmp/plan"; }
id="$(plan)"
jq -e '.command == "media-removal-plan" and .include_drafts == true and .report.blocked == false and .report.references == []' "$tmp/plan" >/dev/null
"$cli" media-removal-plan "$tmp/site" '月.png' > "$tmp/text"
grep -Fq "$id" "$tmp/text"
diff -r "$tmp/before" "$tmp/site"
fail() { local expected="$1"; shift; local status=0; "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?; test "$status" = "$expected"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
fail 2 media-remove "$tmp/site" '月.png' "$id"
fail 2 media-remove "$tmp/site" '月.png' "$id" yes
fail 2 media-remove "$tmp/site" '月.png' "$id" confirm-unscanned-removal --include-drafts
fail 2 media-removal-plan "$tmp/site" '月.png' --include-drafts
fail 2 media-removal-plan "$tmp/site" '月.png' --json --json
fail 1 media-remove "$tmp/site" '月.png' bad confirm-unscanned-removal
printf '\nChanged\n' >> "$tmp/site/content/index.md"
fail 1 media-remove "$tmp/site" '月.png' "$id" confirm-unscanned-removal
printf '%s\n' '---' '{"draft":true}' '---' '# Private' '' '![Image](%E6%9C%88.png)' > "$tmp/site/content/private.md"
blocked="$(plan)"
jq -e '.report.blocked == true and (.report.references | length > 0)' "$tmp/plan" >/dev/null
fail 1 media-remove "$tmp/site" '月.png' "$blocked" confirm-unscanned-removal
printf '# Private without image\n' > "$tmp/site/content/private.md"
id="$(plan)"
"$cli" media-remove "$tmp/site" '月.png' "$id" confirm-unscanned-removal --json > "$tmp/removed"
jq -e '.command == "media-remove" and .include_drafts == true and .report.item.source == "public/月.png"' "$tmp/removed" >/dev/null
test ! -e "$tmp/site/public/月.png"
diff -r "$tmp/output" "$tmp/out"
fail 1 media-remove "$tmp/site" '月.png' "$id" confirm-unscanned-removal
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
echo 'Media removal CLI passed: JSON/text, strict explicit acknowledgement, draft references, stale review and separate rebuild parity.'
