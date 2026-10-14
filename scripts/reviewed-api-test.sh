#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
MOONPRESS_REVIEW_PROBE="$tmp" moon test --target native --filter 'reviewed publication filesystem probe'
echo 'Reviewed API tests passed: read-only deterministic review, stale refusal, exact report, replay and no-op.'
