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
test "$(get /authoring-recovery)" = 200
grep -Fq 'lang="ja"' "$tmp/page"
grep -Fq '途中の編集データは見つかりませんでした' "$tmp/page"
test ! -e "$tmp/site/public"
mkdir "$tmp/site/public"
for kind in post media settings; do
  case "$kind" in
    post) stage="$tmp/site/content/.moonpress-edit" ;;
    media) stage="$tmp/site/public/.moonpress-media-edit" ;;
    settings) stage="$tmp/site/.moonpress-settings-edit" ;;
  esac
  printf '<script>PRIVATE STAGED BODY</script>' > "$stage"
  cp -a "$tmp/site" "$tmp/before-$kind"
  test "$(get /authoring-recovery)" = 200
  grep -Fq "$(sha256sum "$stage" | cut -d ' ' -f1)" "$tmp/page"
  grep -Fq "authoring-rescue SITE $kind" "$tmp/page"
  ! grep -Fq 'PRIVATE STAGED BODY' "$tmp/page"
  ! grep -Fq '<form' "$tmp/page"
  diff -r "$tmp/site" "$tmp/before-$kind"
  rm "$stage"
  ln -s "$tmp/site/content/index.md" "$stage"
  test "$(get /authoring-recovery)" = 200
  grep -Fq '確認できません' "$tmp/page"
  test -L "$stage"
  rm "$stage"
done
truncate -s 8388609 "$tmp/site/content/.moonpress-edit"
test "$(get /authoring-recovery)" = 200
grep -Fq 'supported byte-buffer length' "$tmp/page"
test "$(stat -c %s "$tmp/site/content/.moonpress-edit")" = 8388609
test "$(get '/authoring-recovery?site=elsewhere')" = 404
test "$(curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data token=invalid "$origin/authoring-recovery")" = 400
echo 'Authoring recovery screen: read-only bounded inspection, no staged-body disclosure or mutation, unsafe entry refusal.'
