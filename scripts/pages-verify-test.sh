#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'if [[ -n "${server:-}" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"' EXIT
mkdir "$tmp/public" "$tmp/expected"
printf '<h1>MoonPress</h1>' > "$tmp/public/index.html"
printf '\000binary\377' > "$tmp/public/space asset.bin"
cp -a "$tmp/public/." "$tmp/expected/"
python3 - "$tmp/public" "$tmp/port" <<'PY' &
import http.server, functools, sys
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=sys.argv[1]))
with open(sys.argv[2],'w') as f: f.write(str(server.server_port))
server.serve_forever()
PY
server=$!
for attempt in $(seq 1 100); do test -s "$tmp/port" && break; sleep .05; done
url="http://127.0.0.1:$(cat "$tmp/port")/"
bash scripts/verify-pages.sh "$tmp/expected" "$url"
printf changed > "$tmp/public/space asset.bin"
status=0
bash scripts/verify-pages.sh "$tmp/expected" "$url" >/dev/null 2>&1 || status=$?
test "$status" -eq 1
rm "$tmp/public/space asset.bin"
status=0
bash scripts/verify-pages.sh "$tmp/expected" "$url" >/dev/null 2>&1 || status=$?
test "$status" -ne 0
echo 'Pages verification passed: binary assets and encoded names checked; wrong or missing bytes rejected.'
