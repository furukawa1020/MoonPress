#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
for attempt in {1..10}; do
  port="$(shuf -i 20000-55000 -n 1)"
  "$cli" admin "$tmp/site" "$port" > "$tmp/log" 2> "$tmp/error" & server=$!
  for ((i=0; i<50; i++)); do grep -Fq 'MoonPress admin:' "$tmp/log" && break; kill -0 "$server" 2>/dev/null || break; sleep 0.02; done
  if grep -Fq 'MoonPress admin:' "$tmp/log"; then break; fi
  wait "$server" || true; server=''
done
test -n "$server"
origin="http://127.0.0.1:$port"
get() { curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' "$origin$1"; }
test "$(get '/history?name=index.md')" = 200
grep -Fq 'Enable article history' "$tmp/page"
token="$(sed -n 's/.*name="token" value="\([^" ]*\)".*/\1/p' "$tmp/page" | head -1)"
post() { curl --max-time 10 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data-urlencode "token=$token" "$@"; }
test "$(post --data-urlencode name=index.md "$origin/history-enable")" = 200
version="$("$cli" read "$tmp/site" index.md --json | jq -r '.report.digest')"
test "$(post --data-urlencode name=index.md --data-urlencode "version=$version" "$origin/checkpoint")" = 200
id="$("$cli" history "$tmp/site" index.md --json | jq -r '.report[0].id')"
printf '# Updated\n' > "$tmp/new-source"
"$cli" save "$tmp/site" index.md "$version" "$tmp/new-source" >/dev/null
"$cli" compare-revision "$tmp/site" index.md "$id" --json | jq -e '[.report.lines[].action] | index("add") != null' >/dev/null
test "$(get "/revision-diff?name=index.md&id=$id")" = 200
grep -Fq 'Revision comparison' "$tmp/page"
current="$("$cli" read "$tmp/site" index.md --json | jq -r '.report.digest')"
test "$(get "/revision?name=index.md&id=$id")" = 200
grep -Fq 'Restore this reviewed version' "$tmp/page"
cp -a "$tmp/site" "$tmp/before-history-get"
test "$(get '/history?name=index.md')" = 200
diff -r "$tmp/site" "$tmp/before-history-get"
test "$(post --data-urlencode name=index.md --data-urlencode "version=$version" --data-urlencode "id=$id" "$origin/restore-revision")" = 400
test "$(post --data-urlencode name=index.md --data-urlencode "version=$current" --data-urlencode "id=$id" "$origin/restore-revision")" = 200
"$cli" read "$tmp/site" index.md --json | jq -e '.report.content | contains("Welcome")' >/dev/null
echo 'Browser history HTTP passed: explicit enable/checkpoint, read-only list/detail, stale refusal and actual restore.'
