#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/site/content"
printf '<a href="target.html">Target</a>{{content}}' > "$tmp/site/layout.html"
printf 'body{}' > "$tmp/site/style.css"
printf '%s\n' '# Home' '[target](target.html#mp-target)' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"slug":"target","listed":false}' '---' '# Target' > "$tmp/site/content/renamed.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '[target](target.html)' > "$tmp/site/content/draft.md"
for attempt in {1..10}; do
  port="$(shuf -i 20000-55000 -n 1)"
  "$cli" admin "$tmp/site" "$port" > "$tmp/log" 2> "$tmp/error" &
  server=$!
  for ((i=0; i<50; i++)); do
    grep -Fq 'MoonPress admin:' "$tmp/log" && break
    kill -0 "$server" 2>/dev/null || break
    sleep 0.02
  done
  if grep -Fq 'MoonPress admin:' "$tmp/log"; then break; fi
  wait "$server" || true; server=''
done
test -n "$server"
get() { curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' "http://127.0.0.1:$port$1"; }
cp -a "$tmp/site" "$tmp/before"
test "$(get '/edit?name=renamed.md')" = 200
grep -Fq '/references?name=renamed.md' "$tmp/page"
test "$(get '/references?name=renamed.md')" = 200
grep -Fq 'Output: <code>target.html</code>' "$tmp/page"
grep -Fq '/edit?name=index.md' "$tmp/page"
grep -Fq '<code>layout.html</code>' "$tmp/page"
grep -Fq 'mp-target' "$tmp/page"
! grep -Fq '/edit?name=draft.md' "$tmp/page"
"$cli" backlinks "$tmp/site" target.html --json > "$tmp/query"
incoming="$(jq '.report.incoming|length' "$tmp/query")"
outgoing="$(jq '.report.outgoing|length' "$tmp/query")"
grep -Fq "Incoming references ($incoming)" "$tmp/page"
grep -Fq "Outgoing references ($outgoing)" "$tmp/page"
test "$(get '/references?name=renamed.md&scope=all')" = 200
grep -Fq '/edit?name=draft.md' "$tmp/page"
grep -Fq 'Current scope: including drafts' "$tmp/page"
test "$(get '/references?name=draft.md')" = 200
grep -Fq 'This draft is excluded' "$tmp/page"
test "$(get '/references?name=draft.md&scope=all')" = 200
grep -Fq 'Outgoing references' "$tmp/page"
for path in '/references?name=renamed.md&scope=bad' '/references?name=renamed.md&unknown=x' '/references?scope=all' '/references?name=renamed.md&name=index.md' '/references?name=..%2Fsecret.md'; do
  test "$(get "$path")" = 400
done
test "$(get '/target.html')" = 404
diff -r "$tmp/before" "$tmp/site"
printf '\n[broken](missing.html)\n' >> "$tmp/site/content/draft.md"
cp -a "$tmp/site" "$tmp/broken-before"
test "$(get '/references?name=renamed.md')" = 200
test "$(get '/references?name=renamed.md&scope=all')" = 400
grep -Fq 'No complete reference report is available' "$tmp/page"
grep -Fq 'broken internal link' "$tmp/page"
grep -Fq '/edit?name=renamed.md' "$tmp/page"
! grep -Fq 'Incoming references (0)' "$tmp/page"
diff -r "$tmp/broken-before" "$tmp/site"
test ! -e "$tmp/site/.moonpress-build"
test ! -e "$tmp/site/.moonpress-preview"
# With no ready articles, the excluded draft notice still offers the valid scope.
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '[target](target.html)' > "$tmp/site/content/draft.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Home' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"draft":true,"slug":"target"}' '---' '# Target' > "$tmp/site/content/renamed.md"
cp -a "$tmp/site" "$tmp/all-drafts"
test "$(get '/references?name=draft.md')" = 200
grep -Fq 'This draft is excluded' "$tmp/page"
grep -Fq 'Include saved drafts' "$tmp/page"
! grep -Fq 'Incoming references (0)' "$tmp/page"
test "$(get '/references?name=draft.md&scope=all')" = 200
grep -Fq 'Outgoing references' "$tmp/page"
diff -r "$tmp/all-drafts" "$tmp/site"
echo 'Admin reference tests passed: source-to-slug mapping, CLI counts, selected template evidence, draft scopes, read-only GETs, invalid queries and explicit validation failures.'
