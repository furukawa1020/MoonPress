#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/swap.so"
for boundary in root public; do
  mkdir -p "$tmp/site/public" "$tmp/foreign/public"
  printf 'original\000asset' > "$tmp/site/public/a.png"
  printf 'new\377bytes' > "$tmp/replacement"
  printf 'foreign' > "$tmp/foreign/a.png"
  printf 'foreign' > "$tmp/foreign/public/a.png"
  printf 'foreign stage' > "$tmp/foreign/.moonpress-media-edit"
  printf 'foreign stage' > "$tmp/foreign/public/.moonpress-media-edit"
  cp -a "$tmp/foreign" "$tmp/before"
  version="$(sha256sum "$tmp/site/public/a.png" | cut -d ' ' -f1)"
  chmod 640 "$tmp/site/public/a.png"
  swap="$tmp/site"; result="$tmp/moved/public/a.png"
  if [[ "$boundary" = public ]]; then swap="$tmp/site/public"; result="$tmp/moved/a.png"; fi
  env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_DIRECTORY="$swap" MOONPRESS_SWAP_MOVED="$tmp/moved" MOONPRESS_SWAP_FOREIGN="$tmp/foreign" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement" --json > "$tmp/result"
  cmp "$tmp/replacement" "$result"
  test "$(stat -c %a "$result")" = 640
  test ! -e "$(dirname "$result")/.moonpress-media-edit"
  diff -r "$tmp/foreign" "$tmp/before"
  rm "$swap"
  [[ "$boundary" = root ]] || rmdir "$tmp/site"
  rm -r "$tmp/moved" "$tmp/foreign" "$tmp/before"
done
echo 'Media directory tests passed: root/public swaps preserve unrelated assets and staging.'
