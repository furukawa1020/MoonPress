#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
for operation in post media settings absent; do
  for fault in fail kill success; do
    rm -rf "$tmp/site"
    mkdir -p "$tmp/site/content" "$tmp/site/public"
    case "$operation" in
      post) directory="$tmp/site/content"; name=a.md; stage=.moonpress-edit; printf '# Old\n' > "$directory/$name"; printf '# New\n' > "$tmp/new" ;;
      media) directory="$tmp/site/public"; name=a.png; stage=.moonpress-media-edit; printf 'old' > "$directory/$name"; printf 'new\000bytes' > "$tmp/new" ;;
      settings|absent) directory="$tmp/site"; name=site.json; stage=.moonpress-settings-edit; printf '{}\n' > "$directory/$name"; printf '{"tag_index":true}\n' > "$tmp/new" ;;
    esac
    version="$(sha256sum "$directory/$name" | cut -d ' ' -f1)"
    if [[ "$operation" = absent ]]; then rm "$directory/$name"; version=absent; fi
    case "$operation" in
      post) args=(save "$tmp/site" "$name" "$version" "$tmp/new") ;;
      media) args=(media-replace "$tmp/site" "$name" "$version" "$tmp/new") ;;
      settings|absent) args=(settings-save "$tmp/site" "$version" "$tmp/new") ;;
    esac
    injection=(); expected=0
    case "$fault" in
      fail) injection=("MOONPRESS_TEST_FAIL_DIR_SYNC=$directory"); expected=1 ;;
      kill) injection=("MOONPRESS_TEST_KILL_AFTER_SYNC=$directory"); expected=137 ;;
    esac
    : > "$tmp/trace"
    code=0
    env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_SYNC_TRACE="$tmp/trace" "${injection[@]}" "$cli" "${args[@]}" --json > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
    test "$code" = "$expected"
    cmp "$tmp/new" "$directory/$name"
    if [[ "$fault" = fail ]]; then
      test ! -s "$tmp/stdout"
      grep -Fq 'durability is unconfirmed' "$tmp/stderr"
    fi
    if [[ "$operation" = absent && "$fault" != success ]]; then
      # Exclusive link is visible; retain the stage when commit sync is uncertain.
      test "$(stat -c %i "$directory/$name")" = "$(stat -c %i "$directory/$stage")"
    else
      test ! -e "$directory/$stage"
    fi
    # Never falsely accept the old version after a visible replacement.
    if [[ "$fault" != success ]]; then
      code=0; "$cli" "${args[@]}" --json > /dev/null 2> "$tmp/stale" || code=$?
      test "$code" = 1
    else
      python3 - "$tmp/trace" "$directory/$stage" "$directory" <<'PY'
import sys
lines=open(sys.argv[1]).read().splitlines()
assert lines.index('sync '+sys.argv[2]) < lines.index('sync '+sys.argv[3]),lines
assert lines[-1]=='sync '+sys.argv[3],lines
PY
    fi
  done
done
echo 'Authoring sync passed: data before directory commit, uncertain outcomes, complete bytes and stale-version refusal after restart.'
