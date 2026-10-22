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
"$cli" new "$tmp/site" trash-demo 'Trash demo' >/dev/null
cp "$tmp/site/content/trash-demo.md" "$tmp/original"
test "$(get '/trash-post?name=trash-demo.md')" = 200
token="$(sed -n 's/.*name="token" value="\([^" ]*\)".*/\1/p' "$tmp/page" | head -1)"
version="$("$cli" read "$tmp/site" trash-demo.md --json | jq -r '.report.digest')"
post() { curl --max-time 10 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data-urlencode "token=$token" "$@"; }
cp -a "$tmp/site" "$tmp/before"
test "$(get /trash)" = 200
diff -r "$tmp/site" "$tmp/before"
test "$(post --data-urlencode name=trash-demo.md --data-urlencode "version=$version" "$origin/trash-post")" = 200
test ! -e "$tmp/site/content/trash-demo.md"
"$cli" trash-list "$tmp/site" --json > "$tmp/list"
id="$(jq -r '.report[0].id' "$tmp/list")"
record="$(jq -r '.report[0].record_digest' "$tmp/list")"
test "$(get "/trash-item?id=$id")" = 200
grep -Fq 'Restore to original filename' "$tmp/page"
test "$(post --data-urlencode "id=$id" --data-urlencode "version=$record" "$origin/trash-restore")" = 200
cmp "$tmp/original" "$tmp/site/content/trash-demo.md"
"$cli" trash-list "$tmp/site" --json | jq -e '.report|length==0' >/dev/null
version="$("$cli" read "$tmp/site" trash-demo.md --json | jq -r '.report.digest')"
test "$(post --data-urlencode name=trash-demo.md --data-urlencode "version=$version" "$origin/trash-post")" = 200
"$cli" trash-list "$tmp/site" --json > "$tmp/list"
id="$(jq -r '.report[0].id' "$tmp/list")"
record="$(jq -r '.report[0].record_digest' "$tmp/list")"
test "$(post --data-urlencode "id=$id" --data-urlencode "version=$record" "$origin/trash-purge")" = 400
test "$(get "/trash-item?id=$id")" = 200
grep -Fq 'Permanently purge reviewed record' "$tmp/page"
test "$(post --data-urlencode "id=$id" --data-urlencode "version=$record" --data-urlencode confirm=permanent "$origin/trash-purge")" = 200
"$cli" trash-list "$tmp/site" --json | jq -e '.report|length==0' >/dev/null
test ! -e "$tmp/site/content/trash-demo.md"
echo 'Browser trash HTTP passed: read-only inventory/review/detail, reviewed move, exact restore and no implicit build.'
