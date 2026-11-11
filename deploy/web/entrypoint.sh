#!/bin/sh
set -eu
umask 077
data="${MOONPRESS_DATA_DIR:-/data}"
if [ "$(id -u)" -eq 0 ]; then
  [ "$data" = /data ] || { echo 'The container runs with /data as its volume.' >&2; exit 1; }
  [ -d "$data" ] && [ ! -L "$data" ] || { echo 'Mount the MoonPress data volume at /data.' >&2; exit 1; }
  chown 10001:10001 "$data"
  exec setpriv --reuid=10001 --regid=10001 --clear-groups --no-new-privs /usr/local/bin/moonpress-web
fi
exec /usr/local/bin/moonpress-web
