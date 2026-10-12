#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
printf bytes > "$tmp/site/public/画像 (a).png"
printf pdf > "$tmp/site/public/a.pdf"
printf unused > "$tmp/site/public/unused.txt"
printf '%s\n' '{"base_url":"https://example.org/project/"}' > "$tmp/site/site.json"
printf '%s\n' '---' '{"title":"<draft>","draft":true,"listed":false}' '---' '![one](./%E7%94%BB%E5%83%8F%20%28a%29.png?x=1#f)' '[again](/project/%E7%94%BB%E5%83%8F%20%28a%29.png)' '[pdf](%61.pdf)' '`[code](unused.txt)`' '```' '![code](unused.txt)' '```' > "$tmp/site/content/refs.md"
printf '%s\n' '---' '{"unknown":true}' '---' > "$tmp/site/content/bad.md"
printf '\377' > "$tmp/site/content/bytes.md"
ln -s refs.md "$tmp/site/content/link.md"
mkfifo "$tmp/site/content/fifo.md"
cp -a "$tmp/site" "$tmp/before"
timeout 5 "$cli" media-refs "$tmp/site" --json > "$tmp/report"
jq -e '.schema==1 and .command=="media-refs" and .include_drafts==false and (.report.problems|length)==4' "$tmp/report" >/dev/null
jq -e '.report.assets[] | select(.item.source=="public/画像 (a).png") | (.posts|length)==1 and .posts[0].source=="content/refs.md" and .posts[0].draft and (.posts[0].listed|not)' "$tmp/report" >/dev/null
jq -e '.report.assets[] | select(.item.source=="public/a.pdf") | (.posts|length)==1' "$tmp/report" >/dev/null
jq -e '.report.assets[] | select(.item.source=="public/unused.txt") | .posts==[]' "$tmp/report" >/dev/null
"$cli" media-refs "$tmp/site" > "$tmp/text"
grep -Fq 'Scan diagnostics: 4' "$tmp/text"
grep -Fq 'draft, unlisted' "$tmp/text"
# Avoid reading the FIFO while comparing all other source entries.
diff -r --exclude=fifo.md "$tmp/before" "$tmp/site"
test -p "$tmp/site/content/fifo.md"
"$cli" media-refs --help | grep -Fq 'No --include-drafts option'
for args in '--include-drafts' '--json --json' '--bad'; do
  read -ra options <<< "$args"
  status=0
  "$cli" media-refs "$tmp/site" "${options[@]}" > "$tmp/out" 2> "$tmp/error" || status=$?
  test "$status" = 2; test ! -s "$tmp/out"
done
printf '%s\n' '{"base_url":"invalid"}' > "$tmp/site/site.json"
status=0
"$cli" media-refs "$tmp/site" --json > "$tmp/out" 2> "$tmp/error" || status=$?
test "$status" = 1; test ! -s "$tmp/out"
echo 'Media reference tests passed: encoded routes, drafts, deduplication, code exclusions, diagnostics and read-only CLI.'
