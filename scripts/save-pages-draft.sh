#!/usr/bin/env bash
set -euo pipefail

[[ ${GITHUB_REF:-} == refs/heads/main &&
   ${GITHUB_RUN_ID:-} =~ ^[0-9]+$ &&
   ${GITHUB_RUN_ATTEMPT:-} =~ ^[0-9]+$ &&
   ${DRAFT_SLUG:-} =~ ^[a-z0-9]+(-[a-z0-9]+)*$ &&
   ${#DRAFT_SLUG} -le 64 ]]
: "${GITHUB_REPOSITORY:?Expected GitHub repository}"
: "${GITHUB_STEP_SUMMARY:?Expected GitHub Actions summary}"

branch="moonpress-draft-$DRAFT_SLUG-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
file="site/content/$DRAFT_SLUG.md"
git diff --cached --quiet
[[ -f "$file" && ! -L "$file" ]]
git add -- "$file"
git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' commit -m "Create Pages draft $DRAFT_SLUG"
git -c credential.helper='!gh auth git-credential' push \
  "--force-with-lease=refs/heads/$branch:" origin "HEAD:refs/heads/$branch"

{
  if [[ ${DRAFT_VISIBILITY:-draft} == ready ]]; then
    printf '## 公開候補を保存しました\n\n'
    printf '1. [PRを作成する](https://github.com/%s/compare/main...%s?expand=1)\n' "$GITHUB_REPOSITORY" "$branch"
    if [[ -n "${DRAFT_PUBLISH_AT:-}" ]]; then
      printf '2. PRの確認結果を読んでマージすると予約が有効になります。時刻以降の公開ジョブで配信されます。\n'
    else
      printf '2. PRの確認結果を読んでマージすると公開されます。\n'
    fi
    printf '3. [公開前に本文を修正する](https://github.com/%s/edit/%s/%s)\n\n' "$GITHUB_REPOSITORY" "$branch" "$file"
  else
    printf '## 下書きを作成しました\n\n'
    printf '1. [編集を開く](https://github.com/%s/edit/%s/%s)\n' "$GITHUB_REPOSITORY" "$branch" "$file"
    printf '2. 本文を書き、公開する版では `draft` を `false` にして、同じブランチへ保存します。\n'
    printf '3. [PRを作成する](https://github.com/%s/compare/main...%s?expand=1)\n\n' "$GITHUB_REPOSITORY" "$branch"
  fi
  printf '公開リポジトリの下書きブランチは閲覧できます。\n'
} >> "$GITHUB_STEP_SUMMARY"
