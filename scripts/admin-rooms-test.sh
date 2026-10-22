#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
trap 'if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
cp -a "$tmp/site" "$tmp/before"
for attempt in {1..10}; do
  port="$(shuf -i 20000-55000 -n 1)"
  "$cli" admin "$tmp/site" "$port" > "$tmp/log" 2> "$tmp/error" & server=$!
  for ((i=0;i<50;i++)); do
    grep -q 'MoonPress admin:' "$tmp/log" && break
    kill -0 "$server" 2>/dev/null || break
    sleep .02
  done
  if grep -q 'MoonPress admin:' "$tmp/log"; then break; fi
  wait "$server" || true; server=''
done
test -n "$server"
grep -Fq "http://127.0.0.1:$port/rooms (Ctrl-C" "$tmp/log"
origin="http://127.0.0.1:$port"
get() { curl --max-time 10 -sS -D "$tmp/headers" -o "$tmp/page" -w '%{http_code}' "$origin$1"; }
for room in '' /write /preview /build /publish; do
  test "$(get "/rooms$room")" = 200
  grep -q 'aria-current="step"' "$tmp/page"
  grep -q 'もちもの' "$tmp/page"
  if grep -Eq '<script|onclick=|javascript:' "$tmp/page"; then exit 1; fi
done
grep -q 'ホスティング：未確認' "$tmp/page"
! grep -q 'action="/export-production"' "$tmp/page"
diff -r "$tmp/site" "$tmp/before"
test "$(get /rooms)" = 200
grep -Fq '公開対象の変更計画を確認する' "$tmp/page"
printf '%s\n' '---' '{"draft":true}' '---' '# Private draft' > "$tmp/site/content/draft.md"
test "$(get /rooms)" = 200
grep -Fq '保存した下書きをプレビューする' "$tmp/page"
test "$(get /rooms/preview)" = 200
grep -Fq 'プレビュー：まだ生成していません' "$tmp/page"
test ! -e "$tmp/site/.moonpress-preview"
"$cli" build "$tmp/site" "$tmp/site/.moonpress-preview" --include-drafts >/dev/null
test "$(get /rooms/preview)" = 200
grep -Fq 'プレビュー：保存済みの記事と一致' "$tmp/page"
printf '\nChanged draft\n' >> "$tmp/site/content/draft.md"
test "$(get /rooms/preview)" = 200
grep -Fq 'プレビュー：再生成が必要' "$tmp/page"
cp "$tmp/site/.moonpress-preview/index.html" "$tmp/original-preview"
printf 'manual edit' >> "$tmp/site/.moonpress-preview/index.html"
test "$(get /rooms/preview)" = 200
grep -Fq 'プレビューを確認できません' "$tmp/page"
cp "$tmp/original-preview" "$tmp/site/.moonpress-preview/index.html"
for target in /rooms/nope '/rooms?complete=1' /assets/nope; do
  test "$(get "$target")" = 404
done
test "$(get /rooms/preview)" = 200
grep -Fq '<button>プレビューをつくる</button>' "$tmp/page"
test "$(get /rooms/build)" = 200
grep -Fq '<button>変更計画をみる</button>' "$tmp/page"
test "$(get '/edit?name=index.md')" = 200
grep -Fq '移動する前に、下の編集内容を保存' "$tmp/page"
grep -Fq 'href="/rooms/preview"' "$tmp/page"
test "$(get /assets/logo.jpg)" = 200
cmp "$tmp/page" docs/assets/social-preview.jpg
test "$(get /assets/font.woff)" = 200
grep -qi 'Content-Type: font/woff' "$tmp/headers"
cmp "$tmp/page" ui-assets/dotgothic16.woff
test "$(get /assets/rooms.webp)" = 200
grep -qi 'Content-Type: image/webp' "$tmp/headers"
cmp "$tmp/page" ui-assets/rooms.webp
test "$(curl --max-time 10 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data 'token=bad' "$origin/rooms/build")" = 400
"$cli" build "$tmp/site" "$tmp/site/.moonpress-build" >/dev/null
test "$(get /rooms)" = 200
grep -Fq '最新の公開用ファイルをもちだす' "$tmp/page"
printf '%s\n' '---' '{bad json}' '---' > "$tmp/site/content/broken.md"
test "$(get /rooms)" = 200
grep -Fq 'まず、要修復の記事を確認する' "$tmp/page"
rm "$tmp/site/content/broken.md"
test "$(get /rooms/publish)" = 200
grep -q 'action="/export-production"' "$tmp/page"
grep -Fq '<button>公開用ZIPをダウンロード</button>' "$tmp/page"
grep -q 'ホスティング：未確認' "$tmp/page"
printf '\nChanged after build\n' >> "$tmp/site/content/index.md"
test "$(get /rooms/publish)" = 200
! grep -q 'action="/export-production"' "$tmp/page"
grep -q '再ビルドが必要' "$tmp/page"
echo 'Room navigation passed: read-only routes, embedded assets, no-JS, fresh readiness and stale export refusal.'
