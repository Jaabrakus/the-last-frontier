#!/usr/bin/env python3
"""Local, cookie-free video watermark service. Standard library only."""
import argparse
import email.message
import json
import math
import mmap
import os
from pathlib import Path
import queue
import re
import secrets
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools" / "watermark"))
from policy import RESTRICTIONS, permission_for_detection

TOKEN = re.compile(r"^[A-Za-z0-9_-]{43}$")
MAX_VIDEO = 100 * 1024 * 1024
MAX_BODY = MAX_VIDEO + 65536
TTL = 24 * 60 * 60
MAX_ARTIFACT = 256 * 1024 * 1024
MAX_PIXEL_FRAMES = 8_000_000_000


class Problem(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


permission_from_detection = permission_for_detection


def result_permission(result, operation):
    return permission_from_detection(result.get("detection") if operation == "embed" else result)


def clean_text(value, limit, required=False):
    value = value.strip()
    if (required and not value) or len(value) > limit or any(ord(c) < 32 for c in value):
        raise Problem(400, "Use %s to %s characters without line breaks." % (1 if required else 0, limit))
    return value


def parse_upload(path, content_type, destination, mode):
    """Parse a bounded disk spool; filenames never become paths. No binary body copies in RAM."""
    msg = email.message.Message()
    msg["Content-Type"] = content_type
    boundary = msg.get_param("boundary")
    if msg.get_content_type() != "multipart/form-data" or not isinstance(boundary, str) or not re.fullmatch(r"[A-Za-z0-9'()+_,./:=?\-]{1,70}", boundary):
        raise Problem(400, "Upload a video using multipart/form-data.")
    delimiter = b"--" + boundary.encode("ascii")
    fields = {}
    allowed = {"video", "notice", "creator"} if mode == "embed" else {"video", "asset_id"}
    with path.open("rb") as raw, mmap.mmap(raw.fileno(), 0, access=mmap.ACCESS_READ) as body:
        if body[:len(delimiter) + 2] != delimiter + b"\r\n":
            raise Problem(400, "The upload is incomplete or malformed.")
        pos = len(delimiter) + 2
        while True:
            end_headers = body.find(b"\r\n\r\n", pos, min(pos + 8192, len(body)))
            if end_headers < 0:
                raise Problem(400, "The upload has invalid headers.")
            headers = email.message.Message()
            for line in body[pos:end_headers].split(b"\r\n"):
                if b":" not in line or line[:1] in (b" ", b"\t"):
                    raise Problem(400, "The upload has invalid headers.")
                key, value = line.split(b":", 1)
                headers[key.decode("ascii")] = value.decode("utf-8").strip()
            if len(headers.get_all("Content-Disposition", [])) != 1 or headers.get_content_disposition() != "form-data":
                raise Problem(400, "The upload has invalid fields.")
            name = headers.get_param("name", header="Content-Disposition")
            if name not in allowed or name in fields:
                raise Problem(400, "Unexpected or duplicate upload field.")
            start = end_headers + 4
            marker = b"\r\n" + delimiter
            end = body.find(marker, start)
            while end >= 0 and body[end + len(marker):end + len(marker) + 2] not in (b"\r\n", b"--"):
                end = body.find(marker, end + 1)
            if end < 0:
                raise Problem(400, "The upload ended before it was complete.")
            size = end - start
            if name == "video":
                if not headers.get_filename() or not 0 < size <= MAX_VIDEO:
                    raise Problem(413, "Choose a video under 100 MiB.")
                # Reject playlists/concat before a native parser can open nested references.
                signature = body[start:start + 16]
                if not (signature[4:8] == b"ftyp" or signature[:4] == b"\x1aE\xdf\xa3"):
                    raise Problem(415, "Choose an MP4, a modern MOV, or a WebM video.")
                with destination.open("xb") as output:
                    for offset in range(start, end, 65536):
                        output.write(body[offset:min(offset + 65536, end)])
                fields[name] = size
            else:
                if size > 2048:
                    raise Problem(400, "The text field is too long.")
                fields[name] = body[start:end].decode("utf-8")
            pos = end + len(marker)
            if body[pos:pos + 2] == b"--":
                if body[pos + 2:] not in (b"", b"\r\n"):
                    raise Problem(400, "The upload has an invalid ending.")
                break
            pos += 2
    if "video" not in fields:
        raise Problem(400, "Choose a video first.")
    if mode == "embed":
        fields["notice"] = clean_text(fields.get("notice", ""), 160, True)
        fields["creator"] = clean_text(fields.get("creator", ""), 80)
    else:
        value = fields.get("asset_id", "").strip()
        try:
            fields["asset_id"] = str(uuid.UUID(value)) if value else None
        except (ValueError, AttributeError):
            raise Problem(400, "The asset ID must be a UUID, or leave it blank.")
    return fields


class Service:
    def __init__(self, storage, python=None, engine=None, ttl=TTL, worker=True):
        self.storage = Path(storage).resolve()
        self.storage.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.python = python or os.environ.get("WATERMARK_PYTHON", sys.executable)
        self.engine = Path(engine or os.environ.get("WATERMARK_ENGINE", str(HERE.parents[1] / "tools/watermark/pixel_watermark.py"))).resolve()
        self.ttl = ttl
        self.jobs = {}
        self.lock = threading.RLock()
        self.pending = queue.Queue(maxsize=4)
        self.slots = threading.BoundedSemaphore(5)  # one active + four waiting/uploading
        self.uploads = threading.BoundedSemaphore(2)
        self.stop = threading.Event()
        self.child = None
        self.health_cache = (0, (False, "Checking the local engine…"))
        self.health_lock = threading.Lock()
        self._restore()
        if worker:
            threading.Thread(target=self._work, daemon=True).start()
            threading.Thread(target=self._reaper, daemon=True).start()

    def readiness(self):
        if not self.engine.is_file():
            return False, "The watermark engine is not installed yet. Follow the local setup guide."
        if not shutil.which(self.python):
            return False, "The watermark Python runtime is unavailable. Check WATERMARK_PYTHON."
        with self.health_lock:
            if time.monotonic() - self.health_cache[0] < 30:
                return self.health_cache[1]
            code = """import importlib.util,json,os,pathlib,runpy,sys
engine=runpy.run_path(sys.argv[1],run_name='_watermark_health')
missing=[m for m in ('torch','numpy','PIL','av','imageio_ffmpeg') if importlib.util.find_spec(m) is None]
model=os.environ.get('VIDEOSEAL_MODEL',engine.get('DEFAULT_MODEL',''))
print(json.dumps({'missing':missing,'model':bool(model and pathlib.Path(model).is_file())}))
"""
            try:
                run = subprocess.run([self.python, "-c", code, str(self.engine)], capture_output=True, timeout=10, check=True)
                result = json.loads(run.stdout)
                answer = (False, "Install the engine dependencies with the local setup guide: " + ", ".join(result["missing"])) if result["missing"] else (
                    (False, "The model file is missing. Set VIDEOSEAL_MODEL or run the setup script.") if not result["model"] else (True, "Ready on this computer."))
            except (OSError, subprocess.SubprocessError, ValueError, KeyError):
                answer = (False, "The local engine could not be checked. Follow the setup guide.")
            self.health_cache = (time.monotonic(), answer)
            return answer

    def _save(self, job):
        folder = self.storage / job["job_id"]
        tmp = folder / "job.tmp"
        tmp.write_text(json.dumps(job), encoding="utf-8")
        tmp.replace(folder / "job.json")

    def _restore(self):
        for folder in self.storage.iterdir():
            if not TOKEN.fullmatch(folder.name) or folder.is_symlink() or not folder.is_dir():
                continue
            try:
                job = json.loads((folder / "job.json").read_text())
                if job["job_id"] != folder.name or float(job["expires_at"]) <= time.time():
                    shutil.rmtree(folder)
                    continue
                if job.get("state") not in ("complete", "error", "denied"):
                    job.update(state="error", message="Processing was interrupted. Upload the video again.")
                (folder / "source.bin").unlink(missing_ok=True)
                (folder / "upload.body").unlink(missing_ok=True)
                if job["state"] in ("error", "denied"):
                    for artifact in folder.iterdir():
                        if artifact.name != "job.json" and (artifact.is_file() or artifact.is_symlink()):
                            artifact.unlink(missing_ok=True)
                self.jobs[folder.name] = job
                self._save(job)
            except (OSError, ValueError, KeyError, TypeError):
                shutil.rmtree(folder)

    def reserve(self, mode):
        ready, reason = self.readiness()
        if not ready:
            raise Problem(503, reason)
        self.cleanup()
        if not self.slots.acquire(blocking=False):
            raise Problem(503, "The local queue is full. Try again when a video finishes.")
        with self.lock:
            if len(self.jobs) >= 32:
                self.slots.release()
                raise Problem(503, "Local storage is full. Remove a finished job or wait for its files to expire.")
            token = secrets.token_urlsafe(32)
            folder = self.storage / token
            folder.mkdir(mode=0o700)
            now = time.time()
            job = dict(schema="tidebreak-mark.job.v1", asset_type="video", job_id=token, operation=mode,
                       state="uploading", message="Receiving video…", created_at=now, expires_at=now + self.ttl,
                       asset_id=str(uuid.uuid4()) if mode == "embed" else None)
            self.jobs[token] = job
            self._save(job)
            return job

    def abandon(self, job):
        with self.lock:
            self.jobs.pop(job["job_id"], None)
            shutil.rmtree(self.storage / job["job_id"], ignore_errors=True)
        self.slots.release()

    def submit(self, job, fields):
        with self.lock:
            job["fields"] = {k: v for k, v in fields.items() if k != "video"}
            if job["operation"] == "detect":
                job["asset_id"] = fields["asset_id"]
            job.update(state="queued", message="Waiting for the local processor…")
            self._save(job)
            try:
                self.pending.put_nowait(job["job_id"])
            except queue.Full:
                raise Problem(503, "The local queue is full. Try again shortly.")

    def snapshot(self, token):
        with self.lock:
            job = self.jobs.get(token)
            if not job or job["expires_at"] <= time.time():
                raise Problem(404, "This job is unavailable or has expired.")
            out = {k: v for k, v in job.items() if k != "fields"}
            if job["state"] == "complete":
                # Older retained jobs have no policy field. Keep their API result explicitly
                # unknown rather than interpreting their notice or absent field as permission.
                out["result"] = dict(job.get("result", {}))
                out["result"]["permission"] = result_permission(out["result"], job["operation"])
                kinds = ("video", "manifest") if job["operation"] == "embed" else ("report",)
                out["downloads"] = {k: "/api/jobs/%s/%s" % (token, k) for k in kinds}
            return out

    def update(self, job, **values):
        with self.lock:
            job.update(values)
            self._save(job)

    def _native(self, args, timeout):
        # No shell, and a process group makes timeout cover native decoder children as well.
        with tempfile.TemporaryFile() as errors:
            proc = subprocess.Popen([self.python, str(self.engine)] + args, stdin=subprocess.DEVNULL,
                                    stdout=errors, stderr=errors, start_new_session=True)
            self.child = proc
            try:
                code = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
                raise Problem(422, "Processing took too long. Try a shorter or smaller video.")
            finally:
                self.child = None
            if code:
                errors.seek(0)
                detail = errors.read(16000).decode("utf-8", "replace")
                print("Watermark engine error:", detail, file=sys.stderr)
                raise Problem(422, "This video could not be processed. Use a constant-frame-rate MP4 or WebM without rotation metadata.")

    @staticmethod
    def validate_probe(probe):
        try:
            duration = float(probe["duration_s"])
            width, height = int(probe["width"]), int(probe["height"])
            fps = float(probe["fps"])
            streams = probe["streams"]
            count = len(streams) if isinstance(streams, list) else int(streams)
        except (KeyError, ValueError, TypeError, OverflowError):
            raise Problem(422, "The video information could not be read safely.")
        if not math.isfinite(duration) or not 0 < duration <= 60:
            raise Problem(422, "Videos must be 60 seconds or shorter.")
        if not 0 < width <= 4096 or not 0 < height <= 4096 or width * height > 3840 * 2160:
            raise Problem(422, "Choose a video no larger than 4K.")
        if not math.isfinite(fps) or not 0 < fps <= 120 or not 1 <= count <= 8:
            raise Problem(422, "This video has an unsupported frame rate or too many streams.")
        if duration * fps > 3600 or duration * fps * width * height > MAX_PIXEL_FRAMES:
            raise Problem(422, "This video is too demanding for the local processor. Reduce its resolution, frame rate, or length.")

    def _process(self, job):
        folder = self.storage / job["job_id"]
        source = folder / "source.bin"
        try:
            self.update(job, state="probing", message="Checking your video…")
            probe_path = folder / "probe.json"
            self._native(["probe", "--input", str(source), "--report", str(probe_path)], 30)
            probe = json.loads(probe_path.read_text())
            self.validate_probe(probe)
            if job["operation"] == "embed":
                self.update(job, state="processing", message="Reading existing pixel instructions…")
                preflight_path = folder / "preflight.json"
                self._native(["detect", "--input", str(source), "--report", str(preflight_path)], 1800)
                if not preflight_path.is_file() or preflight_path.stat().st_size > 1024 * 1024:
                    raise Problem(422, "The existing watermark instructions could not be checked.")
                preflight = sanitize_report(json.loads(preflight_path.read_text()), folder)
                if not isinstance(preflight, dict):
                    raise Problem(422, "The existing watermark instructions could not be checked.")
                permission = permission_for_detection(preflight)
                if permission["decision"] == "deny" and {"copying", "ai_use"}.intersection(permission["restrictions"]):
                    self.update(job, state="denied", message="This video's embedded restrictions prohibit the copying or AI use needed to re-mark it. Re-marking was refused.",
                                result={"permission": permission, "detection": preflight, "denied_action": "re_watermark"})
                    return
                preflight_path.unlink()
            self.update(job, state="processing", message="Embedding the pixel identifier…" if job["operation"] == "embed" else "Looking for a pixel identifier…")
            args = [job["operation"], "--input", str(source)]
            if job["operation"] == "embed":
                args += ["--output", str(folder / "marked.mp4"), "--manifest", str(folder / "manifest.json"),
                         "--asset-id", job["asset_id"], "--notice", job["fields"]["notice"], "--policy-flags", "15"]
                if job["fields"].get("creator"):
                    args += ["--creator", job["fields"]["creator"]]
            else:
                args += ["--report", str(folder / "report.json")]
                if job["asset_id"]:
                    args += ["--asset-id", job["asset_id"]]
            self._native(args, 1800)
            json_path = folder / ("manifest.json" if job["operation"] == "embed" else "report.json")
            if not json_path.is_file() or json_path.stat().st_size > 1024 * 1024:
                raise Problem(422, "The processor did not return a valid report.")
            result = json.loads(json_path.read_text())
            if not isinstance(result, dict):
                raise Problem(422, "The processor did not return a valid report.")
            # A downloadable manifest may be shared publicly. Never leak server paths or the
            # secret job capability that happens to be part of those paths.
            result = sanitize_report(result, folder)
            result["permission"] = result_permission(result, job["operation"])
            if job["operation"] == "embed":
                if result["permission"]["decision"] != "deny" or set(result["permission"]["restrictions"]) != set(RESTRICTIONS.values()):
                    raise Problem(422, "The embedded restrictions could not be recovered. This video was not published.")
                video = folder / "marked.mp4"
                if not video.is_file() or not 0 < video.stat().st_size <= MAX_ARTIFACT:
                    raise Problem(422, "The output video exceeded the local download limit.")
                result["service"] = {"schema": "tidebreak-mark.asset.v1", "asset_type": "video",
                                     "notice_is_self_supplied": True, "creator_is_self_supplied": True}
            json_path.write_text(json.dumps(result, indent=2) + "\n")
            self.update(job, state="complete", message="Your marked video is ready." if job["operation"] == "embed" else "Verification finished.", result=result)
        except Problem as exc:
            self.update(job, state="error", message=exc.message)
        except Exception:
            import traceback
            traceback.print_exc()
            self.update(job, state="error", message="The local processor could not finish this video. Check the server log or try another file.")
        finally:
            source.unlink(missing_ok=True)
            (folder / "probe.json").unlink(missing_ok=True)
            if job["state"] in ("error", "denied"):
                # The engine may be killed before its own finally block can unlink a native
                # encoder's temporary file. This directory contains only this service's job.
                for artifact in folder.iterdir():
                    if artifact.name != "job.json" and (artifact.is_file() or artifact.is_symlink()):
                        artifact.unlink(missing_ok=True)

    def _work(self):
        while not self.stop.is_set():
            try:
                token = self.pending.get(timeout=0.5)
            except queue.Empty:
                continue
            try:
                with self.lock:
                    job = self.jobs.get(token)
                    if job:
                        # Claim before releasing the cleanup lock, so expiry cannot remove
                        # a queued directory between lookup and the first worker update.
                        self.update(job, state="probing", message="Checking your video…")
                if job:
                    self._process(job)
            finally:
                self.pending.task_done()
                self.slots.release()

    def cleanup(self):
        with self.lock:
            for token, job in list(self.jobs.items()):
                if job["expires_at"] <= time.time() and job["state"] not in ("uploading", "probing", "processing"):
                    self.jobs.pop(token)
                    shutil.rmtree(self.storage / token, ignore_errors=True)

    def _reaper(self):
        while not self.stop.wait(30):
            self.cleanup()

    def close(self):
        self.stop.set()
        if self.child and self.child.poll() is None:
            try:
                os.killpg(self.child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass


def sanitize_report(value, folder):
    if isinstance(value, dict):
        return {k: sanitize_report(v, folder) for k, v in value.items() if k not in ("input_path", "output_path", "source_path", "model_path")}
    if isinstance(value, list):
        return [sanitize_report(v, folder) for v in value]
    if isinstance(value, str):
        if str(folder) in value or folder.name in value:
            return "local video file"
        if value.startswith(("/", "file://")):
            return Path(value).name
    return value


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "VideoMark/1"

    def setup(self):
        super().setup()
        self.connection.settimeout(30)

    def log_message(self, fmt, *args):
        # Capability URLs must not be copied into access logs.
        pass

    def _guard(self):
        hosts = self.headers.get_all("Host", [])
        if len(hosts) != 1 or hosts[0] not in self.server.allowed_hosts:
            raise Problem(403, "This server only accepts its configured local address.")
        origins = self.headers.get_all("Origin", [])
        if len(origins) > 1 or (origins and origins[0] != "http://" + hosts[0]):
            raise Problem(403, "Open this app directly at its local address.")
        if self.headers.get("Sec-Fetch-Site") == "cross-site":
            raise Problem(403, "Cross-site requests are not accepted.")

    def _headers(self, status, content_type, length, extra=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Connection", "close")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; media-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.close_connection = True

    def _json(self, status, value):
        data = json.dumps(value).encode()
        self._headers(status, "application/json; charset=utf-8", len(data))
        self.wfile.write(data)

    def do_GET(self):
        try:
            self._guard()
            path = urlsplit(self.path).path
            if path == "/api/health":
                ready, reason = self.server.service.readiness()
                return self._json(200, {"ready": ready, "message": reason, "max_bytes": MAX_VIDEO, "max_duration_s": 60,
                                        "expires_after_s": TTL, "asset_types": ["video"]})
            static = {"/": ("index.html", "text/html; charset=utf-8"), "/app.js": ("app.js", "text/javascript; charset=utf-8"), "/style.css": ("style.css", "text/css; charset=utf-8")}
            if path in static:
                name, mime = static[path]
                return self._file(HERE / "static" / name, mime)
            match = re.fullmatch(r"/api/jobs/([A-Za-z0-9_-]{43})(?:/(video|manifest|report))?", path)
            if not match:
                raise Problem(404, "Page or file not found.")
            token, kind = match.groups()
            job = self.server.service.snapshot(token)
            if not kind:
                return self._json(200, job)
            if job["state"] != "complete" or kind not in job.get("downloads", {}):
                raise Problem(404, "This file is not available.")
            names = {"video": "marked.mp4", "manifest": "manifest.json", "report": "report.json"}
            target = self.server.service.storage / token / names[kind]
            return self._file(target, "video/mp4" if kind == "video" else "application/json", names[kind], kind == "video")
        except Problem as exc:
            self._json(exc.status, {"error": exc.message})
        except (BrokenPipeError, ConnectionResetError, TimeoutError):
            pass

    def _file(self, path, mime, filename=None, ranges=False):
        if path.is_symlink() or not path.is_file():
            raise Problem(404, "File not found.")
        size = path.stat().st_size
        if size > MAX_ARTIFACT:
            raise Problem(413, "This file is too large to download.")
        start, end, status = 0, size - 1, 200
        extra = {}
        if filename:
            extra["Content-Disposition"] = ('inline' if ranges else 'attachment') + '; filename="' + filename + '"'
        if ranges:
            extra["Accept-Ranges"] = "bytes"
        requested = self.headers.get("Range")
        if requested:
            match = re.fullmatch(r"bytes=(\d*)-(\d*)", requested) if ranges else None
            if not match or not any(match.groups()):
                raise Problem(416, "Invalid download range.")
            a, b = match.groups()
            if a:
                start, end = int(a), min(int(b), size - 1) if b else size - 1
            else:
                start = max(0, size - int(b))
            if not 0 <= start <= end < size:
                raise Problem(416, "The requested range is outside this file.")
            status = 206
            extra["Content-Range"] = "bytes %d-%d/%d" % (start, end, size)
        with path.open("rb") as source:
            source.seek(start)
            length = end - start + 1
            self._headers(status, mime, length, extra)
            while length:
                data = source.read(min(length, 65536))
                if not data:
                    break
                self.wfile.write(data)
                length -= len(data)

    def do_POST(self):
        job = None
        got_upload = False
        try:
            self._guard()
            mode = {"/api/jobs": "embed", "/api/verify": "detect"}.get(urlsplit(self.path).path)
            if not mode:
                raise Problem(404, "Endpoint not found.")
            lengths = self.headers.get_all("Content-Length", [])
            if self.headers.get("Transfer-Encoding") or len(lengths) != 1 or not re.fullmatch(r"[0-9]{1,12}", lengths[0]):
                raise Problem(411, "A valid Content-Length is required.")
            length = int(lengths[0])
            if not 0 < length <= MAX_BODY:
                raise Problem(413, "Choose a video under 100 MiB.")
            got_upload = self.server.service.uploads.acquire(blocking=False)
            if not got_upload:
                raise Problem(503, "Two uploads are already arriving. Try again shortly.")
            job = self.server.service.reserve(mode)
            folder = self.server.service.storage / job["job_id"]
            spool = folder / "upload.body"
            with spool.open("xb") as output:
                deadline = time.monotonic() + 120
                while length:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise Problem(408, "The upload took too long. Try again.")
                    self.connection.settimeout(min(30, remaining))
                    # read1 returns a partial socket read, so an absolute deadline is checked
                    # even when a peer trickles bytes without triggering the idle timeout.
                    data = self.rfile.read1(min(length, 65536))
                    if not data:
                        raise Problem(400, "The upload ended before it was complete.")
                    output.write(data)
                    length -= len(data)
            fields = parse_upload(spool, self.headers.get("Content-Type", ""), folder / "source.bin", mode)
            spool.unlink()
            self.server.service.submit(job, fields)
            result = self.server.service.snapshot(job["job_id"])
            job = None  # queue owns cleanup now, including if the browser disconnects
            self._json(202, result)
        except Problem as exc:
            self._json(exc.status, {"error": exc.message})
        except (UnicodeError, ValueError):
            self._json(400, {"error": "The upload is malformed."})
        except (BrokenPipeError, ConnectionResetError, TimeoutError):
            pass
        finally:
            if job is not None:
                self.server.service.abandon(job)
            if got_upload:
                self.server.service.uploads.release()

    def do_DELETE(self):
        try:
            self._guard()
            match = re.fullmatch(r"/api/jobs/([A-Za-z0-9_-]{43})", urlsplit(self.path).path)
            if not match:
                raise Problem(404, "Job not found.")
            token = match.group(1)
            service = self.server.service
            with service.lock:
                job = service.snapshot(token)
                if job["state"] not in ("complete", "error", "denied"):
                    raise Problem(409, "Wait for processing to finish before removing this job.")
                service.jobs.pop(token)
                shutil.rmtree(service.storage / token, ignore_errors=True)
            self._json(200, {"deleted": True})
        except Problem as exc:
            self._json(exc.status, {"error": exc.message})


class LocalServer(ThreadingHTTPServer):
    """Bound even connections that never finish sending their HTTP headers."""
    def __init__(self, *args):
        self.request_slots = threading.BoundedSemaphore(16)
        super().__init__(*args)

    def process_request(self, request, client_address):
        if not self.request_slots.acquire(blocking=False):
            try:
                request.settimeout(1)
                request.sendall(b"HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            finally:
                self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.request_slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.request_slots.release()


def make_server(host, port, service):
    server = LocalServer((host, port), Handler)
    server.daemon_threads = True
    server.service = service
    actual_port = server.server_address[1]
    aliases = {host, "localhost", "127.0.0.1"} if host in ("127.0.0.1", "localhost") else {host}
    server.allowed_hosts = {"%s:%d" % (h, actual_port) for h in aliases}
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1", choices=["127.0.0.1", "localhost"])
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--storage", type=Path, default=Path(tempfile.gettempdir()) / ("tidebreak-mark-%s" % os.getuid()))
    args = parser.parse_args()
    service = Service(args.storage)
    server = make_server(args.host, args.port, service)
    print("Tidebreak Mark: http://127.0.0.1:%d — %s" % (server.server_address[1], service.readiness()[1]), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        service.close()
        server.server_close()


if __name__ == "__main__":
    main()
