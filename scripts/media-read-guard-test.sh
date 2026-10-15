#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/swap_media_open.c -ldl -o "$tmp/swap.so"
mkdir -p "$tmp/outside"
printf 'outside private bytes' > "$tmp/outside/a.png"
cp "$tmp/outside/a.png" "$tmp/outside-before"
for command in media-read media-replace; do
  for action in asset fifo public; do
    site="$tmp/$command-$action"
    mkdir -p "$site/public"
    printf 'old bytes' > "$site/public/a.png"
    printf 'new bytes' > "$tmp/replacement"
    version="$("$cli" media-read "$site" a.png --json | jq -r '.report.digest')"
    target="$site/public/a.png"
    outside="$tmp/outside/a.png"
    if [[ "$action" = public ]]; then target="$site/public"; outside="$tmp/outside"; fi
    args=("$command" "$site" a.png)
    if [[ "$command" = media-replace ]]; then args+=("$version" "$tmp/replacement"); fi
    code=0
    env LD_PRELOAD="$tmp/swap.so" MOONPRESS_TEST_MEDIA_SWAP="$action" MOONPRESS_TEST_MEDIA_TARGET="$target" MOONPRESS_TEST_MEDIA_OUTSIDE="$outside" timeout 5 "$cli" "${args[@]}" --json > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
    test "$code" = 1
    test ! -s "$tmp/stdout"
    grep -Fq 'guarded media open' "$tmp/stderr"
    cmp "$tmp/outside/a.png" "$tmp/outside-before"
    if [[ "$action" = public ]]; then
      test -L "$site/public"
      test "$(cat "$site/public.saved/a.png")" = 'old bytes'
      test ! -e "$site/public.saved/.moonpress-media-edit"
    elif [[ "$action" = fifo ]]; then
      test -p "$target"
    else
      test -L "$target"
    fi
  done
done
mkdir -p "$tmp/stream/public"
printf 'old bytes' > "$tmp/stream/public/a.png"
env LD_PRELOAD="$tmp/swap.so" MOONPRESS_TEST_MEDIA_SWAP=fail-stream MOONPRESS_TEST_MEDIA_TARGET="$tmp/stream/public/a.png" MOONPRESS_MEDIA_GUARD_PROBE="$tmp/stream" moon test --target native --filter 'guarded media reader closes descriptors on stream failure'
# Symlinked path components are rejected consistently, not just the final filename.
ln -s "$tmp/stream" "$tmp/alias"
code=0
"$cli" media-read "$tmp/alias/." a.png --json > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
test "$code" = 1
test ! -s "$tmp/stdout"
echo 'Guarded media reads passed: deterministic asset/public symlink swaps and FIFO substitution refused, outside bytes preserved, symlink ancestors rejected and no fd growth on stream failures.'
