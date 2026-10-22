#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
writer=''
cleanup() { if [[ -n "$writer" ]]; then kill -KILL "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir "$tmp/site"
printf '{}\n' > "$tmp/site/site.json"
printf '{"tag_index":true}\n' > "$tmp/new"
cp "$tmp/site/site.json" "$tmp/original"
version="$(sha256sum "$tmp/original" | cut -d ' ' -f1)"
stage="$tmp/site/.moonpress-settings-edit"
target="$tmp/site/site.json"
chmod 640 "$target"
touch -t 200001010000 "$target"
metadata="$(stat -c '%i %a %Y' "$target")"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fail.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/change_media_stage.c -ldl -o "$tmp/stage.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
reject() { local code=0; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
for operation in OPEN WRITE FLUSH EXISTING_SYNC CLOSE RENAME; do
  path="$stage"; [[ "$operation" = RENAME ]] && path="$target"
  reject env LD_PRELOAD="$tmp/fail.so" "MOONPRESS_TEST_FAIL_$operation=$path" "$cli" settings-save "$tmp/site" "$version" "$tmp/new"
  cmp "$tmp/original" "$target"
  test "$(stat -c '%i %a %Y' "$target")" = "$metadata"
  test ! -e "$stage"
done
reject env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_FAIL_WRITE="$stage" MOONPRESS_TEST_FAIL_REMOVE="$stage" "$cli" settings-save "$tmp/site" "$version" "$tmp/new"
grep -Fq 'cleanup incomplete' "$tmp/stderr"
test -f "$stage"
reject "$cli" settings-save "$tmp/site" "$version" "$tmp/original"
rm "$stage"
# Foreign stage replacements must be preserved, never published or cleaned.
for action in edit symlink directory remove; do
  reject env LD_PRELOAD="$tmp/stage.so" MOONPRESS_TEST_MEDIA_STAGE="$stage" MOONPRESS_TEST_STAGE_ACTION="$action" MOONPRESS_TEST_STAGE_LINK="$tmp/new" "$cli" settings-save "$tmp/site" "$version" "$tmp/new"
  grep -Fq 'unverified staging retained' "$tmp/stderr"
  cmp "$tmp/original" "$target"
  case "$action" in
    edit) test "$(cat "$stage")" = 'foreign staged bytes'; rm "$stage" ;;
    symlink) test -L "$stage"; rm "$stage" ;;
    directory) test -d "$stage"; rmdir "$stage" ;;
    remove) test ! -e "$stage" ;;
  esac
done
reject env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_EDIT_ON_CLOSE="$stage" MOONPRESS_TEST_EDIT_TARGET="$target" "$cli" settings-save "$tmp/site" "$version" "$tmp/new"
test "$(cat "$target")" = '# External edit'
test ! -e "$stage"
cp "$tmp/original" "$target"
# A cooperative writer holds the lock; later retries must use the new version.
MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" LD_PRELOAD="$tmp/pause.so" "$cli" settings-save "$tmp/site" "$version" "$tmp/new" > "$tmp/writer-out" 2> "$tmp/writer-error" &
writer=$!
for ((i=0;i<250;i++)); do [[ -e "$tmp/ready" ]] && break; kill -0 "$writer"; sleep .02; done
test -e "$tmp/ready"
reject "$cli" settings-save "$tmp/site" "$version" "$tmp/new"
touch "$tmp/release"
wait "$writer"; writer=''
reject "$cli" settings-save "$tmp/site" "$version" "$tmp/original"
cmp "$tmp/new" "$target"
# Exclusive initial publication cannot overwrite a late external target.
rm "$target"
reject env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_FAIL_LINK="$target" "$cli" settings-save "$tmp/site" absent "$tmp/new"
test ! -e "$target"; test ! -e "$stage"
reject env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_CREATE_BEFORE_LINK="$target" "$cli" settings-save "$tmp/site" absent "$tmp/new"
test "$(cat "$target")" = 'competing writer'
test ! -e "$stage"
rm "$target"
reject env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_FAIL_REMOVE="$stage" "$cli" settings-save "$tmp/site" absent "$tmp/new"
grep -Fq 'settings were saved, but staging cleanup failed' "$tmp/stderr"
cmp "$tmp/new" "$target"
test "$(stat -c %i "$target")" = "$(stat -c %i "$stage")"
newversion="$(sha256sum "$target" | cut -d ' ' -f1)"
reject "$cli" settings-save "$tmp/site" "$newversion" "$tmp/new"
rm "$stage"
"$cli" settings-save "$tmp/site" "$newversion" "$tmp/new" --json | jq -e '.report.changed|not' >/dev/null
echo 'Settings fault tests passed: I/O failures, cleanup, foreign staging, external edits, writer locks, exclusive creation and committed cleanup reporting.'
