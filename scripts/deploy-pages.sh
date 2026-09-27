#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_REPOSITORY:?Run inside GitHub Actions}"
: "${GITHUB_SHA:?Missing source revision}"
: "${GH_TOKEN:?Missing scoped workflow token}"
source_dir="$(realpath "${1:-dist}")"
test -s "$source_dir/index.html"
test -f "$source_dir/.nojekyll"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
repo="https://github.com/$GITHUB_REPOSITORY.git"
git -C "$work" init -q
if git -C "$work" ls-remote --exit-code "$repo" refs/heads/gh-pages >/dev/null 2>&1; then
  git -C "$work" fetch --depth=1 "$repo" gh-pages
  git -C "$work" checkout --detach FETCH_HEAD
  git -C "$work" rm -rf --ignore-unmatch .
fi
cp -a "$source_dir/." "$work/"
git -C "$work" add .
if ! git -C "$work" diff --cached --quiet || ! git -C "$work" rev-parse HEAD >/dev/null 2>&1; then
  git -C "$work" -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' commit -m "Deploy MoonPress from $GITHUB_SHA"
  git -C "$work" -c credential.helper='!gh auth git-credential' push "$repo" HEAD:refs/heads/gh-pages
fi
# GITHUB_TOKEN cannot create a Pages site. Detect setup rather than pretending
# branch publication means the site has been deployed.
if ! gh api "repos/$GITHUB_REPOSITORY/pages" > "$work/pages.json"; then
  echo "::error::Enable Settings > Pages > Deploy from a branch > gh-pages / (root), then rerun this workflow."
  exit 1
fi
if ! jq -e '.source.branch == "gh-pages" and .source.path == "/"' "$work/pages.json" >/dev/null; then
  echo '::error::Pages source must be gh-pages / (root).'
  exit 1
fi
# Workflow-token pushes do not automatically trigger a Pages build.
gh api --method POST "repos/$GITHUB_REPOSITORY/pages/builds" > "$work/build.json"
for attempt in $(seq 1 30); do
  gh api "repos/$GITHUB_REPOSITORY/pages/builds/latest" > "$work/status.json"
  state="$(jq -r .status "$work/status.json")"
  deployed="$(jq -r .commit "$work/status.json")"
  expected="$(git -C "$work" rev-parse HEAD)"
  if [[ "$deployed" == "$expected" && "$state" == built ]]; then
    url="$(jq -r .html_url "$work/pages.json")"
    curl --fail --silent --show-error --retry 3 "$url" -o "$work/live.html"
    grep -Eq '<h1( [^>]*)?>MoonPress</h1>' "$work/live.html"
    echo "Published: $url"
    exit 0
  fi
  if [[ "$deployed" == "$expected" && "$state" == errored ]]; then
    jq .error "$work/status.json" >&2
    exit 1
  fi
  sleep 5
done
echo '::error::Pages deployment timed out; inspect Pages build status.'
exit 1
