#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
writer=''
cleanup() {
  if [[ -n "$writer" ]]; then kill -KILL "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir "$tmp/projects"
failure() {
  local expected="$1" status=0
  shift
  "$@" >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" = "$expected"
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
"$cli" init "$tmp/projects/My 月 site/" --json > "$tmp/report"
jq -e --arg directory "$tmp/projects/My 月 site" '.schema == 1 and .command == "init" and .include_drafts == false and .report.directory == $directory and (.report.files | sort) == ["README.md","content/guide.md","content/index.md","layout.html","layouts/post.html","site.json","style.css"]' "$tmp/report" >/dev/null
site="$tmp/projects/My 月 site"
"$cli" init "$tmp/projects/second" > "$tmp/text"
grep -Fq '7 files' "$tmp/text"
diff -r "$site" "$tmp/projects/second"
"$cli" check "$site" --json | jq -e '.report.pages == 2' >/dev/null
"$cli" build "$site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/sitemap.xml"
grep -Fq 'href="tags.html"' "$tmp/out/index.html"
grep -Fq 'guide</a>' "$tmp/out/tags.html"
if grep -Fq 'href="index.html">My MoonPress site</a></li>' "$tmp/out/articles.html"; then exit 1; fi
"$cli" build "$site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
! find "$site" "$tmp/out" -type f \( -name '*.js' -o -name '*.ts' \) | grep .
cp -a "$site" "$tmp/before"
failure 1 "$cli" init "$site" --json
diff -r "$site" "$tmp/before"
mkdir "$tmp/empty"
printf 'precious\n' > "$tmp/file"
ln -s "$site" "$tmp/link"
ln -s "$tmp/missing" "$tmp/dangling"
mkfifo "$tmp/fifo"
for target in "$tmp/empty" "$tmp/file" "$tmp/link/" "$tmp/dangling" "$tmp/fifo" / '' "$tmp/missing/child"; do
  failure 1 timeout 10 "$cli" init "$target"
done
test "$(cat "$tmp/file")" = precious
test -z "$(find "$tmp/empty" -mindepth 1 -print -quit)"
test -L "$tmp/link" && test -L "$tmp/dangling" && test -p "$tmp/fifo"
test ! -e "$tmp/missing"
diff -r "$site" "$tmp/before"
for flag in --help -h; do
  "$cli" init "$flag" > "$tmp/help"
  grep -Fq 'Usage: moonpress init <site-directory> [--json]' "$tmp/help"
  grep -Fq 'No --include-drafts option' "$tmp/help"
  failure 2 "$cli" init "$flag" --json
done
failure 2 "$cli" init
failure 2 "$cli" init "$tmp/invalid" --force
failure 2 "$cli" init "$tmp/invalid" --include-drafts
failure 2 "$cli" init "$tmp/invalid" --json --json
failure 2 "$cli" init "$tmp/invalid" extra
failure 2 "$cli" init --json "$tmp/invalid"
test ! -e "$tmp/invalid"
(cd "$tmp/projects" && "$cli" init ./--site >/dev/null)
"$cli" check "$tmp/projects/--site" >/dev/null
# Exercise partial writes, close/flush failures and partial directory creation.
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
for fault in OPEN WRITE FLUSH CLOSE; do
  failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/projects/failed/content/index.md" "$cli" init "$tmp/projects/failed" --json
  grep -Fq 'Site initialization failed:' "$tmp/stderr"
  test ! -e "$tmp/projects/failed"
done
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_MKDIR=$tmp/projects/failed/layouts" "$cli" init "$tmp/projects/failed"
test ! -e "$tmp/projects/failed"
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_WRITE=$tmp/projects/failed/content/index.md" "MOONPRESS_TEST_FAIL_REMOVE=$tmp/projects/failed/layout.html" "$cli" init "$tmp/projects/failed"
grep -Fq 'cleanup incomplete' "$tmp/stderr"
grep -Fq 'File write' "$tmp/stderr"
test -f "$tmp/projects/failed/layout.html"
failure 1 "$cli" init "$tmp/projects/failed"
# Two initializers/builds share the existing native parent lock.
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" \
  LD_PRELOAD="$tmp/pause.so" "$cli" init "$tmp/projects/locked" >"$tmp/first" 2>"$tmp/first-error" &
writer=$!
for ((i=0; i<250; i++)); do
  [[ -f "$tmp/ready" ]] && break
  kill -0 "$writer"
  sleep 0.02
done
test -f "$tmp/ready"
failure 1 "$cli" init "$tmp/projects/locked"
grep -Fq 'Output parent is busy' "$tmp/stderr"
failure 1 "$cli" build "$site" "$tmp/projects/sibling"
test ! -e "$tmp/projects/locked"
test ! -e "$tmp/projects/sibling"
touch "$tmp/release"
wait "$writer"
writer=''
"$cli" check "$tmp/projects/locked" >/dev/null
diff -r "$site" "$tmp/before"
echo 'Init tests passed: deterministic usable starter, CLI reports/grammar, existing-target protection, failure cleanup and competing processes.'
