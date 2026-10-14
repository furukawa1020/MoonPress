#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<a href="index.html">Home</a>{{content}}' > "$tmp/site/layout.html"
printf 'body{}' > "$tmp/site/style.css"
printf '<svg/>' > "$tmp/site/public/a&月.svg"
printf '%s\n' '# Home' '![image](a%26%E6%9C%88.svg)' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' > "$tmp/site/content/draft.md"
printf '%s\n' '{"redirects":{"old.html":"index.html"}}' > "$tmp/site/site.json"
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
test "$(get '/')" = 200
grep -Fq 'href="/reference-outputs"' "$tmp/page"
test "$(get '/reference-outputs')" = 200
grep -Fq 'Other referring outputs' "$tmp/page"
grep -Fq 'output=a%26%E6%9C%88.svg' "$tmp/page"
grep -Fq 'a&amp;月.svg' "$tmp/page"
! grep -Fq '>draft.html</a>' "$tmp/page"
"$cli" reference-summary "$tmp/site" --json > "$tmp/summary"
routes="$(jq '.report.routes|length' "$tmp/summary")"
edges="$(jq '.report.edges' "$tmp/summary")"
grep -Fq "Outputs: $routes; authored edges: $edges." "$tmp/page"
test "$(get '/reference-outputs?scope=all')" = 200
grep -Fq '>draft.html</a>' "$tmp/page"
test "$(get '/reference-outputs?output=a%26%E6%9C%88.svg')" = 200
grep -Fq 'Incoming references (1)' "$tmp/page"
grep -Fq '/edit?name=index.md' "$tmp/page"
grep -Fq '<code>public/a&amp;月.svg</code>' "$tmp/page"
test "$(get '/reference-outputs?output=old.html&scope=all')" = 200
grep -Fq 'Redirect terminal target:' "$tmp/page"
grep -Fq 'scope=all&amp;output=index.html' "$tmp/page"
grep -Fq 'Outgoing references (1)' "$tmp/page"
test "$(get '/reference-outputs?output=articles.html')" = 200
test "$(get '/reference-outputs?output=.nojekyll')" = 200
grep -Fq 'Incoming references (0)' "$tmp/page"
grep -Fq 'does not prove deletion is safe' "$tmp/page"
for path in '/reference-outputs?output=missing.html' '/reference-outputs?scope=bad' '/reference-outputs?output=' '/reference-outputs?unknown=x' '/reference-outputs?page=0' '/reference-outputs?page=99999999' '/reference-outputs?output=index.html&page=1' '/reference-outputs?output=..%2Fsecret' '/reference-outputs?scope=all&scope=ready' '/reference-outputs?output=draft.html'; do
  test "$(get "$path")" = 400
done
test "$(get '/index.html')" = 404
diff -r "$tmp/before" "$tmp/site"
# More than twenty routes: overview pagination keeps inclusive scope.
for i in {1..25}; do printf '# Page %s\n' "$i" > "$tmp/site/content/p$i.md"; done
test "$(get '/reference-outputs?scope=all')" = 200
grep -Fq 'scope=all&amp;page=2' "$tmp/page"
test "$(get '/reference-outputs?scope=all&page=2')" = 200
grep -Fq 'scope=all&amp;page=1' "$tmp/page"
# Invalid included content is explicit, never a successful empty report.
printf '\n[broken](absent.html)\n' >> "$tmp/site/content/draft.md"
cp -a "$tmp/site" "$tmp/invalid"
test "$(get '/reference-outputs')" = 200
test "$(get '/reference-outputs?scope=all')" = 400
grep -Fq 'No complete reference report is available' "$tmp/page"
! grep -Fq 'Outputs: 0' "$tmp/page"
test "$(get '/reference-outputs?scope=all&output=index.html')" = 400
! grep -Fq 'Incoming references (0)' "$tmp/page"
diff -r "$tmp/invalid" "$tmp/site"
test ! -e "$tmp/site/.moonpress-build"
test ! -e "$tmp/site/.moonpress-preview"
echo 'Admin output references tests passed: CLI count parity, encoded asset inspection, redirects, archives, zero rows, scopes, pagination, invalid queries, read-only behavior and validation failures.'
