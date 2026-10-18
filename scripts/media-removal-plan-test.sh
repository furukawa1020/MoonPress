#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
MOONPRESS_REMOVAL_PLAN_PROBE="$tmp" moon test --target native --filter 'media removal inspection filesystem probe'
echo 'Media removal plans passed: deterministic IDs, draft/template references, stale bytes, malformed sources and no generated writes.'
