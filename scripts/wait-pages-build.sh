#!/usr/bin/env bash
set -euo pipefail
repository="${1:?repository required}"
expected="${2:?expected commit required}"
budget="${3:-150}"
if [[ ! "$budget" =~ ^[0-9]{1,3}$ ]] || ((10#$budget < 1 || 10#$budget > 600)); then
  echo 'Pages build wait budget must be 1..600 seconds.' >&2
  exit 2
fi
budget=$((10#$budget))
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
deadline=$((SECONDS + budget))
while (( SECONDS < deadline )); do
  remaining=$((deadline - SECONDS))
  if timeout "$remaining" gh api "repos/$repository/pages/builds/latest" > "$work/status.json"; then
    state="$(jq -r .status "$work/status.json")"
    deployed="$(jq -r .commit "$work/status.json")"
    if [[ "$deployed" == "$expected" && "$state" == built ]]; then exit 0; fi
    if [[ "$deployed" == "$expected" && "$state" == errored ]]; then
      jq .error "$work/status.json" >&2
      exit 1
    fi
  fi
  remaining=$((deadline - SECONDS))
  if ((remaining > 0)); then sleep 1; fi
done
echo 'Pages deployment timed out; inspect Pages build status.' >&2
exit 1
