#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
test -x "$cli"
report_dir="${1:-bench-results}"
repeats="${REPEATS:-5}"
[[ "$repeats" =~ ^[1-9][0-9]*$ ]] || { echo 'REPEATS must be a positive integer' >&2; exit 1; }
[[ ! -e "$report_dir" ]] || { echo 'Choose a fresh report directory' >&2; exit 1; }
mkdir "$report_dir"
report_dir="$(realpath "$report_dir")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
csv="$report_dir/raw.csv"
printf 'pages,scenario,repeat,microseconds\n' > "$csv"
measure() {
  local pages="$1" scenario="$2" repetition="$3"
  shift 3
  local start end
  start="${EPOCHREALTIME/./}"
  "$@" > /dev/null
  end="${EPOCHREALTIME/./}"
  printf '%s,%s,%s,%s\n' "$pages" "$scenario" "$repetition" "$((end-start))" >> "$csv"
}
for ((r=1; r<=repeats; r++)); do
  measure 0 startup "$r" "$cli" --version
done
for n in 10 100 1000; do
  input="$tmp/site-$n"
  mkdir -p "$input/content"
  cp site/layout.html "$input/layout.html"
  cp site/style.css "$input/style.css"
  for ((i=1; i<=n; i++)); do
    printf '# Page %s\n\nA deterministic synthetic page for MoonPress.\n\n## Section\n\nSmall builds, explicit dependencies.\n\n```text\nhello world\n```\n' "$i" > "$input/content/page-$i.md"
  done
  for ((r=1; r<=repeats; r++)); do
    output="$tmp/out-$n-$r"
    measure "$n" clean "$r" "$cli" build "$input" "$output"
    measure "$n" noop "$r" "$cli" build "$input" "$output"
    printf '\nEdit %s.\n' "$r" >> "$input/content/page-1.md"
    measure "$n" one_page "$r" "$cli" build "$input" "$output"
  done
done
{
  echo '# MoonPress benchmark'
  echo
  printf -- '- Measured UTC: %s\n' "$(date -u +%FT%TZ)"
  printf -- '- OS / architecture: %s\n' "$(uname -srm)"
  printf -- '- CPU: %s\n' "$(lscpu | awk -F: '/Model name/{sub(/^ +/,"",$2); print $2; exit}')"
  printf -- '- Revision: %s\n' "${BENCH_REVISION:-$(git rev-parse HEAD)}"
  printf -- '- Moon: %s\n' "$(moon version | head -1)"
  printf -- '- Moonc: %s\n' "$(moonc -v)"
  printf -- '- Repetitions: %s\n' "$repeats"
  printf -- '- Native executable: %s bytes\n' "$(wc -c < "$cli")"
  printf -- '- gzip -n executable: %s bytes\n' "$(gzip -nc "$cli" | wc -c)"
  echo
  echo '| Pages | Scenario | Mean (ms) | Min (ms) | Max (ms) |'
  echo '| ---: | --- | ---: | ---: | ---: |'
  awk -F, 'NR>1 {k=$1 SUBSEP $2; n[k]++;sum[k]+=$4;if(n[k]==1||$4<min[k])min[k]=$4;if($4>max[k])max[k]=$4} END {for(k in n){split(k,a,SUBSEP);printf "| %d | %s | %.3f | %.3f | %.3f |\n",a[1],a[2],sum[k]/n[k]/1000,min[k]/1000,max[k]/1000}}' "$csv" | sort -t '|' -k2,2n -k3,3
  echo
  echo 'Method: Bash EPOCHREALTIME around each native process. Includes process startup and shell invocation overhead. Microsecond units do not imply microsecond accuracy. Filesystem caches are NOT flushed. Clean means a fresh output directory, not a cold OS cache. Tiny synthetic pages; no assets beyond shared CSS. Edits append to one source page between repetitions. Incremental builds still hash inputs and verify every generated output. These numbers are host-specific, not a comparison with other SSGs. Native binary uses system runtime libraries; gzip bytes are not a packaged distribution size.'
} > "$report_dir/report.md"
cat "$report_dir/report.md"
