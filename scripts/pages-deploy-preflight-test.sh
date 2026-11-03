#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="${1:-$PWD/_build/native/release/build/cmd/main/main.exe}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"$cli" build site "$work/dist" >/dev/null
mkdir "$work/bin"
cat > "$work/bin/gh" <<'MOCK'
#!/usr/bin/env bash
if [[ "$*" == 'api repos/example/moonpress/pages' ]]; then
  if [[ "$PAGES_TEST_MODE" == missing ]]; then exit 1; fi
  printf '%s\n' '{"source":{"branch":"main","path":"/"}}'
else
  touch "$PAGES_TEST_MUTATED"
  exit 1
fi
MOCK
cat > "$work/bin/git" <<'MOCK'
#!/usr/bin/env bash
touch "$PAGES_TEST_MUTATED"
exit 1
MOCK
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" GITHUB_REPOSITORY=example/moonpress GITHUB_SHA=test GH_TOKEN=fixture
export PAGES_TEST_MUTATED="$work/mutated"
for PAGES_TEST_MODE in missing wrong-source; do
  export PAGES_TEST_MODE
  if bash scripts/deploy-pages.sh "$work/dist" > "$work/log" 2>&1; then
    echo "Expected deployment to fail for $PAGES_TEST_MODE" >&2
    exit 1
  fi
  test ! -e "$PAGES_TEST_MUTATED"
  case "$PAGES_TEST_MODE" in
    missing) rg -q 'Enable Settings > Pages' "$work/log" ;;
    wrong-source) rg -q 'Pages source must be gh-pages' "$work/log" ;;
  esac
done
echo 'Pages preflight rejects invalid settings before Git or build requests.'
