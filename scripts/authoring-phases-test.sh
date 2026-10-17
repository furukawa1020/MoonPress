#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/swap.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
for operation in settings absent media post; do
  for phase in lock create publish cleanup; do
    mkdir -p "$tmp/site/public" "$tmp/site/content" "$tmp/foreign"
    case "$operation" in
      settings|absent) directory="$tmp/site"; name=site.json; staging=.moonpress-settings-edit; printf '{}\n' > "$directory/$name"; printf '{"tag_index":true}\n' > "$tmp/replacement" ;;
      media) directory="$tmp/site/public"; name=a.png; staging=.moonpress-media-edit; printf 'original' > "$directory/$name"; printf 'new\000bytes' > "$tmp/replacement" ;;
      post) directory="$tmp/site/content"; name=a.md; staging=.moonpress-edit; printf '# Original\n' > "$directory/$name"; printf '# Replacement\n' > "$tmp/replacement" ;;
    esac
    cp "$directory/$name" "$tmp/original"
    version="$(sha256sum "$directory/$name" | cut -d ' ' -f1)"
    if [[ "$operation" = absent ]]; then rm "$directory/$name"; version=absent; fi
    printf 'foreign target' > "$tmp/foreign/$name"
    printf 'foreign staging' > "$tmp/foreign/$staging"
    cp -a "$tmp/foreign" "$tmp/before"
    inode="$(stat -c %i "$tmp/foreign/$name")"
    case "$operation" in
      settings|absent) args=(settings-save "$tmp/site" "$version" "$tmp/replacement") ;;
      media) args=(media-replace "$tmp/site" "$name" "$version" "$tmp/replacement") ;;
      post) args=(save "$tmp/site" "$name" "$version" "$tmp/replacement") ;;
    esac
    fault=(); expected=0
    if [[ "$phase" = cleanup && "$operation" != absent ]]; then
      fault=("MOONPRESS_TEST_FAIL_RENAME=$directory/$name"); expected=1
    fi
    code=0
    env LD_PRELOAD="$tmp/swap.so:$tmp/fault.so" MOONPRESS_SWAP_PHASE="$phase" MOONPRESS_SWAP_DIRECTORY="$directory" MOONPRESS_SWAP_MOVED="$tmp/moved" MOONPRESS_SWAP_FOREIGN="$tmp/foreign" "${fault[@]}" "$cli" "${args[@]}" --json > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
    test "$code" = "$expected"
    test -L "$directory"
    diff -r "$tmp/foreign" "$tmp/before"
    test "$(stat -c %i "$tmp/foreign/$name")" = "$inode"
    if [[ "$expected" = 0 ]]; then cmp "$tmp/replacement" "$tmp/moved/$name"
    else cmp "$tmp/original" "$tmp/moved/$name"; test ! -s "$tmp/stdout"; fi
    test ! -e "$tmp/moved/$staging"
    rm "$directory"
    rm -rf "$tmp/site" "$tmp/moved" "$tmp/foreign" "$tmp/before"
  done
done
echo 'Authoring phase tests passed: lock/create/publish/cleanup swaps never redirect settings/media/post mutations or touch foreign inode/stage contents.'
