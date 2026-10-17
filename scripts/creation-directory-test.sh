#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/swap.so"
for operation in new duplicate import; do
  mkdir -p "$tmp/site/content" "$tmp/site/public" "$tmp/foreign"
  printf '# Source\n' > "$tmp/site/content/source.md"
  printf 'foreign target' > "$tmp/foreign/new.md"
  printf 'foreign target' > "$tmp/foreign/new.png"
  printf '# Foreign source\n' > "$tmp/foreign/source.md"
  cp -a "$tmp/foreign" "$tmp/before"
  directory="$tmp/site/content"; name=new.md
  case "$operation" in
    new) args=(new "$tmp/site" new 'New article') ;;
    duplicate) version="$(sha256sum "$tmp/site/content/source.md" | cut -d ' ' -f1)"; args=(duplicate "$tmp/site" source.md "$version" new 'Copied') ;;
    import) directory="$tmp/site/public"; name=new.png; printf 'new\000bytes' > "$tmp/image"; args=(import "$tmp/site" "$tmp/image" "$name") ;;
  esac
  env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_PHASE=lock MOONPRESS_SWAP_DIRECTORY="$directory" MOONPRESS_SWAP_MOVED="$tmp/moved" MOONPRESS_SWAP_FOREIGN="$tmp/foreign" "$cli" "${args[@]}" --json > "$tmp/report"
  test -f "$tmp/moved/$name"
  diff -r "$tmp/foreign" "$tmp/before"
  if [[ "$operation" = import ]]; then cmp "$tmp/image" "$tmp/moved/$name"
  else grep -Fq '"draft":true' "$tmp/moved/$name"; fi
  if [[ "$operation" = duplicate ]]; then grep -Fq '# Source' "$tmp/moved/new.md"; fi
  rm "$directory"
  rm -r "$tmp/site" "$tmp/moved" "$tmp/foreign" "$tmp/before"
done
echo 'Creation directory tests passed: new/duplicate/import remain in retained directories and preserve foreign targets.'
