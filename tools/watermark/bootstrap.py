#!/usr/bin/env python3
"""Install an isolated VideoSeal runtime and verify the official model download."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import urllib.request

URL = "https://dl.fbaipublicfiles.com/videoseal/y_256b_img.jit"
SHA256 = "5c7a4581c36fc6090aafdcfb3999123bae5172a4847f22e2da4e7fd1a39d1e1b"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--python", default=sys.executable, help="Python3.11 interpreter")
parser.add_argument("--runtime", default="/private/tmp/tidebreak-videoseal-runtime")
parser.add_argument("--model-dir", default="/private/tmp/tidebreak-videoseal-model")
args = parser.parse_args()
runtime = Path(args.runtime).resolve()
model_dir = Path(args.model_dir).resolve()
subprocess.run([args.python, "-c", "import sys; assert sys.version_info[:2] == (3, 11), 'Use Python3.11'"], check=True)
subprocess.run([args.python, "-m", "venv", str(runtime)], check=True)
python = runtime / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
subprocess.run([str(python), "-m", "pip", "install", "--only-binary=:all:", "-r",
                str(Path(__file__).with_name("requirements.txt"))], check=True)
model_dir.mkdir(parents=True, exist_ok=True)
model = model_dir / "y_256b_img.jit"
if not model.exists():
    temporary = model.with_suffix(".download")
    try:
        with urllib.request.urlopen(URL, timeout=60) as source, temporary.open("xb") as output:
            while True:
                block = source.read(1024 * 1024)
                if not block:
                    break
                output.write(block)
        assert hashlib.sha256(temporary.read_bytes()).hexdigest() == SHA256, "Model hash mismatch"
        os.link(temporary, model)
    finally:
        temporary.unlink(missing_ok=True)
assert hashlib.sha256(model.read_bytes()).hexdigest() == SHA256, "Model hash mismatch"
(model_dir / "LICENSE").write_bytes(Path(__file__).with_name("LICENSE.videoseal").read_bytes())
print("WATERMARK_PYTHON=" + str(python))
print("VIDEOSEAL_MODEL=" + str(model))
