#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/public"
asset="$tmp/site/public/a.png"
stage="$tmp/site/public/.moonpress-media-edit"
printf 'original asset' > "$asset"
printf 'new requested bytes' > "$tmp/replacement"
printf 'foreign target' > "$tmp/foreign"
cp -a "$asset" "$tmp/original"
cp "$tmp/foreign" "$tmp/foreign-before"
version="$("$cli" media-read "$tmp/site" a.png --json | jq -r '.report.digest')"
metadata="$(stat -c '%i %a %Y' "$asset")"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/change_media_stage.c -ldl -o "$tmp/change.so"
for action in edit symlink directory remove; do
  code=0
  env LD_PRELOAD="$tmp/change.so" MOONPRESS_TEST_MEDIA_STAGE="$stage" MOONPRESS_TEST_STAGE_ACTION="$action" MOONPRESS_TEST_STAGE_LINK="$tmp/foreign" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement" --json > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
  test "$code" = 1
  test ! -s "$tmp/stdout"
  grep -Fq 'staging could not be verified' "$tmp/stderr"
  cmp "$asset" "$tmp/original"
  test "$(stat -c '%i %a %Y' "$asset")" = "$metadata"
  cmp "$tmp/foreign" "$tmp/foreign-before"
  case "$action" in
    edit) test "$(cat "$stage")" = 'foreign staged bytes'; rm "$stage" ;;
    symlink) test -L "$stage"; test "$(readlink "$stage")" = "$tmp/foreign"; rm "$stage" ;;
    directory) test -d "$stage"; rmdir "$stage" ;;
    remove) test ! -e "$stage" ;;
  esac
done
"$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement" --json > "$tmp/report"
cmp "$asset" "$tmp/replacement"
test "$(jq -r '.report.item.digest' "$tmp/report")" = "$(sha256sum "$asset" | cut -d ' ' -f1)"
echo 'Media staging tests passed: post-close edits/symlinks/directories/removal refused, foreign remnants preserved, original metadata retained and successful report matches published bytes.'
