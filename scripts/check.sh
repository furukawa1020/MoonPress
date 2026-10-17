#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/setup-test.sh
moon check --target native
moon test --target native
moon build --target native --release
bash scripts/smoke.sh
bash scripts/cli-help-test.sh
bash scripts/init-test.sh
bash scripts/posts-test.sh
bash scripts/media-test.sh
bash scripts/media-snapshot-test.sh
bash scripts/media-read-guard-test.sh
bash scripts/media-replace-api-test.sh
bash scripts/media-replace-cli-test.sh
bash scripts/media-stage-test.sh
bash scripts/media-directory-test.sh
bash scripts/media-replace-fault-test.sh
bash scripts/media-references-test.sh
bash scripts/media-import-test.sh
bash scripts/new-post-test.sh
bash scripts/duplicate-post-test.sh
bash scripts/creation-directory-test.sh
bash scripts/post-editor-test.sh
bash scripts/post-directory-test.sh
bash scripts/post-status-test.sh
bash scripts/admin-test.sh
bash scripts/preview-server-test.sh
bash scripts/admin-references-test.sh
bash scripts/admin-output-references-test.sh
bash scripts/admin-media-replace-test.sh
bash scripts/local-config-test.sh
bash scripts/settings-snapshot-test.sh
bash scripts/settings-directory-test.sh
bash scripts/settings-save-api-test.sh
bash scripts/settings-cli-test.sh
bash scripts/admin-settings-test.sh
bash scripts/settings-fault-test.sh
bash scripts/settings-transitions-test.sh
bash scripts/authoring-phases-test.sh
bash scripts/authoring-descriptors-test.sh
bash scripts/incremental-test.sh
bash scripts/routes-test.sh
bash scripts/reference-api-test.sh
bash scripts/references-test.sh
bash scripts/reference-summary-test.sh
bash scripts/reference-summary-transitions-test.sh
bash scripts/reference-transitions-test.sh
bash scripts/redirects-test.sh
bash scripts/content-test.sh
bash scripts/slugs-test.sh
bash scripts/listed-test.sh
bash scripts/dates-test.sh
bash scripts/layouts-test.sh
bash scripts/collection-layout-test.sh
bash scripts/title-test.sh
bash scripts/atx-test.sh
bash scripts/emphasis-test.sh
bash scripts/escapes-test.sh
bash scripts/thematic-break-test.sh
bash scripts/navigation-test.sh
bash scripts/feed-limit-test.sh
bash scripts/feed-test.sh
bash scripts/pagination-test.sh
bash scripts/tag-pagination-test.sh
bash scripts/tag-index-test.sh

bash scripts/tables-test.sh
bash scripts/setext-test.sh
bash scripts/hard-breaks-test.sh
bash scripts/strikethrough-test.sh
bash scripts/task-lists-test.sh
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

bash scripts/strict-state-test.sh
bash scripts/manifest-preflight-test.sh
bash scripts/output-audit-test.sh
bash scripts/build-plan-test.sh
bash scripts/reviewed-api-test.sh
bash scripts/reviewed-cli-test.sh
bash scripts/reviewed-transitions-test.sh
bash scripts/manifest-diff-test.sh
bash scripts/dependencies-test.sh
bash scripts/dependency-impact-test.sh

bash scripts/source-preflight-test.sh

bash scripts/locking-test.sh

bash scripts/publication-test.sh
bash scripts/journal-test.sh
bash scripts/recovery-test.sh

bash scripts/io-cleanup-test.sh

bash scripts/utf8-input-test.sh
