#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '<title>{{title}}</title>{{toc}}{{content}}' > "$tmp/site/layout.html"
printf 'code.language-moonbit { color: navy; }' > "$tmp/site/style.css"
cat > "$tmp/site/content/index.md" <<'PAGE'
# Home
```moonbit ignored
# Hidden
[Missing](missing.html)
![Missing](missing.png)
<script>&
```
~~~x"onclick="bad
unsafe annotation
~~~
~~~sh
printf hello
~~~
PAGE
printf '# Other\n' > "$tmp/site/content/other.md"
"$cli" check "$tmp/site" >/dev/null
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  if grep -Fq 'class="language-' "$tmp/out/index.html"; then exit 1; fi
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
  old_hash="$(printf moonpress-renderer-v14 | sha256sum | cut -d' ' -f1)"
  jq --arg hash "$old_hash" '(.artifacts[].dependencies[] | select(.name == "compiler") | .digest) = $hash' \
    "$tmp/out/.moonpress.json" > "$tmp/previous.json"
  cp "$tmp/previous.json" "$tmp/out/.moonpress.json"
fi
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
jq -e '[.report.changes[] | select(.action == "write" and (.reason | contains("compiler")))] | length == 2' "$tmp/plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
grep -Fq '<code class="language-moonbit">' "$tmp/out/index.html"
grep -Fq '<code class="language-sh">' "$tmp/out/index.html"
grep -Fq '<pre><code>unsafe annotation' "$tmp/out/index.html"
grep -Fq '&lt;script&gt;&amp;' "$tmp/out/index.html"
if grep -Eq 'onclick=|href="#mp-hidden"|id="mp-hidden"' "$tmp/out/index.html"; then exit 1; fi
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
sed -i 's/```moonbit ignored/```text/' "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
grep -Fq '<code class="language-text">' "$tmp/out/index.html"
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
test "$(stat -c %Y "$tmp/out/other.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean-after" >/dev/null
diff -r "$tmp/out" "$tmp/clean-after"
cp -a "$tmp/out" "$tmp/valid"
printf '\n[Broken](missing.html)\n' >> "$tmp/site/content/index.md"
for command in explain build; do
  if "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
  grep -Fq 'broken internal link' "$tmp/stderr"
  diff -r "$tmp/out" "$tmp/valid"
done
echo 'Fence language tests passed: safe classes, code isolation, renderer migration, scoped/no-op builds, clean parity and preflight integrity.'
