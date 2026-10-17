#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/swap.so"
for state in absent existing; do
  mkdir "$tmp/site" "$tmp/foreign"
  printf '{"tag_index":true}' > "$tmp/foreign/site.json"
  [[ "$state" = absent ]] || printf '{}\n' > "$tmp/site/site.json"
  cp -a "$tmp/foreign" "$tmp/before"
  env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_DIRECTORY="$tmp/site" MOONPRESS_SWAP_MOVED="$tmp/moved" MOONPRESS_SWAP_FOREIGN="$tmp/foreign" "$cli" settings-read "$tmp/site" --json > "$tmp/result"
  if [[ "$state" = absent ]]; then jq -e '.report.exists|not' "$tmp/result" >/dev/null
  else jq -e '.report.content=="{}\n"' "$tmp/result" >/dev/null; fi
  diff -r "$tmp/before" "$tmp/foreign"
  rm "$tmp/site"; rm -r "$tmp/moved" "$tmp/foreign" "$tmp/before"
done
echo 'Settings directory snapshots passed: retained absence and existing bytes after root replacement.'
for state in absent existing; do
  mkdir "$tmp/site" "$tmp/foreign"
  printf '{"tag_index":false}' > "$tmp/foreign/site.json"
  printf '{"tag_index":true}' > "$tmp/new"
  expected=absent
  if [[ "$state" = existing ]]; then
    printf '{}\n' > "$tmp/site/site.json"
    chmod 640 "$tmp/site/site.json"
    expected="$(sha256sum "$tmp/site/site.json" | cut -d ' ' -f1)"
  fi
  cp -a "$tmp/foreign" "$tmp/before"
  env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_DIRECTORY="$tmp/site" MOONPRESS_SWAP_MOVED="$tmp/moved" MOONPRESS_SWAP_FOREIGN="$tmp/foreign" "$cli" settings-save "$tmp/site" "$expected" "$tmp/new" --json > "$tmp/result"
  cmp "$tmp/moved/site.json" "$tmp/new"
  diff -r "$tmp/before" "$tmp/foreign"
  test ! -e "$tmp/moved/.moonpress-settings-edit"
  [[ "$state" = absent ]] || test "$(stat -c %a "$tmp/moved/site.json")" = 640
  rm "$tmp/site"; rm -r "$tmp/moved" "$tmp/foreign" "$tmp/before"
done
echo 'Settings directory writes passed: locked initial/existing saves target the retained directory only.'
