#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/public/dir.png"
printf '\211PNG\r\n\032\nfixture' > "$tmp/site/public/a.png"
printf '<svg>not a raster image</svg>' > "$tmp/site/public/wrong.png"
printf '<svg/>' > "$tmp/site/public/a.svg"
cp "$tmp/site/public/a.png" "$tmp/site/public/limit.png"
truncate -s 8388608 "$tmp/site/public/limit.png"
truncate -s 8388609 "$tmp/site/public/huge.png"
ln -s a.png "$tmp/site/public/link.png"
mkfifo "$tmp/site/public/pipe.png"
ln -s "$tmp/site" "$tmp/site/alias"
cp -a "$tmp/site" "$tmp/before"
MOONPRESS_IMAGE_PROBE="$tmp/site" timeout 30 moon test --target native --filter 'media preview guarded filesystem probe'
# Compare regular bytes and metadata without attempting to read the FIFO.
find "$tmp/site" -type f -exec sha256sum {} + | sed "s|$tmp/site|SITE|" > "$tmp/after-sums"
find "$tmp/before" -type f -exec sha256sum {} + | sed "s|$tmp/before|SITE|" > "$tmp/before-sums"
sort "$tmp/after-sums" > "$tmp/a"; sort "$tmp/before-sums" > "$tmp/b"; cmp "$tmp/a" "$tmp/b"
echo 'Media preview API passed: versioned binary snapshots, signature/size restrictions, unsafe kinds and no fd growth or source writes.'
