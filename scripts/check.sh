#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
moon check --target native
moon test --target native
moon build --target native --release
bash scripts/smoke.sh
bash scripts/incremental-test.sh
