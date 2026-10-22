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
"$cli" new "$tmp/site" kind-demo 'Kind demo' >/dev/null
"$cli" history-enable "$tmp/site" >/dev/null
version="$("$cli" read "$tmp/site" kind-demo.md --json | jq -r '.report.digest')"
"$cli" post-kind "$tmp/site" kind-demo.md "$version" page --json | jq -e '.report.changed' >/dev/null
"$cli" posts "$tmp/site" --json | jq -e '.report.posts[]|select(.source=="content/kind-demo.md")|.kind=="page"' >/dev/null
if "$cli" post-kind "$tmp/site" kind-demo.md "$version" post > "$tmp/stale" 2>&1; then exit 1; fi
test "$(get '/edit?name=kind-demo.md')" = 200
token="$(sed -n 's/.*name="token" value="\([^" ]*\)".*/\1/p' "$tmp/page" | head -1)"
grep -Fq 'action="/kind"' "$tmp/page"
version="$("$cli" read "$tmp/site" kind-demo.md --json | jq -r '.report.digest')"
post() { curl --max-time 10 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data-urlencode "token=$token" "$@"; }
test "$(post --data-urlencode name=kind-demo.md --data-urlencode "version=$version" --data-urlencode kind=post "$origin/kind")" = 200
"$cli" posts "$tmp/site" --json | jq -e '.report.posts[]|select(.source=="content/kind-demo.md")|.kind=="post"' >/dev/null
test "$(get '/?kind=page')" = 200
! grep -Fq 'href="/edit?name=kind-demo.md"' "$tmp/page"
test "$(get '/?kind=post')" = 200
grep -Fq 'href="/edit?name=kind-demo.md"' "$tmp/page"
test "$(get '/?kind=bogus')" = 400
"$cli" history "$tmp/site" kind-demo.md --json | jq -e '.report|length==2' >/dev/null
echo 'Kind controls passed: native/HTTP changes, stale refusal, inventory filters and retained preimages.'
