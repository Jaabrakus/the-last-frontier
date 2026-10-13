#!/bin/sh
set -eu
service_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$service_dir/../.." && pwd)
setup_python="${WATERMARK_SETUP_PYTHON:-python3.11}"
exec "$setup_python" "$repo_dir/tools/watermark/bootstrap.py" --python "$setup_python" --runtime "$service_dir/.runtime" --model-dir "$service_dir/.model"
