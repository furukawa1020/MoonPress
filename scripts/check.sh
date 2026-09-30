#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
moon check --target native
moon test --target native
moon build --target native --release
bash scripts/smoke.sh
bash scripts/cli-help-test.sh
bash scripts/init-test.sh
bash scripts/incremental-test.sh
bash scripts/content-test.sh
bash scripts/slugs-test.sh
bash scripts/dates-test.sh
bash scripts/layouts-test.sh
bash scripts/title-test.sh
bash scripts/atx-test.sh
bash scripts/emphasis-test.sh
bash scripts/escapes-test.sh
bash scripts/thematic-break-test.sh
bash scripts/navigation-test.sh
bash scripts/feed-test.sh
bash scripts/pagination-test.sh

bash scripts/markdown-test.sh
bash scripts/assets-test.sh
bash scripts/images-test.sh
bash scripts/url-test.sh
bash scripts/toc-test.sh
bash scripts/heading-links-test.sh
bash scripts/fences-test.sh
bash scripts/fence-languages-test.sh
bash scripts/code-spans-test.sh
bash scripts/site-check-test.sh
bash scripts/drafts-test.sh
bash scripts/draft-preview-test.sh

bash scripts/json-report-test.sh

bash scripts/manifest-preflight-test.sh

bash scripts/source-preflight-test.sh

bash scripts/locking-test.sh

bash scripts/publication-test.sh
bash scripts/journal-test.sh
bash scripts/recovery-test.sh

bash scripts/io-cleanup-test.sh

bash scripts/utf8-input-test.sh
