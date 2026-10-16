#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
rm "$tmp/site/site.json"
"$cli" settings-read "$tmp/site" --json > "$tmp/snapshot"
jq -e '.schema==1 and .command=="settings-read" and (.include_drafts|not) and (.report.exists|not) and .report.digest==null and .report.content=="{}\n"' "$tmp/snapshot" >/dev/null
test ! -e "$tmp/site/site.json"
printf '{"tag_index":true}\n' > "$tmp/config"
"$cli" settings-save "$tmp/site" absent "$tmp/config" --json > "$tmp/created"
jq -e '.command=="settings-save" and .report.changed and .report.created' "$tmp/created" >/dev/null
version="$(jq -r '.report.digest' "$tmp/created")"
cmp "$tmp/config" "$tmp/site/site.json"
test "$version" = "$(sha256sum "$tmp/site/site.json" | cut -d ' ' -f1)"
chmod 640 "$tmp/site/site.json"
touch -t 200001010000 "$tmp/site/site.json"
metadata="$(stat -c '%i %a %Y' "$tmp/site/site.json")"
"$cli" settings-save "$tmp/site" "$version" "$tmp/config" --json | jq -e '(.report.changed|not) and (.report.created|not)' >/dev/null
test "$(stat -c '%i %a %Y' "$tmp/site/site.json")" = "$metadata"
reject() { local expected="$1" code=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = "$expected"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
reject 1 "$cli" settings-save "$tmp/site" absent "$tmp/config"
reject 1 "$cli" settings-save "$tmp/site" bad "$tmp/config"
for content in '{broken' '{"page_size":0}' '{"feed":{}}' '{"unknown":true}'; do
  printf '%s' "$content" > "$tmp/invalid"
  reject 1 "$cli" settings-save "$tmp/site" "$version" "$tmp/invalid"
  cmp "$tmp/config" "$tmp/site/site.json"
done
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/before-out"
printf '{"base_url":"https://example.org/blog/","tag_index":true}\n' > "$tmp/config"
"$cli" settings-save "$tmp/site" "$version" "$tmp/config" --json > "$tmp/changed"
test "$(stat -c %a "$tmp/site/site.json")" = 640
diff -r "$tmp/out" "$tmp/before-out"
reject 1 "$cli" settings-save "$tmp/site" "$version" "$tmp/config"
"$cli" check "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
# Invalid JSON is readable and repairable, with a version of the exact bad bytes.
printf '{broken\n' > "$tmp/site/site.json"
"$cli" settings-read "$tmp/site" --json > "$tmp/broken"
jq -e '.report.exists and .report.content=="{broken\n"' "$tmp/broken" >/dev/null
broken="$(jq -r '.report.digest' "$tmp/broken")"
"$cli" settings-save "$tmp/site" "$broken" "$tmp/config" >/dev/null
cmp "$tmp/config" "$tmp/site/site.json"
for command in settings-read settings-save; do
  "$cli" "$command" --help | grep -Fq "Usage: moonpress $command"
  reject 2 "$cli" "$command"
  grep -Fq "Usage: moonpress $command" "$tmp/stderr"
done
reject 2 "$cli" settings-read "$tmp/site" --json --json
reject 2 "$cli" settings-read "$tmp/site" --include-drafts
reject 2 "$cli" settings-save "$tmp/site" "$broken" "$tmp/config" --json --json
reject 2 "$cli" settings-save "$tmp/site" "$broken" "$tmp/config" --include-drafts
ln -s "$tmp/config" "$tmp/link"
mkfifo "$tmp/pipe"
current="$("$cli" settings-read "$tmp/site" --json | jq -r '.report.digest')"
for file in "$tmp/link" "$tmp/pipe" "$tmp/site" "$tmp/missing"; do
  reject 1 timeout 5 "$cli" settings-save "$tmp/site" "$current" "$file"
done
"$cli" settings-read "$tmp/site" | grep -Fq 'No files written.'
test ! -e "$tmp/site/.moonpress-settings-edit"
echo 'Settings CLI tests passed: absent/create, exact versions, raw repair, schema/stale refusal, no-op metadata/modes, strict grammar and separate deterministic builds.'
