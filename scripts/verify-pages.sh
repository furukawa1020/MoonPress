#!/usr/bin/env bash
# Compare every public artifact; optionally wait for CDN propagation.
set -euo pipefail
bundle="${1:?validated public bundle required}"
url="${2:?public base URL required}"
budget="${3:-0}"
case "$url" in http://*|https://*) ;; *) echo 'Expected HTTP(S) base URL' >&2; exit 1 ;; esac
if [[ ! "$budget" =~ ^[0-9]{1,3}$ ]] || ((10#$budget > 600)); then
  echo 'Verification budget must be 0..600 seconds' >&2; exit 2
fi
budget=$((10#$budget))
deadline=$((SECONDS + budget))
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mapfile -d '' files < <(find "$bundle" -maxdepth 1 -type f -print0 | sort -z)
test "${#files[@]}" -gt 0
nonce="$(date +%s)-$$"
attempt=0
while true; do
  attempt=$((attempt + 1))
  complete=true
  for file in "${files[@]}"; do
    remaining=120
    if ((budget > 0)); then
      remaining=$((deadline - SECONDS))
      if ((remaining <= 0)); then echo 'Public artifact verification timed out' >&2; exit 1; fi
    fi
    name="${file##*/}"
    encoded="$(printf '%s' "$name" | jq -sRr @uri)"
    if ! timeout "$remaining" curl --fail --silent --show-error --location \
      --proto '=http,https' --proto-redir '=http,https' \
      --connect-timeout 10 --max-time 30 --retry 2 --retry-max-time 90 \
      --url "${url%/}/$encoded?moonpress_verify=$nonce-$attempt" -o "$work/received" || \
      ! cmp -s -- "$file" "$work/received"; then
      printf 'Published artifact not ready: %s\n' "$name" >&2
      complete=false
      break
    fi
  done
  if [[ "$complete" == true ]]; then
    printf 'Verified %s public artifacts at %s\n' "${#files[@]}" "$url"
    exit 0
  fi
  remaining=$((deadline - SECONDS))
  if ((budget == 0 || remaining <= 0)); then exit 1; fi
  delay=5
  if ((remaining < delay)); then delay="$remaining"; fi
  sleep "$delay"
done
