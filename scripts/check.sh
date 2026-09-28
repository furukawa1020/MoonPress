#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
moon check --target native
moon test --target native
moon build --target native --release
bash scripts/smoke.sh
bash scripts/incremental-test.sh
bash scripts/content-test.sh
bash scripts/navigation-test.sh

bash scripts/markdown-test.sh
bash scripts/assets-test.sh
bash scripts/images-test.sh
bash scripts/url-test.sh
bash scripts/toc-test.sh
bash scripts/fences-test.sh
bash scripts/code-spans-test.sh
bash scripts/site-check-test.sh
bash scripts/drafts-test.sh
