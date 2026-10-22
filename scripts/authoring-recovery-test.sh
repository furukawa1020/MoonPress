#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public" "$tmp/backups"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
reject() { local code=0; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
for kind in post media settings; do
  case "$kind" in
    post) directory="$tmp/site/content"; name=.moonpress-edit ;;
    media) directory="$tmp/site/public"; name=.moonpress-media-edit ;;
    settings) directory="$tmp/site"; name=.moonpress-settings-edit ;;
  esac
  stage="$directory/$name"
  "$cli" authoring-stage "$tmp/site" "$kind" --json | jq -e '.report.exists|not' >/dev/null
  printf 'staged\000bytes\377' > "$stage"
  cp "$stage" "$tmp/original"
  version="$("$cli" authoring-stage "$tmp/site" "$kind" --json | jq -r '.report.digest')"
  test "$version" = "$(sha256sum "$stage" | cut -d ' ' -f1)"
  reject "$cli" authoring-rescue "$tmp/site" "$kind" "$(printf '%064d' 0)" "$tmp/backups/stale.backup"
  test ! -e "$tmp/backups/stale.backup"
  reject flock "$directory" "$cli" authoring-stage "$tmp/site" "$kind"
  grep -Fq 'busy' "$tmp/stderr"
  reject flock "$directory" "$cli" authoring-rescue "$tmp/site" "$kind" "$version" "$tmp/backups/locked.backup"
  test ! -e "$tmp/backups/locked.backup"
  for fault in WRITE SYNC CLOSE INSTALL; do
    reject env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/backups/fail.backup" "$cli" authoring-rescue "$tmp/site" "$kind" "$version" "$tmp/backups/fail.backup"
    cmp "$stage" "$tmp/original"
    test ! -e "$tmp/backups/fail.backup"
  done
  reject env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_DIR_SYNC="$tmp/backups" "$cli" authoring-rescue "$tmp/site" "$kind" "$version" "$tmp/backups/$kind-uncertain.backup"
  cmp "$stage" "$tmp/backups/$kind-uncertain.backup"
  reject "$cli" authoring-rescue "$tmp/site" "$kind" "$version" "$tmp/backups/$kind-uncertain.backup"
  cmp "$stage" "$tmp/original"
  "$cli" authoring-rescue "$tmp/site" "$kind" "$version" "$tmp/backups/$kind.backup" --json | jq -e '.report.bytes > 0' >/dev/null
  cmp "$tmp/original" "$tmp/backups/$kind.backup"
  test "$(stat -c %a "$tmp/backups/$kind.backup")" = 600
  test ! -e "$stage"
  ln -s "$tmp/original" "$stage"
  reject "$cli" authoring-stage "$tmp/site" "$kind"
  reject "$cli" authoring-rescue "$tmp/site" "$kind" "$version" "$tmp/backups/link.backup"
  test -L "$stage"
  rm "$stage"
done
# Bounded rescue inspection must preserve oversized remnants and accept the limit.
for kind in post media settings; do
  case "$kind" in
    post) stage="$tmp/site/content/.moonpress-edit" ;;
    media) stage="$tmp/site/public/.moonpress-media-edit" ;;
    settings) stage="$tmp/site/.moonpress-settings-edit" ;;
  esac
  truncate -s 8388609 "$stage"
  expected="$(sha256sum "$stage" | cut -d ' ' -f1)"
  reject "$cli" authoring-stage "$tmp/site" "$kind" --json
  grep -Fq 'supported byte-buffer length' "$tmp/stderr"
  reject "$cli" authoring-rescue "$tmp/site" "$kind" "$expected" "$tmp/backups/oversize.backup"
  test ! -e "$tmp/backups/oversize.backup"
  test "$(stat -c %s "$stage")" = 8388609
  truncate -s 8388608 "$stage"
  "$cli" authoring-stage "$tmp/site" "$kind" --json | jq -e '.report.bytes == 8388608' >/dev/null
  expected="$(sha256sum "$stage" | cut -d ' ' -f1)"
  "$cli" authoring-rescue "$tmp/site" "$kind" "$expected" "$tmp/backups/$kind-limit.backup" >/dev/null
  test ! -e "$stage"
  test "$(stat -c %s "$tmp/backups/$kind-limit.backup")" = 8388608
done
# A real interrupted save can be rescued without changing the original article.
printf '# Original\n' > "$tmp/site/content/a.md"
printf '# Replacement\n' > "$tmp/replacement"
version="$(sha256sum "$tmp/site/content/a.md" | cut -d ' ' -f1)"
code=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_BEFORE_RENAME="$tmp/site/content/a.md" "$cli" save "$tmp/site" a.md "$version" "$tmp/replacement" >/dev/null 2>&1 || code=$?
test "$code" = 137
stage="$tmp/site/content/.moonpress-edit"
staged="$("$cli" authoring-stage "$tmp/site" post --json | jq -r '.report.digest')"
code=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_AFTER_SYNC="$tmp/backups" "$cli" authoring-rescue "$tmp/site" post "$staged" "$tmp/backups/interrupted.backup" >/dev/null 2>&1 || code=$?
test "$code" = 137
cmp "$stage" "$tmp/backups/interrupted.backup"
reject env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_DIR_SYNC="$tmp/site/content" "$cli" authoring-rescue "$tmp/site" post "$staged" "$tmp/backups/retry.backup"
grep -Fq 'Removal is visible, but durability is unconfirmed' "$tmp/stderr"
test ! -e "$stage"
cmp "$tmp/replacement" "$tmp/backups/retry.backup"
test "$(sha256sum "$tmp/site/content/a.md" | cut -d ' ' -f1)" = "$version"
"$cli" save "$tmp/site" a.md "$version" "$tmp/replacement" >/dev/null
cmp "$tmp/replacement" "$tmp/site/content/a.md"
for command in authoring-stage authoring-rescue; do
  "$cli" "$command" --help | grep -Fq 'No --include-drafts option'
done
echo 'Authoring recovery passed: digest checks, durable private backups, no overwrite/symlink traversal, interrupted save/rescue and retry.'
