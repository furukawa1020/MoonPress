#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_media_open.c -ldl -o "$tmp/swap.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/directory.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
mkdir -p "$tmp/outside/public"
printf '\211PNG\r\n\032\nforeign' > "$tmp/outside/public/a.png"
cp "$tmp/outside/public/a.png" "$tmp/outside-before"
for action in asset fifo public fail-stream; do
  site="$tmp/$action"
  mkdir -p "$site/public"
  printf '\211PNG\r\n\032\noriginal' > "$site/public/a.png"
  target="$site/public/a.png"; outside="$tmp/outside/public/a.png"
  if [[ "$action" = public ]]; then target="$site/public"; outside="$tmp/outside/public"; fi
  env LD_PRELOAD="$tmp/swap.so" MOONPRESS_TEST_MEDIA_SWAP="$action" MOONPRESS_TEST_MEDIA_TARGET="$target" MOONPRESS_TEST_MEDIA_OUTSIDE="$outside" MOONPRESS_IMAGE_FAILURE_PROBE="$site" timeout 30 moon test --target native --filter 'media preview refuses substituted paths and closes failed streams'
  cmp "$tmp/outside/public/a.png" "$tmp/outside-before"
done
for kind in root public; do
  site="$tmp/retained-$kind"
  mkdir -p "$site/public"
  printf '\211PNG\r\n\032\noriginal' > "$site/public/a.png"
  target="$site"; outside="$tmp/outside"
  if [[ "$kind" = public ]]; then target="$site/public"; outside="$tmp/outside/public"; fi
  env LD_PRELOAD="$tmp/directory.so" MOONPRESS_SWAP_DIRECTORY="$target" MOONPRESS_SWAP_MOVED="$tmp/moved-$kind" MOONPRESS_SWAP_FOREIGN="$outside" MOONPRESS_IMAGE_DIRECTORY_PROBE="$site" timeout 30 moon test --target native --filter 'media preview retains original directory after replacement'
  test -L "$target"
  cmp "$tmp/outside/public/a.png" "$tmp/outside-before"
done
mkdir -p "$tmp/fault/public"
printf '\211PNG\r\n\032\noriginal' > "$tmp/fault/public/a.png"
for fault in READ SEEK SIZE CLOSE; do
  echo "Media preview fault probe: $fault"
  if ! env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/fault/public/a.png" MOONPRESS_IMAGE_FAILURE_PROBE="$tmp/fault" timeout 30 moon test --target native --filter 'media preview refuses substituted paths and closes failed streams'; then
    nm -D _build/native/debug/test/moonpress.whitebox_test.exe | grep -E 'fread|fseek|ftell|fclose|readlink'
    exit 1
  fi
done
echo 'Media preview guard tests passed: substituted symlinks/FIFOs, retained root/public handles, read/seek/size/close faults and no descriptor growth.'
