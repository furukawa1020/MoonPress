#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() {
  if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
for attempt in {1..10}; do
  port="$(shuf -i 20000-55000 -n 1)"
  "$cli" admin "$tmp/site" "$port" > "$tmp/log" 2> "$tmp/error" &
  server=$!
  for ((i=0; i<50; i++)); do
    grep -Fq 'MoonPress admin:' "$tmp/log" && break
    kill -0 "$server" 2>/dev/null || break
    sleep 0.02
  done
  if grep -Fq 'MoonPress admin:' "$tmp/log"; then break; fi
  wait "$server" || true
  server=''
done
test -n "$server"
origin="http://127.0.0.1:$port"
get() { curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' "$origin$1"; }
post() { local path="$1"; shift; curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" "$@" "$origin$path"; }
test "$(get /)" = 200
grep -Fq 'New draft' "$tmp/page"
token="$(sed -n 's/.*name="token" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "${#token}" = 64
# Guided authoring is read-only, even with malformed sources and absent templates.
cp -a "$tmp/site" "$tmp/before-workflow"
test "$(get /workflow)" = 200
grep -Fq '2 ready for build; 0 drafts; 0 needing repair' "$tmp/page"
for step in '1. Write and save' '2. Preview your saved drafts' '3. Choose what goes live' '4. Review before building' '5. Create production files' '6. Publish and verify'; do
  grep -Fq "$step" "$tmp/page"
done
grep -Fq 'action="/plan-production"' "$tmp/page"
grep -Fq 'href="/#new-draft"' "$tmp/page"
diff -r "$tmp/before-workflow" "$tmp/site"
"$cli" new "$tmp/site" workflow-draft 'Private draft' >/dev/null
printf '%s\n' '---' '{"<script>":true}' '---' > "$tmp/site/content/workflow-bad.md"
mv "$tmp/site/layout.html" "$tmp/site/layout.saved"
cp -a "$tmp/site" "$tmp/workflow-broken"
test "$(get /workflow)" = 200
grep -Fq '2 ready for build; 1 drafts; 1 needing repair' "$tmp/page"
grep -Fq '/edit?name=workflow-bad.md' "$tmp/page"
grep -Fq '&lt;script&gt;' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
diff -r "$tmp/workflow-broken" "$tmp/site"
test ! -e "$tmp/site/.moonpress-build"
test ! -e "$tmp/site/.moonpress-preview"
mv "$tmp/site/layout.saved" "$tmp/site/layout.html"
rm "$tmp/site/content/workflow-draft.md" "$tmp/site/content/workflow-bad.md"
# A fresh site can prepare media storage explicitly without shell setup.
cp -a "$tmp/site" "$tmp/before-media-setup"
test "$(get /media)" = 200
grep -Fq 'Prepare media storage' "$tmp/page"
test ! -e "$tmp/site/public"
diff -r "$tmp/before-media-setup" "$tmp/site"
test "$(post /prepare-media --data-urlencode token=wrong)" = 400
test "$(post /prepare-media --data-urlencode "token=$token" --data-urlencode extra=bad)" = 400
test ! -e "$tmp/site/public"
for kind in file fifo link; do
  case "$kind" in
    file) printf 'existing data' > "$tmp/site/public" ;;
    fifo) mkfifo "$tmp/site/public" ;;
    link) ln -s "$tmp/site/content" "$tmp/site/public" ;;
  esac
  test "$(post /prepare-media --data-urlencode "token=$token")" = 400
  case "$kind" in
    file) test "$(cat "$tmp/site/public")" = 'existing data' ;;
    fifo) test -p "$tmp/site/public" ;;
    link) test -L "$tmp/site/public" ;;
  esac
  rm "$tmp/site/public"
done
test "$(post /prepare-media --data-urlencode "token=$token")" = 200
test -d "$tmp/site/public"
grep -Fq 'Media storage ready' "$tmp/page"
cp -a "$tmp/site" "$tmp/after-media-setup"
test "$(post /prepare-media --data-urlencode "token=$token")" = 200
grep -Fq 'already ready' "$tmp/page"
diff -r "$tmp/after-media-setup" "$tmp/site"
test "$(get /media)" = 200
grep -Fq 'type="file"' "$tmp/page"
cp -a "$tmp/site" "$tmp/before"
test "$(post /new --data-urlencode token=wrong --data-urlencode slug=bad --data-urlencode title=Bad)" = 400
test "$(curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H 'Host: attacker.example' "$origin/")" = 400
test "$(post /new -H 'Origin: https://attacker.example' --data-urlencode "token=$token" --data-urlencode slug=bad --data-urlencode title=Bad)" = 400
test "$(curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' --data-urlencode "token=$token" --data-urlencode slug=bad --data-urlencode title=Bad "$origin/new")" = 400
test "$(get '/new?slug=bad')" = 404
diff -r "$tmp/site" "$tmp/before"
test "$(post /new --data-urlencode "token=$token" --data-urlencode slug=first --data-urlencode 'title=<script>alert("月")</script>')" = 200
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source=="content/first.md")][0].draft' >/dev/null
test "$(get /)" = 200
grep -Fq '&lt;script&gt;' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
test "$(get '/edit?name=first.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
printf '%s\n' '---' '{"title":"Changed","draft":true}' '---' '# Body' '</textarea><script>bad</script>' > "$tmp/replacement"
test "$(post /save --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode "content@$tmp/replacement")" = 200
cmp "$tmp/site/content/first.md" "$tmp/replacement"
test "$(post /save --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode 'content=Keep my unsaved text </textarea><script>')" = 400
grep -Fq 'Keep my unsaved text &lt;/textarea&gt;&lt;script&gt;' "$tmp/page"
cmp "$tmp/site/content/first.md" "$tmp/replacement"
test "$(get '/edit?name=first.md')" = 200
grep -Fq '&lt;/textarea&gt;&lt;script&gt;bad' "$tmp/page"
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
test "$(post /status --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode state=ready)" = 200
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source=="content/first.md")][0].draft == false' >/dev/null
test "$(get '/edit?name=first.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
fields_post() { post /fields --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode 'title=Structured <title>' --data-urlencode 'description=Summary' --data-urlencode 'tags=Moon,Bit' --data-urlencode 'body=# Structured body' --data-urlencode "date=$1"; }
cp "$tmp/site/content/first.md" "$tmp/before-fields"
test "$(fields_post 2026-02-30)" = 400
grep -Fq 'Structured &lt;title&gt;' "$tmp/page"
grep -Fq '# Structured body' "$tmp/page"
cmp "$tmp/before-fields" "$tmp/site/content/first.md"
test "$(fields_post 2026-10-03)" = 200
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source=="content/first.md")][0] | .title=="Structured <title>" and .date=="2026-10-03" and .tags==["Moon,Bit"] and .draft==false' >/dev/null
cp "$tmp/site/content/first.md" "$tmp/after-fields"
test "$(fields_post 2026-10-04)" = 400
grep -Fq 'Post changed since' "$tmp/page"
cmp "$tmp/after-fields" "$tmp/site/content/first.md"
# Preview stale unsaved work without refreshing the version or touching files.
cp -a "$tmp/site" "$tmp/before-preview"
printf '%s\n' '# Preview heading' '' '**Unsaved** </textarea><script>bad</script>' '[next](guide.html) ![alt](image.png)' > "$tmp/preview-body"
test "$(post /preview --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode title=Unsaved --data-urlencode description=Summary --data-urlencode date=invalid --data-urlencode tags=Moon --data-urlencode "body@$tmp/preview-body")" = 200
grep -Fq '<strong>Unsaved</strong>' "$tmp/page"
grep -Fq '&lt;/textarea&gt;&lt;script&gt;bad&lt;/script&gt;' "$tmp/page"
grep -Fq 'data-preview-href="guide.html"' "$tmp/page"
grep -Fq "name=\"version\" value=\"$version\"" "$tmp/page"
grep -Fq '**Unsaved**' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
diff -r "$tmp/before-preview" "$tmp/site"
test "$(fields_post 2026-10-04)" = 400
cmp "$tmp/after-fields" "$tmp/site/content/first.md"
test "$(post /preview --data-urlencode token=wrong)" = 400
test "$(post /preview --data-urlencode "token=$token" --data-urlencode name=../README.md --data-urlencode "version=$version" --data-urlencode title=Keep --data-urlencode description= --data-urlencode date= --data-urlencode tags= --data-urlencode body=Keep)" = 400
grep -Fq 'Keep' "$tmp/page"
printf '%s\n' '---' '{broken' '---' > "$tmp/site/content/broken.md"
test "$(get '/edit?name=broken.md')" = 200
grep -Fq 'Structured editor unavailable' "$tmp/page"
grep -Fq '{broken' "$tmp/page"
rm "$tmp/site/content/broken.md"
test ! -e "$tmp/site/dist"
test "$(get '/edit?name=..%2FREADME.md')" = 400
test "$(get '/edit?name=first.md&name=index.md')" = 400
# Settings use separate source-version checks and preserve article text/state.
settings_version="$("$cli" read "$tmp/site" first.md --json | jq -r '.report.digest')"
settings_post() { post /settings --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$settings_version" --data-urlencode "slug=$1" --data-urlencode "listed=$2" --data-urlencode "layout=$3"; }
test "$(get '/edit?name=first.md')" = 200
grep -Fq 'Save article settings' "$tmp/page"
grep -Fq 'still built and publicly reachable' "$tmp/page"
cp -a "$tmp/site" "$tmp/before-settings"
touch -t 200001010000 "$tmp/site/content/first.md"
stamp="$(stat -c %Y "$tmp/site/content/first.md")"
test "$(settings_post '' yes '')" = 200
cmp "$tmp/before-settings/content/first.md" "$tmp/site/content/first.md"
test "$(stat -c %Y "$tmp/site/content/first.md")" = "$stamp"
test "$(post /settings --data-urlencode token=wrong)" = 400
test "$(settings_post '../bad"><script>' no missing.html)" = 400
grep -Fq '../bad&quot;&gt;&lt;script&gt;' "$tmp/page"
grep -Fq 'missing.html' "$tmp/page"
test "$(settings_post valid invalid '')" = 400
grep -Fq 'Invalid submitted value: invalid' "$tmp/page"
cmp "$tmp/before-settings/content/first.md" "$tmp/site/content/first.md"
mkdir -p "$tmp/site/layouts"
printf '<aside>Named settings layout</aside>' > "$tmp/site/layouts/custom.html"
cat "$tmp/site/layout.html" >> "$tmp/site/layouts/custom.html"
test "$(settings_post settings-route no custom.html)" = 200
"$cli" posts "$tmp/site" --json | jq -e '.report.posts[] | select(.source=="content/first.md") | .output=="settings-route.html" and (.listed|not) and (.draft|not) and .title=="Structured <title>" and .date=="2026-10-03"' >/dev/null
test "$(get '/edit?name=first.md')" = 200
grep -Fq 'value="settings-route"' "$tmp/page"
grep -Fq 'value="no" selected' "$tmp/page"
grep -Fq '# Structured body' "$tmp/page"
"$cli" build "$tmp/site" "$tmp/settings-build" >/dev/null
test -f "$tmp/settings-build/settings-route.html"
test ! -e "$tmp/settings-build/first.html"
grep -Fq 'Named settings layout' "$tmp/settings-build/settings-route.html"
if grep -Fq 'settings-route.html' "$tmp/settings-build/index.html"; then exit 1; fi
cp "$tmp/site/content/first.md" "$tmp/after-settings"
test "$(settings_post overwrite yes '')" = 400
grep -Fq 'Post changed since' "$tmp/page"
cmp "$tmp/after-settings" "$tmp/site/content/first.md"
settings_version="$("$cli" read "$tmp/site" first.md --json | jq -r '.report.digest')"
test "$(settings_post '' yes '')" = 200
"$cli" build "$tmp/site" "$tmp/settings-build" >/dev/null
test -f "$tmp/settings-build/first.html"
test ! -e "$tmp/settings-build/settings-route.html"
# Saving metadata can succeed while whole-site layout validation still fails.
settings_version="$("$cli" read "$tmp/site" first.md --json | jq -r '.report.digest')"
test "$(settings_post '' yes missing.html)" = 200
if "$cli" check "$tmp/site" > "$tmp/settings-check" 2>&1; then exit 1; fi
grep -Fq 'missing.html' "$tmp/settings-check"
cp "$tmp/before-settings/content/first.md" "$tmp/site/content/first.md"
rm "$tmp/site/layouts/custom.html"
diff -r "$tmp/before-settings" "$tmp/site"
# Duplicate saved articles through token/version-protected HTML forms.
copy_version="$("$cli" read "$tmp/site" first.md --json | jq -r '.report.digest')"
duplicate_post() { post /duplicate --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$copy_version" --data-urlencode "slug=$1" --data-urlencode 'title=Copy <title>'; }
test "$(get '/edit?name=first.md')" = 200
grep -Fq 'Duplicate into new draft' "$tmp/page"
cp -a "$tmp/site" "$tmp/before-duplicate"
test "$(post /duplicate --data-urlencode token=wrong)" = 400
test "$(duplicate_post first)" = 400
grep -Fq 'Could not duplicate article' "$tmp/page"
grep -Fq 'Copy &lt;title&gt;' "$tmp/page"
test "$(duplicate_post ../escape)" = 400
diff -r "$tmp/before-duplicate" "$tmp/site"
printf '\nExternal edit\n' >> "$tmp/site/content/first.md"
test "$(duplicate_post stale-copy)" = 400
grep -Fq 'Post changed since' "$tmp/page"
test ! -e "$tmp/site/content/stale-copy.md"
cp "$tmp/before-duplicate/content/first.md" "$tmp/site/content/first.md"
test "$(duplicate_post copied)" = 200
grep -Fq 'Draft duplicated' "$tmp/page"
grep -Fq '/edit?name=copied.md' "$tmp/page"
"$cli" posts "$tmp/site" --json | jq -e '.report.posts[] | select(.source=="content/copied.md") | .draft and .date==null and .title=="Copy <title>"' >/dev/null
test "$(get '/edit?name=copied.md')" = 200
grep -Fq '# Structured body' "$tmp/page"
diff -r --exclude=copied.md "$tmp/before-duplicate" "$tmp/site"
rm "$tmp/site/content/copied.md"
# Site validation reuses the compiler without writing sources or output.
check_post() { post /check --data-urlencode "token=$token" --data-urlencode "mode=$1"; }
"$cli" build "$tmp/site" "$tmp/site/dist" >/dev/null
printf 'user-owned output' > "$tmp/site/dist/foreign.txt"
cp -a "$tmp/site" "$tmp/before-check"
test "$(check_post ready)" = 200
grep -Fq 'Site validation passed' "$tmp/page"
expected="$("$cli" check "$tmp/site" --json | jq -r '"Checked: \(.report.pages) pages, \(.report.outputs) planned outputs."')"
grep -Fq "$expected" "$tmp/page"
test "$(check_post drafts)" = 200
grep -Fq 'Including drafts' "$tmp/page"
diff -r "$tmp/before-check" "$tmp/site"
printf '%s\n' '---' '{"draft":true}' '---' '[missing](missing.html)' > "$tmp/site/content/draft-check.md"
cp -a "$tmp/site" "$tmp/before-check-error"
test "$(check_post ready)" = 200
test "$(check_post drafts)" = 400
grep -Fq 'Validation failed' "$tmp/page"
grep -Fq 'missing.html' "$tmp/page"
diff -r "$tmp/before-check-error" "$tmp/site"
test "$(check_post invalid)" = 400
test "$(post /check --data-urlencode token=wrong --data-urlencode mode=ready)" = 400
rm "$tmp/site/content/draft-check.md"
printf '%s\n' '---' '{"<script>":true}' '---' > "$tmp/site/content/bad-check.md"
test "$(check_post ready)" = 400
grep -Fq '&lt;script&gt;' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
rm "$tmp/site/content/bad-check.md"
# A broken source must not hide good articles or permit unsafe repair reads.
printf '%s\n' '---' '{"<script>":true}' '---' > "$tmp/site/content/repair.md"
printf '\377' > "$tmp/site/content/invalid-utf8.md"
ln -s "$tmp/site/content/first.md" "$tmp/site/content/link.md"
mkdir "$tmp/site/content/nested.md"
mkfifo "$tmp/site/content/pipe.md"
cp -a "$tmp/site" "$tmp/before-inventory"
test "$(get /)" = 200
grep -Fq 'Structured &lt;title&gt;' "$tmp/page"
grep -Fq 'Sources needing attention' "$tmp/page"
grep -Fq '&lt;script&gt;' "$tmp/page"
grep -Fq '/edit?name=repair.md' "$tmp/page"
for name in invalid-utf8 link nested pipe; do
  grep -Fq "content/$name.md" "$tmp/page"
  if grep -Fq "/edit?name=$name.md" "$tmp/page"; then exit 1; fi
done
if "$cli" posts "$tmp/site" > "$tmp/strict" 2>&1; then exit 1; fi
# Compare regular files/links and check FIFO type without reading it.
test -p "$tmp/site/content/pipe.md"
diff -r --exclude=pipe.md "$tmp/before-inventory" "$tmp/site" > "$tmp/inventory-diff" || { cat "$tmp/inventory-diff"; exit 1; }
test "$(get '/edit?name=repair.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
test "$(post /save --data-urlencode "token=$token" --data-urlencode name=repair.md --data-urlencode "version=$version" --data-urlencode 'content=# Repaired article')" = 200
rm "$tmp/site/content/invalid-utf8.md" "$tmp/site/content/link.md" "$tmp/site/content/pipe.md"
rmdir "$tmp/site/content/nested.md"
test "$(get /)" = 200
grep -Fq 'Repaired article' "$tmp/page"
if grep -Fq 'Sources needing attention' "$tmp/page"; then exit 1; fi
# GET search/filter navigation has stable twenty-row pages and no writes.
for ((i=1; i<=21; i++)); do
  printf -v name 'batch%02d' "$i"
  draft=false; listed=true
  if ((i % 2 == 0)); then draft=true; fi
  if ((i == 1)); then listed=false; fi
  printf '%s\n' '---' "{\"title\":\"Batch $i\",\"draft\":$draft,\"listed\":$listed,\"tags\":[\"月\"]}" '---' '# Content' > "$tmp/site/content/$name.md"
done
cp -a "$tmp/site" "$tmp/before-search"
test "$(get '/?q=BATCH&state=all')" = 200
grep -Fq 'Showing 20 of 21 matching posts' "$tmp/page"
grep -Fq '/?q=BATCH&amp;state=all&amp;page=2' "$tmp/page"
grep -Fq '/edit?name=batch01.md' "$tmp/page"
if grep -Fq '/edit?name=batch21.md' "$tmp/page"; then exit 1; fi
test "$(get '/?q=BATCH&state=all&page=2')" = 200
grep -Fq 'Showing 1 of 21 matching posts' "$tmp/page"
grep -Fq '/edit?name=batch21.md' "$tmp/page"
grep -Fq 'Previous posts' "$tmp/page"
test "$(get '/?q=batch&state=draft')" = 200
grep -Fq 'Showing 10 of 10 matching posts' "$tmp/page"
test "$(get '/?q=batch&state=ready')" = 200
grep -Fq 'Showing 11 of 11 matching posts' "$tmp/page"
test "$(get '/?q=batch&state=unlisted')" = 200
grep -Fq 'Showing 1 of 1 matching posts' "$tmp/page"
test "$(get '/?q=%E6%9C%88')" = 200
grep -Fq 'Showing 20 of 21 matching posts' "$tmp/page"
test "$(get '/?q=%22%3E%3Cscript%3E')" = 200
grep -Fq 'No matching posts' "$tmp/page"
grep -Fq '&quot;&gt;&lt;script&gt;' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
for query in 'page=0' 'page=-1' 'page=1.5' 'page=999999999999' 'page=3&q=batch' 'state=bad' 'q=a&q=b' 'unknown=x'; do
  test "$(get "/?$query")" = 400
done
diff -r "$tmp/before-search" "$tmp/site"
printf '%s\n' '---' '{broken' '---' > "$tmp/site/content/search-error.md"
test "$(get '/?q=absent&state=draft')" = 200
grep -Fq 'content/search-error.md' "$tmp/page"
grep -Fq 'No matching posts' "$tmp/page"
rm "$tmp/site/content/search-error.md"
# Build production files separately, excluding drafts and protecting existing output.
production="$tmp/site/.moonpress-build"
build_production() { post /build-production --data-urlencode "token=$token"; }
plan_production() { post /plan-production --data-urlencode "token=$token"; }
cp -a "$tmp/site" "$tmp/before-production"
test "$(get /)" = 200
grep -Fq 'Build production files' "$tmp/page"
grep -Fq 'Inspect production changes' "$tmp/page"
test "$(post /plan-production --data-urlencode token=wrong)" = 400
test "$(post /plan-production --data-urlencode "token=$token" --data-urlencode output=dist)" = 400
test "$(plan_production)" = 200
grep -Fq 'Production changes inspected' "$tmp/page"
grep -Fq 'No files written or deployment performed' "$tmp/page"
test ! -e "$production"
diff -r "$tmp/before-production" "$tmp/site"
test "$(post /build-production --data-urlencode token=wrong)" = 400
test "$(post /build-production --data-urlencode "token=$token" --data-urlencode output=dist)" = 400
test ! -e "$production"
ln -s "$tmp/site/dist" "$production"
test "$(build_production)" = 400
rm "$production"
mkdir "$production"
printf foreign > "$production/foreign.txt"
test "$(build_production)" = 400
test "$(plan_production)" = 400
grep -Fq 'Production inspection failed' "$tmp/page"
test "$(cat "$production/foreign.txt")" = foreign
rm "$production/foreign.txt"; rmdir "$production"
printf '%s\n' '---' '{"draft":true}' '---' '[broken](absent.html)' > "$tmp/site/content/production-draft.md"
cp -a "$tmp/site" "$tmp/before-production-plan"
"$cli" explain "$tmp/site" "$production" --json > "$tmp/production-plan"
expected="$(jq -r '"Pages: \(.report.pages); would write: \(.report.written); unchanged: \(.report.skipped); would delete: \(.report.deleted)."' "$tmp/production-plan")"
test "$(plan_production)" = 200
grep -Fq "$expected" "$tmp/page"
grep -Fq '<th>Reason</th>' "$tmp/page"
diff -r "$tmp/before-production-plan" "$tmp/site"
test "$(build_production)" = 200
grep -Fq 'Production files built' "$tmp/page"
expected_build="$(jq -r '"Pages: \(.report.pages); written: \(.report.written); unchanged: \(.report.skipped); deleted: \(.report.deleted)."' "$tmp/production-plan")"
grep -Fq "$expected_build" "$tmp/page"
grep -Fq 'drafts excluded' "$tmp/page"
grep -Fq 'No deployment performed' "$tmp/page"
test ! -e "$production/batch02.html"
test ! -e "$production/production-draft.html"
"$cli" build "$tmp/site" "$tmp/clean-production" >/dev/null
diff -r "$tmp/clean-production" "$production"
rm "$tmp/site/content/production-draft.md"
test "$(build_production)" = 200
grep -Fq 'written: 0;' "$tmp/page"
cp -a "$tmp/site" "$tmp/before-noop-plan"
test "$(plan_production)" = 200
grep -Fq 'would write: 0;' "$tmp/page"
diff -r "$tmp/before-noop-plan" "$tmp/site"
printf 'manual production edit' > "$production/index.html"
cp -a "$production" "$tmp/edited-production"
test "$(plan_production)" = 400
diff -r "$tmp/edited-production" "$production"
test "$(build_production)" = 400
grep -Fq 'Production build failed' "$tmp/page"
diff -r "$tmp/edited-production" "$production"
cp "$tmp/clean-production/index.html" "$production/index.html"
test "$(get '/.moonpress-build/index.html')" = 404
diff -r --exclude=.moonpress-build "$tmp/before-production" "$tmp/site"
# Build themed draft-inclusive previews with the compiler's ownership checks.
preview="$tmp/site/.moonpress-preview"
build_preview() { post /build-preview --data-urlencode "token=$token"; }
cp -a "$tmp/site" "$tmp/before-preview-build"
test "$(post /build-preview --data-urlencode token=wrong)" = 400
test "$(post /build-preview --data-urlencode "token=$token" --data-urlencode output=dist)" = 400
test ! -e "$preview"
ln -s "$tmp/site/dist" "$preview"
test "$(build_preview)" = 400
rm "$preview"
mkdir "$preview"
printf 'foreign' > "$preview/foreign.txt"
test "$(build_preview)" = 400
test "$(cat "$preview/foreign.txt")" = foreign
rm "$preview/foreign.txt"
rmdir "$preview"
# A draft link failure is caught before creating any preview directory.
printf '%s\n' '---' '{"draft":true}' '---' '[missing](missing.html)' > "$tmp/site/content/build-error.md"
test "$(build_preview)" = 400
grep -Fq 'Preview build failed' "$tmp/page"
test ! -e "$preview"
rm "$tmp/site/content/build-error.md"
test "$(build_preview)" = 200
grep -Fq 'Full preview files built' "$tmp/page"
grep -Fq 'No deployment performed' "$tmp/page"
test -f "$preview/batch02.html"
"$cli" build "$tmp/site" "$tmp/clean-preview" --include-drafts >/dev/null
diff -r "$tmp/clean-preview" "$preview"
diff -r --exclude=.moonpress-preview "$tmp/before-preview-build" "$tmp/site"
test "$(build_preview)" = 200
grep -Fq 'written: 0;' "$tmp/page"
printf 'manual edit' > "$preview/index.html"
cp -a "$preview" "$tmp/edited-preview"
test "$(build_preview)" = 400
diff -r "$tmp/edited-preview" "$preview"
# The admin origin never serves generated project HTML.
test "$(get '/.moonpress-preview/index.html')" = 404
diff -r --exclude=.moonpress-preview "$tmp/before-preview-build" "$tmp/site"
mkdir -p "$tmp/site/public"
printf 'image bytes' > "$tmp/site/public/画像 (a)&.PNG"
printf '<pdf>' > "$tmp/site/public/a.pdf"
printf '%s\n' '---' '{"title":"<media article>","draft":true,"listed":false}' '---' '[asset](a.pdf)' > "$tmp/site/content/media-use.md"
printf '%s\n' '---' '{"broken":true}' '---' > "$tmp/site/content/media-bad.md"
cp -a "$tmp/site" "$tmp/before-media"
test "$(get /media)" = 200
grep -Fq '![Describe image](%E7%94%BB%E5%83%8F%20%28a%29%26.PNG)' "$tmp/page"
grep -Fq '[Download](a.pdf)' "$tmp/page"
grep -Fq 'public/画像 (a)&amp;.PNG' "$tmp/page"
grep -Fq 'Referring articles' "$tmp/page"
grep -Fq '/edit?name=media-use.md' "$tmp/page"
grep -Fq '&lt;media article&gt;' "$tmp/page"
grep -Fq 'Draft · unlisted' "$tmp/page"
grep -Fq 'content/media-bad.md' "$tmp/page"
grep -Fq 'not proof that deletion is safe' "$tmp/page"
diff -r "$tmp/before-media" "$tmp/site"
test "$(get '/media?q=PDF&kind=attachments')" = 200
grep -Fq '[Download](a.pdf)' "$tmp/page"
if grep -Fq '![Describe image](%E7%94%BB' "$tmp/page"; then exit 1; fi
grep -Fq 'content/media-bad.md' "$tmp/page"
test "$(get '/media?q=missing&kind=images')" = 200
grep -Fq 'No matching media assets' "$tmp/page"
grep -Fq 'content/media-bad.md' "$tmp/page"
test "$(get '/media?q=%22%3E%3Cscript%3E&kind=all')" = 200
grep -Fq '&quot;&gt;&lt;script&gt;' "$tmp/page"
for query in 'q=a&q=b' 'kind=bad' 'extra=bad'; do
  test "$(get "/media?$query")" = 400
done
diff -r "$tmp/before-media" "$tmp/site"
# Media page boundaries retain search/type, diagnostics and import/upload actions.
for i in {1..24}; do printf bytes > "$tmp/site/public/media-page$(printf '%02d' "$i").txt"; done
cp -a "$tmp/site" "$tmp/before-media-pages"
test "$(get '/media?q=media-page&kind=attachments')" = 200
grep -Fq 'Showing 20 of 24 matching media assets' "$tmp/page"
test "$(grep -oF '<section><h2>public/media-page' "$tmp/page" | wc -l)" = 20
grep -Fq '/media?q=media-page&amp;kind=attachments&amp;page=2' "$tmp/page"
grep -Fq 'content/media-bad.md' "$tmp/page"
test "$(get '/media?q=media-page&kind=attachments&page=2')" = 200
grep -Fq 'Showing 4 of 24 matching media assets' "$tmp/page"
test "$(grep -oF '<section><h2>public/media-page' "$tmp/page" | wc -l)" = 4
grep -Fq 'public/media-page21.txt' "$tmp/page"
if grep -Fq 'public/media-page20.txt' "$tmp/page"; then exit 1; fi
grep -Fq '/media?q=media-page&amp;kind=attachments&amp;page=1' "$tmp/page"
grep -Fq 'type="file"' "$tmp/page"
grep -Fq 'Import a local file' "$tmp/page"
grep -Fq 'content/media-bad.md' "$tmp/page"
# Search submits no page field and therefore resets to page 1.
if grep -Fq 'name="page"' "$tmp/page"; then exit 1; fi
for query in 'page=0' 'page=-1' 'page=999999999' 'page=1&page=2' 'q=missing&page=2' 'q=media-page&kind=attachments&page=3'; do
  test "$(get "/media?$query")" = 400
done
diff -r "$tmp/before-media-pages" "$tmp/site"
rm "$tmp/site/public"/media-page*.txt
rm "$tmp/site/content/media-use.md" "$tmp/site/content/media-bad.md"

test "$(get '/public/a.pdf')" = 404
printf '\000\377binary upload' > "$tmp/media-source"
import_post() { post /import --data-urlencode "token=$token" --data-urlencode "source=$tmp/media-source" --data-urlencode "name=$1"; }
test "$(post /import --data-urlencode token=wrong --data-urlencode "source=$tmp/media-source" --data-urlencode name=new.png)" = 400
test ! -e "$tmp/site/public/new.png"
test "$(import_post 'new (月).png')" = 200
grep -Fq 'Media imported' "$tmp/page"
grep -Fq '![Describe image](new%20%28%E6%9C%88%29.png)' "$tmp/page"
cmp "$tmp/media-source" "$tmp/site/public/new (月).png"
cp -a "$tmp/site" "$tmp/before-import-error"
test "$(import_post 'new (月).png')" = 400
grep -Fq 'Could not import media' "$tmp/page"
grep -Fq 'name="source"' "$tmp/page"
grep -Fq "$tmp/media-source" "$tmp/page"
test "$(import_post '../bad.png')" = 400
diff -r "$tmp/before-import-error" "$tmp/site"
test "$(get /media)" = 200
grep -Fq 'new (月).png' "$tmp/page"
# Multipart uploads preserve raw bytes; only /upload accepts this encoding.
printf '\000\377\001\r\n--almost-boundaryX\r\n' > "$tmp/upload-source"
upload_post() { post /upload -H 'Expect:' -F "token=$token" -F "name=$1" -F "file=@$tmp/upload-source"; }
test "$(get /media)" = 200
grep -Fq 'type="file"' "$tmp/page"
grep -Fq 'multipart/form-data' "$tmp/page"
test "$(upload_post 'browser (月).png')" = 200
grep -Fq 'Media uploaded' "$tmp/page"
cmp "$tmp/upload-source" "$tmp/site/public/browser (月).png"
cp -a "$tmp/site" "$tmp/before-upload-error"
test "$(upload_post 'browser (月).png')" = 400
grep -Fq 'Select the file again' "$tmp/page"
grep -Fq 'browser (月).png' "$tmp/page"
test "$(upload_post '../bad.png')" = 400
test "$(post /upload -H 'Expect:' -F token=wrong -F name=bad.png -F "file=@$tmp/upload-source")" = 400
test "$(post /upload -H 'Expect:' -F "token=$token" -F name=bad.png -F name=other.png -F "file=@$tmp/upload-source")" = 400
test "$(post /upload -H 'Expect:' -F "token=$token" -F name=bad.png -F extra=bad -F "file=@$tmp/upload-source")" = 400
test "$(post /upload -H 'Expect:' -F "token=$token" -F name=bad.png)" = 400
test "$(post /save -H 'Expect:' -F "token=$token" -F name=bad.png -F "file=@$tmp/upload-source")" = 400
test "$(post /upload --data-urlencode "token=$token" --data-urlencode name=bad.png)" = 400
diff -r "$tmp/before-upload-error" "$tmp/site"
# Uploads above the ordinary 256 KiB form limit use their own bounded route.
dd if=/dev/zero of="$tmp/upload-source" bs=1024 count=300 status=none
test "$(upload_post large.pdf)" = 200
cmp "$tmp/upload-source" "$tmp/site/public/large.pdf"
raw() { timeout 8 bash -c 'exec 3<>/dev/tcp/127.0.0.1/"$1"; printf "%b" "$2" >&3; cat <&3 2>/dev/null || true' _ "$port" "$1" > "$tmp/raw"; }
raw "GET / HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nHost: evil\r\n\r\n"
grep -Fq '400 Bad Request' "$tmp/raw"
raw "POST /upload HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nOrigin: $origin\r\nContent-Type: multipart/form-data; boundary=test\r\nContent-Length: 8388609\r\n\r\n"
grep -Fq '400 Bad Request' "$tmp/raw"
raw "POST /new HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nContent-Length: 262145\r\n\r\n"
grep -Fq '400 Bad Request' "$tmp/raw"
raw "GET / HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nTransfer-Encoding: chunked\r\n\r\n"
grep -Fq '400 Bad Request' "$tmp/raw"
printf -v padding '%17000s' ''
raw "GET / HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nX-Padding:$padding"
grep -Fq '400 Bad Request' "$tmp/raw"
# Idle/incomplete clients cannot monopolize the single-user server indefinitely.
raw 'GET / HTTP/1.1\r\n'
grep -Fq '400 Bad Request' "$tmp/raw"
test "$(get /)" = 200
"$cli" admin --help | grep -Fq 'Ctrl-C'
for portarg in 0 80 65536 abc 1.2; do
  if "$cli" admin "$tmp/site" "$portarg" > "$tmp/args" 2>&1; then exit 1; else test "$?" = 2; fi
done
if "$cli" admin "$tmp/site" "$port" --json > "$tmp/args" 2>&1; then exit 1; else test "$?" = 2; fi
if "$cli" admin "$tmp/site" "$port" > "$tmp/args" 2>&1; then exit 1; else test "$?" = 1; fi
"$cli" check "$tmp/site" >/dev/null
echo 'Admin tests passed: HTTP forms, token/origin/host checks, escape safety, stale input recovery, framing limits, timeouts and lifecycle.'
