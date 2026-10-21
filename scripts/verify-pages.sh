#!/usr/bin/env bash
# Compare every published artifact, including assets and feeds, byte for byte.
set -euo pipefail
bundle="${1:?validated public bundle required}"
url="${2:?public base URL required}"
case "$url" in http://*|https://*) ;; *) echo 'Expected HTTP(S) base URL' >&2; exit 1 ;; esac
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
count=0
while IFS= read -r -d '' file; do
  name="${file##*/}"
  encoded="$(printf '%s' "$name" | jq -sRr @uri)"
  curl --fail --silent --show-error --location --proto '=http,https' --proto-redir '=http,https' \
    --connect-timeout 10 --max-time 30 --retry 2 --retry-max-time 90 \
    --url "${url%/}/$encoded" -o "$work/received"
  if ! cmp -s -- "$file" "$work/received"; then
    printf 'Published artifact differs: %s\n' "$name" >&2
    exit 1
  fi
  count=$((count + 1))
done < <(find "$bundle" -maxdepth 1 -type f -print0 | sort -z)
test "$count" -gt 0
printf 'Verified %s public artifacts at %s\n' "$count" "$url"
