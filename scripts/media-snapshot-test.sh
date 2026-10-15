#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/public"
printf '\000\377abc' > "$tmp/site/public/月 &a.PNG"
cp -a "$tmp/site" "$tmp/before"
MOONPRESS_MEDIA_SNAPSHOT_PROBE="$tmp/site" moon test --target native --filter 'media snapshot filesystem probe'
diff -r "$tmp/before" "$tmp/site"
ln -s "$tmp/site/public/月 &a.PNG" "$tmp/site/public/link.png"
mkfifo "$tmp/site/public/pipe.png"
mkdir "$tmp/site/public/directory.png" "$tmp/site/linked-site"
ln -s "$tmp/site/public" "$tmp/site/linked-site/public"
MOONPRESS_MEDIA_UNSAFE_PROBE="$tmp/site" timeout 20 moon test --target native --filter 'media snapshot rejects unsafe filesystem kinds'
echo 'Media snapshot API tests passed: binary metadata, inventory parity, encoded URL and read-only behavior.'
