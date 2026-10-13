#!/bin/sh
set -eu
service_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
is_running() {
  headers=$(/usr/bin/curl --silent --fail --max-time 2 --dump-header - --output /dev/null http://127.0.0.1:8765/api/health) || return 1
  case "$headers" in
    *'Server: VideoMark/1'*) return 0 ;;
    *) return 1 ;;
  esac
}
# Reuse this app if it is already open, including when its engine needs setup.
if is_running; then
  /usr/bin/open http://127.0.0.1:8765/
  exit 0
fi
# Open only this local service after it starts accepting connections. No public binding.
(
  n=0
  while [ "$n" -lt 60 ]; do
    if is_running; then
      /usr/bin/open http://127.0.0.1:8765/
      exit 0
    fi
    n=$((n + 1))
    sleep 1
  done
  printf '%s\n' 'The local server did not become available. See the terminal output above.'
) &
exec "$service_dir/run.sh" --port 8765
