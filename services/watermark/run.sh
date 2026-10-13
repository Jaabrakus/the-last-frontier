#!/bin/sh
set -eu
service_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runtime="${WATERMARK_PYTHON:-}"
if [ -z "$runtime" ]; then
  if [ -x "$service_dir/.runtime/bin/python" ]; then runtime="$service_dir/.runtime/bin/python"
  elif [ -x /private/tmp/tidebreak-videoseal-runtime/bin/python ]; then runtime=/private/tmp/tidebreak-videoseal-runtime/bin/python
  else runtime=python3
  fi
fi
export WATERMARK_PYTHON="$runtime"
if [ -z "${VIDEOSEAL_MODEL:-}" ] && [ -f "$service_dir/.model/y_256b_img.jit" ]; then
  export VIDEOSEAL_MODEL="$service_dir/.model/y_256b_img.jit"
fi
exec "$runtime" "$service_dir/server.py" "$@"
