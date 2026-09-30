#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.moon/bin:$PATH"
expected="$(cat .moon-version)"
# Consume the complete output: head can close early and make moon panic on EPIPE.
if ! command -v moon >/dev/null || [[ "$(moon version | sed -n '1p' | cut -d' ' -f2)" != "$expected" ]]; then
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl --fail --silent --show-error --location https://cli.moonbitlang.com/install/unix.sh -o "$installer"
  TAR_OPTIONS=--no-same-owner bash "$installer"
fi
actual="$(moon version | sed -n '1p' | cut -d' ' -f2)"
if [[ "$actual" != "$expected" ]]; then
  echo "Expected moon $expected, received $actual. Review and update .moon-version; do not silently upgrade." >&2
  exit 1
fi
moonc -v | grep -F 'v0.10.14+7d59c7ec9'
moon update
moon version --all
