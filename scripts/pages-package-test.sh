#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
bash scripts/prepare-pages.sh "$tmp/out" "$tmp/bundle"
test ! -e "$tmp/bundle/.moonpress.json"
diff -r --exclude=.moonpress.json "$tmp/out" "$tmp/bundle"
rm -r "$tmp/bundle"
for kind in foreign edited symlink; do
  cp -a "$tmp/out" "$tmp/broken"
  case "$kind" in
    foreign) printf secret > "$tmp/broken/private.txt" ;;
    edited) printf changed > "$tmp/broken/index.html" ;;
    symlink) rm "$tmp/broken/index.html"; ln -s "$tmp/out/index.html" "$tmp/broken/index.html" ;;
  esac
  status=0
  bash scripts/prepare-pages.sh "$tmp/broken" "$tmp/bundle" >/dev/null 2>&1 || status=$?
  test "$status" -ne 0
  test ! -e "$tmp/bundle"
  rm -r "$tmp/broken"
done
echo 'Pages packaging passed: exact owned bytes, no local manifest, invalid sources rejected before destination creation.'
