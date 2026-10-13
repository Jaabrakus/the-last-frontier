#!/usr/bin/env python3
"""VideoSeal pixel restrictions and identifiers. No automatic copy prevention.

The TBW2 pixel payload carries UUID and explicit deny flags. Legacy TBW1 carries
only UUID. Checksums detect corruption, not identity or ownership. A matching
detector can act on the policy; embedding cannot force other systems to obey.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import struct
import subprocess
import sys
import tempfile
import time
import uuid
import zlib
from fractions import Fraction

MODEL_URL = "https://dl.fbaipublicfiles.com/videoseal/y_256b_img.jit"
MODEL_SHA256 = "5c7a4581c36fc6090aafdcfb3999123bae5172a4847f22e2da4e7fd1a39d1e1b"
DEFAULT_MODEL = "/private/tmp/tidebreak-videoseal-model/y_256b_img.jit"
MAGIC = b"TBW2"
ALL_DENY_FLAGS = 15
LIMIT_SECONDS = 60
LIMIT_PIXELS = 3840 * 2160


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as out:
        json.dump(value, out, indent=2, ensure_ascii=False, allow_nan=False)
        out.write("\n")


def input_format(path):
    path = Path(path).resolve(strict=True)
    require(path.is_file(), "Input must be a local regular file")
    with path.open("rb") as source:
        header = source.read(16)
    if len(header) >= 12 and header[4:8] == b"ftyp":
        return "mov"
    if header[:4] == b"\x1aE\xdf\xa3":
        return "matroska"
    raise ValueError("Only self-contained MP4/MOV (ftyp) or WebM/Matroska inputs are supported")


def open_media(path):
    import av
    fmt = input_format(path)
    return av.open(str(path), mode="r", format=fmt, options={
        "protocol_whitelist": "file,pipe", "enable_drefs": "0", "use_absolute_path": "0",
        "max_streams": "2"})


def probe(path):
    with open_media(path) as media:
        require(len(media.streams.video) == 1, "Exactly one video stream is required")
        require(len(media.streams.audio) <= 1 and len(media.streams) <= 2,
                "Only one video and optional single audio stream are supported")
        video = media.streams.video[0]
        rate = video.average_rate or video.base_rate
        require(rate and rate > 0, "Video has no usable frame rate")
        duration = float(video.duration * video.time_base) if video.duration is not None else (
            media.duration / 1e6 if media.duration is not None else None)
        require(duration is not None and 0 < duration <= LIMIT_SECONDS + 0.01,
                "Video must have a known duration of at most 60 seconds")
        require(0 < video.width * video.height <= LIMIT_PIXELS, "Video exceeds 3840×2160 pixels")
        require(float(rate) <= 120, "Video exceeds 120 fps")
        require(duration * float(rate) * video.width * video.height <= 8_000_000_000,
                "Video exceeds the eight-billion pixel-frame work limit")
        require(video.codec_context.color_trc not in (16, 18), "HDR PQ/HLG input is unsupported")
        if media.streams.audio:
            audio = media.streams.audio[0]
            require(0 < audio.codec_context.sample_rate <= 192000 and
                    0 < len(audio.codec_context.layout.channels) <= 8,
                    "Audio exceeds 192kHz/eight channels or has no sample format")
            if audio.duration is not None:
                require(0 <= float(audio.duration * audio.time_base) <= LIMIT_SECONDS + 0.1,
                        "Audio track exceeds the 60-second limit including codec padding")
        rotation = video.metadata.get("rotate", "0")
        require(float(rotation) % 360 == 0, "Rotation metadata is unsupported; normalize orientation first")
        return {"schema": "pixel-watermark-probe/v1", "duration_s": duration,
                "width": video.width, "height": video.height, "fps": float(rate),
                "fps_fraction": str(rate), "declared_frames": video.frames,
                "format": media.format.name, "metadata": dict(media.metadata),
                "streams": [{"type": s.type, "codec": s.codec_context.name,
                             "metadata": dict(s.metadata)} for s in media.streams]}


def payload(asset_id, flags=ALL_DENY_FLAGS, version="TBW2"):
    identifier = uuid.UUID(asset_id.removeprefix("urn:uuid:"))
    require(isinstance(flags, int) and 0 <= flags <= ALL_DENY_FLAGS, "Unknown policy flags")
    require(version in ("TBW1", "TBW2"), "Unknown payload version")
    head = version.encode("ascii") + identifier.bytes
    if version == "TBW2":
        head += bytes([flags, 0, 0, 0])
    body = head + struct.pack(">I", zlib.crc32(head))
    return body + hashlib.sha256(body).digest()[:32 - len(body)]


def policy_object(flags):
    actions = [text for bit, text in ((1, "copy"), (8, "redistribute"),
               (2, "train AI on"), (4, "use this content with AI")) if flags & bit]
    if flags == ALL_DENY_FLAGS:
        instruction = "Do not copy, redistribute, train AI on, or use this content with AI."
    elif not flags:
        instruction = "No permission is conveyed by this payload."
    else:
        instruction = "Restrictions: " + "; ".join("do not " + a for a in actions) + "."
    return {"schema": "pixel-use-policy/v1", "flags": flags,
            "deny_copying": bool(flags & 1), "deny_ai_training": bool(flags & 2),
            "deny_ai_inference": bool(flags & 4), "deny_redistribution": bool(flags & 8),
            "instruction": instruction}


def decode_payload(raw):
    if len(raw) != 32 or raw[:4] not in (b"TBW1", b"TBW2"):
        return None
    version = raw[:4].decode("ascii")
    head_size = 20 if version == "TBW1" else 24
    if version == "TBW2" and (raw[20] & ~ALL_DENY_FLAGS or raw[21:24] != bytes(3)):
        return None
    if struct.unpack(">I", raw[head_size:head_size + 4])[0] != zlib.crc32(raw[:head_size]):
        return None
    body_size = head_size + 4
    if raw[body_size:] != hashlib.sha256(raw[:body_size]).digest()[:32 - body_size]:
        return None
    policy = policy_object(raw[20]) if version == "TBW2" else None
    return {"asset_id": str(uuid.UUID(bytes=raw[4:20])), "payload_version": version,
            "policy_state": "deny" if policy and policy["flags"] else "unknown", "policy": policy}


def unpack_payload(raw):
    decoded = decode_payload(raw)
    return decoded["asset_id"] if decoded else None


def load_model(args):
    import torch
    model_path = Path(args.model).resolve(strict=True)
    require(sha256(model_path) == MODEL_SHA256, "Model hash differs from pinned official VideoSeal model")
    torch.set_num_threads(min(4, os.cpu_count() or 1))
    device = args.device
    if device == "auto":
        # Torch2.6 MPS lacks the model's antialiased resize; avoid silent fallback.
        device = "cuda" if torch.cuda.is_available() else "cpu"
    model = torch.jit.load(str(model_path), map_location="cpu").eval().to(device)
    return model, device


def model_record(device):
    import torch
    return {"algorithm": "Meta VideoSeal 1.0", "model": "y_256b_img.jit",
            "model_url": MODEL_URL, "model_sha256": MODEL_SHA256, "license": "MIT",
            "payload_format": "TBW2 / UUID128 / deny flags8 / reserved24 / CRC32 / SHA256-first32 (256 bits); TBW1 read compatibility",
            "torch": torch.__version__, "python": platform.python_version(),
            "device": device, "strength": 0.2, "video_step_size": 4,
            "checksums_are_authentication": False}


def video_frames(media):
    """Bound real decode work too, rather than trusting container duration tags."""
    stream = media.streams.video[0]
    rate = stream.average_rate or stream.base_rate
    max_frames = min(LIMIT_SECONDS * 120, math.ceil(LIMIT_SECONDS * float(rate)) + 1)
    pixel_frames = 0
    for index, frame in enumerate(media.decode(video=0)):
        require(index < max_frames, "Decoded frame count exceeds limit")
        require(0 < frame.width * frame.height <= LIMIT_PIXELS, "Decoded dimensions exceed limit")
        pixel_frames += frame.width * frame.height
        require(pixel_frames <= 8_000_000_000, "Decoded pixel-frame work exceeds limit")
        require(frame.pts is not None and 0 <= float(frame.pts * frame.time_base) <= LIMIT_SECONDS,
                "Decoded presentation time exceeds limit")
        require(getattr(frame, "rotation", 0) % 360 == 0, "Rotated video is unsupported")
        require(frame.format.name in ("yuv420p", "yuvj420p", "yuv422p", "yuv444p", "nv12", "rgb24", "bgr24", "rgba", "bgra"),
                "Only 8-bit SDR input is supported; HDR/10-bit requires a color-managed pipeline")
        yield frame


def detect(path, args, model=None, device=None):
    import numpy as np
    import torch
    info = probe(path)
    if model is None:
        model, device = load_model(args)
    # Uniform sampling throughout the clip; aggregation uses pixel predictions only.
    estimated = max(1, round(info["duration_s"] * info["fps"]))
    chosen = set(np.linspace(0, estimated - 1, min(64, estimated)).round().astype(int).tolist())
    total = np.zeros(256, dtype=np.float64)
    sampled = []
    with open_media(path) as media, torch.inference_mode():
        for index, frame in enumerate(video_frames(media)):
            if index not in chosen:
                continue
            array = frame.to_ndarray(format="rgb24")
            tensor = torch.from_numpy(array.copy()).permute(2, 0, 1).unsqueeze(0).float().to(device) / 255
            predictions = model.detect(tensor, is_video=True)[:, 1:]
            if predictions.ndim > 2:
                predictions = predictions.mean(dim=tuple(range(2, predictions.ndim)))
            total += predictions.mean(dim=0).cpu().numpy().astype(np.float64)
            sampled.append(index)
    require(sampled, "No frames could be sampled")
    logits = total / len(sampled)
    bits = (logits > 0).astype(np.uint8)
    raw = np.packbits(bits, bitorder="big").tobytes()
    decoded = decode_payload(raw)
    recovered = decoded["asset_id"] if decoded else None
    expected = str(uuid.UUID(args.asset_id.removeprefix("urn:uuid:"))) if args.asset_id else None
    agreement = None
    if expected:
        version = decoded["payload_version"] if decoded else "TBW2"
        flags = args.policy_flags if args.policy_flags is not None else (
            decoded["policy"]["flags"] if decoded and decoded["policy"] else ALL_DENY_FLAGS)
        expected_bits = np.unpackbits(np.frombuffer(payload(expected, flags, version), dtype=np.uint8), bitorder="big")
        agreement = float(np.mean(bits == expected_bits))
    policy = decoded["policy"] if decoded else None
    return {"schema": "pixel-watermark-detection/v2", "valid": recovered is not None,
            "recovered_asset_id": recovered, "expected_asset_id": expected,
            "matches_expected": recovered == expected if expected else None,
            "payload_version": decoded["payload_version"] if decoded else None,
            "policy_state": decoded["policy_state"] if decoded else "unknown", "policy": policy,
            "expected_policy_flags": args.policy_flags,
            "matches_expected_policy": bool(policy and policy["flags"] == args.policy_flags) if args.policy_flags is not None else None,
            "expected_bit_accuracy": agreement, "sampled_frames": sampled,
            "sample_count": len(sampled), "raw_payload_hex": raw.hex(),
            "minimum_absolute_mean_logit": float(np.min(np.abs(logits))),
            "mean_absolute_mean_logit": float(np.mean(np.abs(logits))),
            "input_sha256": sha256(path), "model": model_record(device),
            "uses_container_metadata_for_detection": False,
            "limits": "Decoded restrictions are a request for cooperating systems, not forced enforcement or issuer authentication. Unknown/legacy/negative results grant no permission."}


def playback(path):
    """Actual decoded frame PTS and audio payload/sample facts, independent of tags."""
    import numpy as np
    info = probe(path)
    rate = Fraction(info["fps_fraction"])
    timestamps = hashlib.sha256()
    count = 0
    max_error = 0.0
    with open_media(path) as media:
        for frame in video_frames(media):
            require(frame.pts is not None, "Video frame has no presentation timestamp")
            value = frame.pts * frame.time_base
            max_error = max(max_error, abs(float(value - Fraction(count, 1) / rate)))
            timestamps.update((str(value) + "\n").encode())
            count += 1
    require(count > 0 and max_error < 0.000002, "Only zero-start constant-frame-rate video is supported")
    audio = None
    with open_media(path) as media:
        if media.streams.audio:
            digest = hashlib.sha256()
            packet_times = hashlib.sha256()
            packets = 0
            audio_bytes = 0
            for packet in media.demux(media.streams.audio[0]):
                if not packet.size:
                    continue
                require(packet.pts is not None and -0.1 <= float(packet.pts * packet.time_base) <= LIMIT_SECONDS + 0.1,
                        "Audio packet time exceeds limit")
                audio_bytes += packet.size
                require(packets < 100000 and audio_bytes <= 256 * 1024 * 1024, "Audio packet work exceeds limit")
                digest.update(bytes(packet))
                packet_times.update((str(packet.pts * packet.time_base) + "\n").encode())
                packets += 1
            audio = {"compressed_payload_sha256": digest.hexdigest(),
                     "packet_pts_sha256": packet_times.hexdigest(), "packets": packets}
    if audio is not None:
        with open_media(path) as media:
            pcm = hashlib.sha256()
            samples = 0
            first = None
            last = None
            first_time = None
            for frame in media.decode(audio=0):
                require(0 < frame.sample_rate <= 192000 and len(frame.layout.channels) <= 8,
                        "Decoded audio format exceeds limit")
                require(frame.pts is not None, "Audio frame has no presentation timestamp")
                pts = frame.pts * frame.time_base
                require(-0.1 <= float(pts) <= LIMIT_SECONDS + 0.1 and
                        samples + frame.samples <= (LIMIT_SECONDS + 0.1) * frame.sample_rate,
                        "Decoded audio work exceeds limit")
                if first_time is None:
                    first_time = pts
                require(abs(float(pts - first_time - Fraction(samples, frame.sample_rate))) < 0.000002,
                        "Decoded audio has a timing discontinuity")
                array = frame.to_ndarray()
                # Hash sample-major float32 bytes; independent of packet grouping.
                if frame.format.is_planar:
                    array = array.T
                pcm.update(np.ascontiguousarray(array, dtype=np.float32).tobytes())
                samples += frame.samples
                if first is None:
                    first = str(frame.pts * frame.time_base)
                last = str(frame.pts * frame.time_base + Fraction(frame.samples, frame.sample_rate))
            audio.update({"decoded_pcm_sha256": pcm.hexdigest(), "decoded_samples": samples,
                          "first_pts": first, "decoded_end": last, "continuous": True})
    return {"width": info["width"], "height": info["height"], "fps_fraction": str(rate),
            "frames": count, "duration_s": count / float(rate),
            "display_pts_sha256": timestamps.hexdigest(), "max_cfr_error_s": max_error,
            "audio": audio, "metadata": info["metadata"]}


def quality_samples(source, output, count=12):
    import numpy as np
    info = probe(source)
    estimated = max(1, round(info["duration_s"] * info["fps"]))
    chosen = set(np.linspace(0, estimated - 1, min(count, estimated)).round().astype(int).tolist())
    rows = []
    with open_media(source) as original, open_media(output) as marked:
        for index, (a, b) in enumerate(zip(video_frames(original), video_frames(marked))):
            if index not in chosen:
                continue
            delta = a.to_ndarray(format="rgb24").astype(np.float32) - b.to_ndarray(format="rgb24").astype(np.float32)
            mse = float(np.mean(delta * delta, dtype=np.float64))
            rows.append({"frame": index, "psnr_db": 10 * math.log10(255 ** 2 / max(mse, 1e-12)),
                         "mean_absolute_rgb_delta_255": float(np.mean(np.abs(delta))),
                         "p99_absolute_rgb_delta_255": float(np.percentile(np.abs(delta), 99))})
    return {"method": "Decoded RGB source versus final H264 output, uniformly sampled; includes re-encode loss",
            "samples": rows, "mean_psnr_db": sum(r["psnr_db"] for r in rows) / len(rows),
            "minimum_psnr_db": min(r["psnr_db"] for r in rows),
            "visual_review_required": True}


def embed(args):
    import imageio_ffmpeg
    import numpy as np
    import torch
    source = Path(args.input).resolve(strict=True)
    output = Path(args.output).resolve()
    manifest = Path(args.manifest).resolve()
    require(source != output and source != manifest and output != manifest, "Input, output and manifest must be distinct")
    require(not output.exists() and not manifest.exists(), "Refusing existing output or manifest")
    require(output.suffix.lower() == ".mp4", "Output must use .mp4")
    require(args.notice and len(args.notice) <= 4000, "Notice must contain 1–4000 characters")
    identifier = str(uuid.UUID(args.asset_id.removeprefix("urn:uuid:")))
    info = probe(source)
    source_hash = sha256(source)
    before = playback(source)
    model, device = load_model(args)
    encoded_policy = policy_object(args.policy_flags)
    message = torch.tensor(np.unpackbits(np.frombuffer(payload(identifier, args.policy_flags), dtype=np.uint8), bitorder="big").copy(),
                           dtype=torch.float32, device=device).unsqueeze(0)
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(prefix=".pixel-watermark-", suffix=".mp4", dir=output.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    rights = {"schema": "pixel-watermark-notice/v2", "asset_id": identifier,
              "notice": args.notice, "source_sha256": source_hash,
              "payload_version": "TBW2", "policy": encoded_policy}
    if args.creator:
        rights["creator"] = args.creator
    encoder = None
    started = time.monotonic()
    try:
        command = [imageio_ffmpeg.get_ffmpeg_exe(), "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
                   "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f'{info["width"]}x{info["height"]}',
                   "-r", info["fps_fraction"], "-i", "pipe:0", "-protocol_whitelist", "file,pipe",
                   "-f", input_format(source)]
        if input_format(source) == "mov":
            command += ["-enable_drefs", "0", "-use_absolute_path", "0"]
        command += ["-i", str(source), "-map", "0:v:0", "-map", "1:a?", "-map_metadata", "1",
                    "-c:v", "libx264", "-preset", "fast", "-crf", str(args.crf), "-threads", "4",
                    "-pix_fmt", "yuv420p", "-fps_mode", "passthrough", "-c:a", "copy",
                    "-metadata", "pixel_watermark=" + json.dumps(rights, ensure_ascii=False, separators=(",", ":")),
                    "-movflags", "+faststart+use_metadata_tags", str(temporary)]
        with tempfile.TemporaryFile() as encoder_log:
            encoder = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=encoder_log)
            frames = []
            completed = 0

            def process_chunk():
                nonlocal completed
                tensor = torch.from_numpy(np.stack(frames)).permute(0, 3, 1, 2).float().to(device) / 255
                with torch.inference_mode():
                    marked = model.embed(tensor, message, is_video=True)
                    array = (marked.clamp(0, 1) * 255).round().to(torch.uint8).permute(0, 2, 3, 1).cpu().numpy()
                encoder.stdin.write(array.tobytes())
                completed += len(frames)
                frames.clear()
                if completed % 120 == 0:
                    print(f"Embedded {completed}/{before['frames']} frames ({time.monotonic()-started:.1f}s)", file=sys.stderr, flush=True)

            with open_media(source) as media:
                for frame in video_frames(media):
                    frames.append(frame.to_ndarray(format="rgb24"))
                    if len(frames) == 4:
                        process_chunk()
                if frames:
                    process_chunk()
            encoder.stdin.close()
            status = encoder.wait()
            encoder_log.seek(0)
            require(status == 0, "FFmpeg encode failed: " + encoder_log.read().decode(errors="replace"))
        print("Checking playback, pixel recovery and quality…", file=sys.stderr, flush=True)
        after = playback(temporary)
        for key in ("frames", "width", "height", "fps_fraction", "duration_s", "display_pts_sha256", "audio"):
            require(before[key] == after[key], f"Playback preservation failed for {key}")
        metadata_changes = {key: {"source": value, "output": after["metadata"].get(key)}
                            for key, value in before["metadata"].items() if after["metadata"].get(key) != value}
        # Container brands/encoder identify the new encode; attribution is retained.
        require(not (set(metadata_changes) - {"major_brand", "minor_version", "compatible_brands", "encoder"}),
                "Existing descriptive metadata was not retained")
        detection = detect(temporary, args, model, device)
        require(detection["valid"] and detection["matches_expected"], "Watermark failed exact UUID recovery after encoding")
        require(detection["payload_version"] == "TBW2" and detection["matches_expected_policy"],
                "Watermark failed exact pixel restriction recovery after encoding")
        quality = quality_samples(source, temporary)
        require(sha256(source) == source_hash, "Source changed during processing")
        result = {"schema": "pixel-watermark-manifest/v2", "asset_id": identifier, "notice": args.notice,
                  "payload_version": "TBW2", "policy_state": detection["policy_state"], "policy": detection["policy"],
                  "source": str(source), "output": str(output), "source_sha256": source_hash,
                  "output_sha256": sha256(temporary), "model": model_record(device),
                  "detection": detection, "source_playback": before, "output_playback": after,
                  "quality": quality, "container_metadata_changes": metadata_changes,
                  "encode": {"codec": "libx264", "crf": args.crf, "preset": "fast", "audio": "stream-copy"},
                  "elapsed_s": time.monotonic() - started,
                  "limitations": ["The UUID and explicit restriction flags are embedded in pixels; free-text notice/creator remain metadata and manifest claims.",
                                  "A matching detector can recover the deny instruction; unrelated systems are not compelled to recognize or obey it. Unknown policy never grants permission.",
                                  "No authentication, ownership proof, registration, DRM, AI-blocking or guaranteed survival of transformations."]}
        if args.creator:
            result["creator"] = args.creator
        # Hard-link publication is atomic and refuses replacing a raced existing file.
        os.link(temporary, output)
        try:
            write_json(manifest, result)
        except Exception:
            output.unlink()
            raise
        print(json.dumps({"output": str(output), "manifest": str(manifest), "asset_id": identifier,
                          "valid": True, "elapsed_s": result["elapsed_s"]}))
    finally:
        if encoder is not None and encoder.poll() is None:
            encoder.kill()
            encoder.wait()
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("probe", "embed", "detect"):
        command = sub.add_parser(name)
        command.add_argument("--input", required=True)
        if name == "probe":
            command.add_argument("--report", required=True)
            continue
        command.add_argument("--model", default=os.environ.get("VIDEOSEAL_MODEL", DEFAULT_MODEL))
        command.add_argument("--device", choices=("auto", "cpu", "mps", "cuda"), default="auto")
        command.add_argument("--asset-id", required=name == "embed")
        command.add_argument("--policy-flags", type=int, choices=range(16), default=ALL_DENY_FLAGS if name == "embed" else None,
                             help="TBW2 deny bits:1 copying,2 AI training,4 AI inference/reference use,8 redistribution; embed default15")
        if name == "detect":
            command.add_argument("--report", required=True)
        else:
            command.add_argument("--output", required=True)
            command.add_argument("--manifest", required=True)
            command.add_argument("--notice", required=True)
            command.add_argument("--creator")
            command.add_argument("--crf", type=int, choices=range(0, 31), default=18)
    args = parser.parse_args()
    try:
        if args.command == "embed":
            embed(args)
        else:
            require(Path(args.input).resolve() != Path(args.report).resolve(), "Refusing source overwrite")
            require(not Path(args.report).exists(), "Refusing existing report")
            result = probe(args.input) if args.command == "probe" else detect(args.input, args)
            write_json(args.report, result)
            print(json.dumps(result))
    except (Exception, KeyboardInterrupt) as error:
        print(f"pixel_watermark: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
