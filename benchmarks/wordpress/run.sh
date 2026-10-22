#!/usr/bin/env bash
# Disposable GitHub-hosted runner only. Never use a user/production database.
set -euo pipefail
cd "$(dirname "$0")/../.."
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted ]] || { echo 'Requires a disposable GitHub-hosted runner.' >&2; exit 1; }
work="$(mktemp -d "$RUNNER_TEMP/moonpress-wordpress.XXXXXXXX")"
trap 'rm -rf "$work"' EXIT
php --version
php -m | grep -Fx mysqli
php -m | grep -Fx 'Zend OPcache'
sudo systemctl start mysql
root=(mysql --protocol=socket -u root -proot)
if ! "${root[@]}" -Nse 'SELECT 1' >/dev/null 2>&1; then root=(sudo mysql --protocol=socket); fi
export MOONPRESS_BENCH_DB_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
echo "::add-mask::$MOONPRESS_BENCH_DB_PASSWORD"
"${root[@]}" -e "CREATE DATABASE moonpress_benchmark CHARACTER SET utf8mb4; CREATE USER 'moonpress_bench'@'127.0.0.1' IDENTIFIED BY '$MOONPRESS_BENCH_DB_PASSWORD'; GRANT ALL ON moonpress_benchmark.* TO 'moonpress_bench'@'127.0.0.1';"
url='https://wordpress.org/wordpress-7.1.3.tar.gz'
curl --fail --location --retry 3 "$url" -o "$work/wordpress.tar.gz"
curl --fail --location --retry 3 "$url.sha1" -o "$work/wordpress.sha1"
expected="$(tr -d '[:space:]' < "$work/wordpress.sha1")"
[[ "$expected" =~ ^[a-fA-F0-9]{40}$ ]]
printf '%s  %s\n' "$expected" "$work/wordpress.tar.gz" | sha1sum --check --strict
sha256sum "$work/wordpress.tar.gz"
tar -xzf "$work/wordpress.tar.gz" -C "$work"
for source in benchmarks/wordpress/*.php; do php -l "$source"; done
python3 benchmarks/wordpress/native.py "$work/native.json"
python3 benchmarks/wordpress/compare.py "$work/wordpress" "$work/wordpress.tar.gz" "$work/http.json"
python3 benchmarks/wordpress/emit.py "$work/native.json" "$work/http.json"
