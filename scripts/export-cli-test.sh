#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
review() { "$cli" review "$tmp/site" "$tmp/out" --json | jq -r '.report.review_id'; }
id="$(review)"
cp -a "$tmp/site" "$tmp/source-before"
cp -a "$tmp/out" "$tmp/output-before"
"$cli" export "$tmp/site" "$tmp/out" "$id" "$tmp/site.zip" --json > "$tmp/report"
jq -e '.schema == 1 and .command == "export" and .include_drafts == false' "$tmp/report" >/dev/null
test "$(jq -r '.report.digest' "$tmp/report")" = "$(sha256sum "$tmp/site.zip" | cut -d ' ' -f1)"
test "$(jq -r '.report.bytes' "$tmp/report")" = "$(wc -c < "$tmp/site.zip")"
unzip -q "$tmp/site.zip" -d "$tmp/unpacked"
rm "$tmp/output-before/.moonpress.json"
diff -r "$tmp/output-before" "$tmp/unpacked"
diff -r "$tmp/source-before" "$tmp/site"
"$cli" export "$tmp/site" "$tmp/out" "$id" "$tmp/again.zip" > "$tmp/text"
cmp "$tmp/site.zip" "$tmp/again.zip"
fail() { local code="$1"; shift; local actual=0; "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || actual=$?; test "$actual" = "$code"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
fail 1 export "$tmp/site" "$tmp/out" "$id" "$tmp/site.zip"
cmp "$tmp/site.zip" "$tmp/again.zip"
ln -s "$tmp/site.zip" "$tmp/link.zip"
fail 1 export "$tmp/site" "$tmp/out" "$id" "$tmp/link.zip"
test -L "$tmp/link.zip"
fail 1 export "$tmp/site" "$tmp/out" "$id" "$tmp/out/a.zip"
fail 1 export "$tmp/site" "$tmp/out" "$id" "$tmp/out/../out/a.zip"
test ! -e "$tmp/out/a.zip"
for destination in "$tmp/site/release.zip" "$tmp/site/public/release.zip" "$tmp/site/public/../public/release.zip" "$tmp/site/content/release.zip"; do
  fail 1 export "$tmp/site" "$tmp/out" "$id" "$destination"
  test ! -e "$destination"
done
diff -r "$tmp/source-before" "$tmp/site"
test "$(review)" = "$id"
fail 1 export "$tmp/site" "$tmp/out" bad "$tmp/bad.zip"
test ! -e "$tmp/bad.zip"
fail 2 export "$tmp/site" "$tmp/out" "$id"
fail 2 export "$tmp/site" "$tmp/out" "$id" "$tmp/new.zip" --include-drafts
fail 2 export "$tmp/site" "$tmp/out" "$id" "$tmp/new.zip" --json --json
mkdir "$tmp/aliases"
ln -s "$tmp" "$tmp/aliases/parent"
alias_site="$tmp/aliases/parent/site"
alias_id="$("$cli" review "$alias_site" "$tmp/out" --json | jq -r '.report.review_id')"
"$cli" export "$alias_site" "$tmp/out" "$alias_id" "$tmp/alias.zip" >/dev/null
cmp "$tmp/site.zip" "$tmp/alias.zip"
fail 1 export "$alias_site" "$tmp/out" "$alias_id" "$tmp/site/public/alias.zip"
test ! -e "$tmp/site/public/alias.zip"
ln -s "$tmp/site" "$tmp/site-link"
fail 1 export "$tmp/site-link/" "$tmp/out" "$alias_id" "$tmp/root-link.zip"
test ! -e "$tmp/root-link.zip"
diff -r "$tmp/source-before" "$tmp/site"
printf '# Changed\n' > "$tmp/site/content/index.md"
fail 1 export "$tmp/site" "$tmp/out" "$id" "$tmp/stale.zip"
fail 1 export "$tmp/site" "$tmp/out" "$(review)" "$tmp/stale.zip"
test ! -e "$tmp/stale.zip"
echo 'Export CLI passed: ZIP parity, JSON/text, deterministic reads, stale source, destination/alias protection and strict grammar.'
