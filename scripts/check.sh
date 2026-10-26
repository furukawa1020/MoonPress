#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/setup-test.sh
moon check --target native
moon test --target native
moon build --target native --release
bash scripts/smoke.sh
bash scripts/site-zip-test.sh
bash scripts/site-export-test.sh
bash scripts/export-cli-test.sh
bash scripts/admin-export-test.sh
bash scripts/export-failure-test.sh
bash scripts/export-alias-race-test.sh
bash scripts/package-native-test.sh
bash scripts/package-provenance-test.sh
bash scripts/cli-help-test.sh
bash scripts/init-test.sh
bash scripts/posts-test.sh
bash scripts/media-test.sh
bash scripts/media-removal-plan-test.sh
bash scripts/media-remove-test.sh
bash scripts/media-removal-cli-test.sh
bash scripts/admin-media-removal-test.sh
bash scripts/media-removal-failure-test.sh
bash scripts/media-snapshot-test.sh
bash scripts/media-preview-api-test.sh
bash scripts/media-preview-guard-test.sh
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
python3 scripts/http-buffer-test.py
bash scripts/admin-test.sh
bash scripts/admin-language-test.sh
bash scripts/preview-server-test.sh
bash scripts/admin-preview-server-test.sh
bash scripts/publish-readiness-test.sh
bash scripts/first-site-journey-test.sh
bash scripts/admin-references-test.sh
bash scripts/admin-output-references-test.sh
bash scripts/admin-media-replace-test.sh
bash scripts/admin-media-image-test.sh
bash scripts/media-preview-journey-test.sh
bash scripts/local-config-test.sh
bash scripts/settings-snapshot-test.sh
bash scripts/settings-directory-test.sh
bash scripts/settings-save-api-test.sh
bash scripts/settings-cli-test.sh
bash scripts/admin-settings-test.sh
bash scripts/settings-fault-test.sh
bash scripts/settings-transitions-test.sh
bash scripts/admin-authoring-recovery-test.sh
bash scripts/authoring-vault-test.sh
bash scripts/post-history-test.sh
bash scripts/post-trash-test.sh
bash scripts/trash-cli-test.sh
bash scripts/admin-trash-test.sh
bash scripts/history-cli-test.sh
bash scripts/admin-history-test.sh
bash scripts/authoring-recovery-test.sh
bash scripts/authoring-atomic-test.sh
bash scripts/authoring-sync-test.sh
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
bash scripts/audit-recovery-test.sh
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
bash scripts/recovery-cleanup-test.sh
bash scripts/recovery-record-test.sh
bash scripts/recovery-preparation-test.sh
bash scripts/atomic-publication-test.sh
bash scripts/recovery-inspection-test.sh
bash scripts/recovery-reader-lock-test.sh
bash scripts/recovery-plan-cli-test.sh
bash scripts/recovery-limits-test.sh
bash scripts/admin-recovery-test.sh

bash scripts/io-cleanup-test.sh

bash scripts/utf8-input-test.sh
bash scripts/pages-package-test.sh
bash scripts/pages-verify-test.sh
bash scripts/publication-sync-test.sh
bash scripts/publication-commit-sync-test.sh

bash scripts/admin-rooms-test.sh

bash scripts/post-kind-test.sh

bash scripts/admin-kind-test.sh

bash scripts/categories-test.sh

bash scripts/category-archives-test.sh

bash scripts/shared-fixture-test.sh

bash scripts/benchmark-report-test.sh

python3 scripts/capacity-test.py

python3 scripts/capacity-report-test.py

python3 scripts/schedule-test.py

python3 scripts/wxr-export-test.py

python3 scripts/wxr-import-test.py

python3 scripts/access-test.py

python3 scripts/rest-test.py

python3 scripts/rest-edit-test.py

python3 scripts/rest-create-test.py

python3 scripts/rest-trash-test.py
python3 scripts/rest-options-test.py
python3 scripts/rest-search-test.py
python3 scripts/html-intake-test.py

python3 scripts/rest-terms-test.py

python3 scripts/rest-slug-test.py

python3 scripts/rest-history-test.py

python3 scripts/rest-history-restore-test.py

python3 scripts/rest-media-test.py

python3 scripts/rest-media-upload-test.py

python3 scripts/rest-media-replace-test.py

python3 scripts/rest-comment-create-test.py

python3 scripts/rest-comment-read-test.py

python3 scripts/rest-comment-moderate-test.py

python3 scripts/rest-comment-trash-test.py

python3 scripts/rest-settings-test.py
python3 scripts/rest-settings-save-test.py

python3 scripts/rest-conditional-test.py

python3 scripts/rest-taxonomy-test.py

python3 scripts/rest-term-filter-test.py

python3 scripts/rest-media-query-test.py

python3 scripts/rest-comment-query-test.py

python3 scripts/rest-comment-summary-test.py

python3 scripts/admin-comment-test.py

python3 scripts/static-comment-test.py

python3 scripts/rest-after-test.py

python3 scripts/rest-before-test.py

python3 scripts/rest-search-columns-test.py

python3 scripts/rest-author-order-test.py

python3 scripts/rest-slug-order-test.py

python3 scripts/rest-array-query-test.py

python3 scripts/rest-embed-context-test.py

python3 scripts/rest-envelope-test.py

python3 scripts/rest-put-patch-test.py

python3 scripts/rest-namespace-test.py

python3 scripts/rest-types-test.py

python3 scripts/rest-type-detail-test.py

python3 scripts/rest-type-edit-test.py

python3 scripts/rest-statuses-test.py

python3 scripts/rest-status-detail-test.py

python3 scripts/rest-resource-links-test.py
