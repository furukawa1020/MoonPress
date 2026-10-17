#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/swap.so"
for boundary in root content; do
  mkdir -p "$tmp/site/content" "$tmp/foreign/content"
  printf '# Original\n' > "$tmp/site/content/a.md"
  printf '# Replacement\n' > "$tmp/replacement"
  printf 'foreign' > "$tmp/foreign/a.md"
  printf 'foreign' > "$tmp/foreign/content/a.md"
  printf 'foreign stage' > "$tmp/foreign/.moonpress-edit"
  printf 'foreign stage' > "$tmp/foreign/content/.moonpress-edit"
  cp -a "$tmp/foreign" "$tmp/before"
  version="$(sha256sum "$tmp/site/content/a.md" | cut -d ' ' -f1)"
  chmod 640 "$tmp/site/content/a.md"
  swap="$tmp/site"; result="$tmp/moved/content/a.md"
  if [[ "$boundary" = content ]]; then swap="$tmp/site/content"; result="$tmp/moved/a.md"; fi
  env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_DIRECTORY="$swap" MOONPRESS_SWAP_MOVED="$tmp/moved" MOONPRESS_SWAP_FOREIGN="$tmp/foreign" "$cli" save "$tmp/site" a.md "$version" "$tmp/replacement" --json > "$tmp/result"
  cmp "$tmp/replacement" "$result"
  test "$(stat -c %a "$result")" = 640
  test ! -e "$(dirname "$result")/.moonpress-edit"
  diff -r "$tmp/foreign" "$tmp/before"
  rm "$swap"
  [[ "$boundary" = root ]] || rmdir "$tmp/site"
  rm -r "$tmp/moved" "$tmp/foreign" "$tmp/before"
done
# Closed staged post bytes must be checked before publication or cleanup.
mkdir -p "$tmp/site/content"
printf '# Original\n' > "$tmp/site/content/a.md"
printf '# Replacement\n' > "$tmp/replacement"
version="$(sha256sum "$tmp/site/content/a.md" | cut -d ' ' -f1)"
cp "$tmp/site/content/a.md" "$tmp/original"
stage="$tmp/site/content/.moonpress-edit"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/change_media_stage.c -ldl -o "$tmp/stage.so"
for action in edit symlink directory remove; do
  code=0
  env LD_PRELOAD="$tmp/stage.so" MOONPRESS_TEST_MEDIA_STAGE="$stage" MOONPRESS_TEST_STAGE_ACTION="$action" MOONPRESS_TEST_STAGE_LINK="$tmp/replacement" "$cli" save "$tmp/site" a.md "$version" "$tmp/replacement" --json > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
  test "$code" = 1; test ! -s "$tmp/stdout"
  grep -Fq 'unverified staging retained' "$tmp/stderr"
  cmp "$tmp/original" "$tmp/site/content/a.md"
  case "$action" in
    edit) test "$(cat "$stage")" = 'foreign staged bytes'; rm "$stage" ;;
    symlink) test -L "$stage"; rm "$stage" ;;
    directory) test -d "$stage"; rmdir "$stage" ;;
    remove) test ! -e "$stage" ;;
  esac
done
ln -s "$tmp/site" "$tmp/alias"
if "$cli" read "$tmp/alias/." a.md > "$tmp/stdout" 2> "$tmp/stderr"; then exit 1; fi
test ! -s "$tmp/stdout"
echo 'Post directory tests passed: root/content swaps preserve unrelated posts and staging.'
