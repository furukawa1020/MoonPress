#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '{}\n' > "$tmp/site/site.json"
printf '# Original\n' > "$tmp/site/content/a.md"
printf 'original' > "$tmp/site/public/a.png"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fail.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_media_open.c -ldl -o "$tmp/stream.so"
for operation in settings media post; do
  case "$operation" in
    settings) target="$tmp/site/site.json"; stage="$tmp/site/.moonpress-settings-edit" ;;
    media) target="$tmp/site/public/a.png"; stage="$tmp/site/public/.moonpress-media-edit" ;;
    post) target="$tmp/site/content/a.md"; stage="$tmp/site/content/.moonpress-edit" ;;
  esac
  version="$(sha256sum "$target" | cut -d ' ' -f1)"
  cp "$target" "$tmp/before"
  for fault in OPEN WRITE FLUSH CLOSE READ RENAME; do
    path="$stage"; [[ "$fault" != RENAME ]] || path="$target"
    env LD_PRELOAD="$tmp/fail.so" "MOONPRESS_TEST_FAIL_$fault=$path" MOONPRESS_AUTHORING_PROBE="$tmp/site" MOONPRESS_AUTHORING_OPERATION="$operation" MOONPRESS_AUTHORING_VERSION="$version" MOONPRESS_AUTHORING_STAGE="$stage" moon test --target native --filter 'retained authoring descriptors close on repeated failures'
    cmp "$target" "$tmp/before"
    test ! -e "$stage"
  done
  env LD_PRELOAD="$tmp/stream.so" MOONPRESS_TEST_MEDIA_SWAP=fail-stream MOONPRESS_TEST_MEDIA_TARGET="$stage" MOONPRESS_AUTHORING_PROBE="$tmp/site" MOONPRESS_AUTHORING_OPERATION="$operation" MOONPRESS_AUTHORING_VERSION="$version" MOONPRESS_AUTHORING_STAGE="$stage" moon test --target native --filter 'retained authoring descriptors close on repeated failures'
  if [[ "$operation" != media ]]; then
    env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_FAIL_READ="$target" MOONPRESS_AUTHORING_PROBE="$tmp/site" MOONPRESS_AUTHORING_OPERATION="$operation-read" MOONPRESS_AUTHORING_VERSION="$version" MOONPRESS_AUTHORING_STAGE="$stage" moon test --target native --filter 'retained authoring descriptors close on repeated failures'
  fi
done
echo 'Authoring descriptor tests passed: no fd growth across repeated snapshot/stage/write/close/read/publication failures.'
