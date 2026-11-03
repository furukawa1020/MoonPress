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
  if [[ "$PAGES_TEST_MODE" == wrong-source ]]; then
    printf '%s\n' '{"source":{"branch":"main","path":"/"}}'
  else
    printf '%s\n' '{"source":{"branch":"gh-pages","path":"/"}}'
  fi
else
  touch "$PAGES_TEST_MUTATED"
  exit 1
fi
MOCK
cat > "$work/bin/git" <<'MOCK'
#!/usr/bin/env bash
case "${3:-}" in
  init) [[ "$PAGES_TEST_MODE" == remote-* ]] && exit 0 ;;
  ls-remote)
    case "$PAGES_TEST_MODE" in
      remote-error) exit 128 ;;
      remote-timeout) exit 124 ;;
    esac
    ;;
esac
touch "$PAGES_TEST_MUTATED"
exit 1
MOCK
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" GITHUB_REPOSITORY=example/moonpress GITHUB_SHA=test GH_TOKEN=fixture
export PAGES_TEST_MUTATED="$work/mutated"
for PAGES_TEST_MODE in missing wrong-source remote-error remote-timeout; do
  export PAGES_TEST_MODE
  if bash scripts/deploy-pages.sh "$work/dist" > "$work/log" 2>&1; then
    echo "Expected deployment to fail for $PAGES_TEST_MODE" >&2
    exit 1
  fi
  test ! -e "$PAGES_TEST_MUTATED"
  case "$PAGES_TEST_MODE" in
    missing) grep -Eq 'Enable Settings > Pages' "$work/log" ;;
    wrong-source) grep -Eq 'Pages source must be gh-pages' "$work/log" ;;
    remote-error) grep -Eq 'Could not inspect the gh-pages branch .*128' "$work/log" ;;
    remote-timeout) grep -Eq 'Could not inspect the gh-pages branch .*124' "$work/log" ;;
  esac
done
echo 'Pages preflight rejects invalid settings and failed branch lookups before publication.'
