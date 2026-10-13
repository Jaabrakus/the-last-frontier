#!/usr/bin/env python3
"""Read-only, independent verification of the 60-second Tidebreak trailer.

Uses PyAV/numpy/Pillow/imageio-ffmpeg from the persistent watermark runtime.
No renderer/GPU, builder imports, media writes, or source edits. Writes evidence
only below --out (default artifacts/tidebreak_trailer_60/verification).

  services/watermark/.runtime/bin/python tools/ring/verify_tidebreak_trailer.py \
      --master /path/master.mp4 --edit-manifest /path/edit/manifest.json \
      [--marked /path/pixelmarked.mp4] [--out /path/new-verification-dir]

Freeze checks exclude only the intentional 0–0.2 and 59.7–60 s edge fades.
Exact luma repeats are reported individually; >=12 consecutive near-static
frames (luma mean absolute delta <=0.02/255) also fail pending visual review.
These detect repeats, not every possible visual defect or subjective quality.
"""
from __future__ import annotations

import argparse
import csv
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import time
import traceback

import av
import imageio_ffmpeg
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FPS = 60
FRAMES = 3600
RATE = 48000
SAMPLES = 60 * RATE


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda:f.read(1024*1024), b""):
            h.update(block)
    return h.hexdigest()


def runs(indices):
    """Repeated-pair endpoint indices -> inclusive runs of video frames."""
    out = []
    for n in indices:
        if out and n == out[-1][1]+1:
            out[-1][1] = n
        else:
            out.append([n-1, n])
    return [{"first_frame":a, "last_frame":b, "frames":b-a+1,
             "start_s":a/FPS, "end_s":(b+1)/FPS} for a,b in out]


def db(x):
    return 20*math.log10(max(float(x), 1e-12))


def check_frame_map(manifest_path):
    manifest = json.loads(manifest_path.read_text())
    map_path = Path(manifest["source_map"])
    with map_path.open(newline="") as f:
        rows = list(csv.DictReader(f))
    errors, takes, seen, normalized, sample_rows = [], {}, set(), [], {}
    if manifest.get("status") != "encoded":
        errors.append("Edit manifest has not completed encoding")
    if len(rows) != FRAMES:
        errors.append(f"Map has {len(rows)} rows, expected {FRAMES}")
    for i, row in enumerate(rows):
        take = Path(row["take"]).resolve()
        if take not in takes:
            index = {}
            for line in (take/"frames.txt").read_text().splitlines():
                if not line or line.startswith("#"):
                    continue
                n, engine, element, stamp = line.split()
                if int(n) in index:
                    errors.append(f"Duplicate source index {take}:{n}")
                index[int(n)] = (int(engine), element, float(stamp))
            timings = {}
            for line in (take/"timing.jsonl").read_text().splitlines():
                item = json.loads(line)
                if int(item["frame"]) in timings:
                    errors.append(f"Duplicate timing index {take}:{item['frame']}")
                timings[int(item["frame"])] = item
            takes[take] = {"frames":index, "timings":timings,
                           "frames_sha256":sha(take/"frames.txt"),
                           "timing_sha256":sha(take/"timing.jsonl")}
        n, engine, ef = [int(row[k]) for k in ("source_frame", "engine_frame", "element_frame")]
        key = (str(take), n)
        if int(row["output_frame"]) != i:
            errors.append(f"Output row sequence mismatch at {i}")
        if key in seen:
            errors.append(f"Source frame reused at output {i}: {key}")
        seen.add(key)
        actual = takes[take]["frames"].get(n)
        timing = takes[take]["timings"].get(n)
        if actual is None or timing is None:
            errors.append(f"Source/timing row missing at output {i}")
        else:
            if actual[:2] != (engine, row["element"]) or abs(actual[2]-ef/FPS) > .000051:
                errors.append(f"frames.txt disagrees with map at output {i}")
            if (timing["engine_frame"] != engine or timing["element"] != row["element"]
                    or abs(timing["video_s"]-ef/FPS) > 1e-6):
                errors.append(f"Timing timestamp/identity disagrees with map at output {i}")
            if abs(timing["time_scale"]-1) > 1e-9 or abs(timing["process_delta_s"]-1/FPS) > 1e-8:
                errors.append(f"Non-normal playback timing at output {i}")
        source = take/"frames"/f"f{n:05d}.jpg"
        if not source.is_file():
            errors.append(f"Source image missing at output {i}")
        normalized.append({"output_frame":i, "take":str(take), "source_frame":n,
                           "engine_frame":engine, "element":row["element"],
                           "element_frame":ef, "source_image":str(source)})
    expected_cursor = 0
    cuts = []
    for cut in manifest["cuts"]:
        start, end = round(cut["output_start_s"]*FPS), round(cut["output_end_s"]*FPS)
        selected = normalized[start:end]
        target_start, target_length = round(cut["start_s"]*FPS), round(cut["duration_s"]*FPS)
        problems = []
        if start != expected_cursor or end-start != target_length or len(selected) != target_length:
            problems.append("Cut coverage/length is not contiguous")
        expected_cursor = end
        for j, row in enumerate(selected):
            if (row["take"] != str(Path(cut["take"]).resolve()) or row["element"] != cut["element"]
                    or row["element_frame"] != target_start+j):
                problems.append(f"Cut source choice mismatch at output {row['output_frame']}")
        for a,b in zip(selected, selected[1:]):
            if b["source_frame"] != a["source_frame"]+1 or b["engine_frame"] != a["engine_frame"]+1:
                problems.append(f"Non-contiguous source/engine frame at output {b['output_frame']}")
        if selected and (selected[0]["source_frame"] != cut["first_source_frame"]
                         or selected[-1]["source_frame"] != cut["last_source_frame"]):
            problems.append("Cut source endpoints disagree")
        # At least three picture checks per cut, avoiding the global edge fades.
        for at in (start+min(30, max(1,target_length//5)), (start+end)//2, end-min(30,max(1,target_length//5))):
            if start <= at < end and 12 <= at < 3582:
                sample_rows[at] = normalized[at]
        errors.extend(problems)
        cuts.append({"element":cut["element"], "output_start_frame":start,
                     "output_end_frame_exclusive":end, "source_start_frame":target_start,
                     "frames":len(selected), "passed":not problems})
    if expected_cursor != FRAMES:
        errors.append("Cuts do not cover exactly 3600 frames")
    result = {"passed":not errors, "errors":errors, "rows":len(rows), "unique_sources":len(seen),
              "cuts":cuts, "sampled_picture_frames":sorted(sample_rows),
              "manifest_sha256":sha(manifest_path), "frame_map_sha256":sha(map_path),
              "takes":[{"path":str(k), "frames_sha256":v["frames_sha256"],
                        "timing_sha256":v["timing_sha256"]} for k,v in takes.items()],
              "scope":"Every CSV row joined to capture frame/timing records; every cut has unit source/engine/frame steps and time_scale=1. This alone does not establish encoded pixel identity."}
    return result, manifest, sample_rows


def picture_match(frame, row, titles, index):
    size = (320, 180)
    decoded = frame.reformat(width=size[0], height=size[1], format="rgb24").to_ndarray()
    with Image.open(row["source_image"]) as im:
        source = np.asarray(im.convert("RGB").resize(size, Image.Resampling.BILINEAR))
    expected = source.astype(np.float32)
    visibility = np.ones((size[1],size[0]), np.float32)
    for title in titles:
        if title["start_s"] <= index/FPS <= title["end_s"]:
            with Image.open(title["file"]) as im:
                rgba = np.asarray(im.convert("RGBA").resize(size, Image.Resampling.BILINEAR),np.float32)
            fade = title.get("fade_s",.4)
            opacity = max(0,min(1,(index/FPS-title["start_s"])/fade,
                                (title["end_s"]-index/FPS)/fade))
            alpha = rgba[:,:,3]/255*opacity
            expected = expected*(1-alpha[:,:,None])+rgba[:,:,:3]*alpha[:,:,None]
            visibility *= 1-alpha
    # Opening/closing cards shade the whole frame. Account for that tint while
    # rejecting opaque title text: retain pixels with >=40% source visibility.
    mask = visibility >= .4
    valid = float(mask.mean())
    delta = np.abs(decoded.astype(np.float32)-expected)
    mae = float(delta[mask].mean()) if valid > 0 else None
    return {"output_frame":index, "source_image":row["source_image"],
            "source_visible_fraction":valid, "mean_abs_rgb_error_255":mae,
            "threshold_255":12, "passed":valid >= .2 and mae is not None and mae < 12,
            "scope":"Downsampled picture resemblance with title shading/fades accounted for, excluding opaque title content; tolerant of encoding/watermark. Not proof of exact source-frame identity."}


def decode_video(path, sample_rows, titles):
    pts_errors, dimensions, exact_pairs, still_pairs = [], set(), [], []
    prev_hash, prev_thumb, samples = None, None, []
    deltas = []
    count = 0
    with av.open(str(path)) as container:
        if len(container.streams.video) != 1:
            raise ValueError("Expected exactly one video stream")
        stream = container.streams.video[0]
        stream.thread_type = "AUTO"
        header = {"codec":stream.codec_context.name, "rate":str(stream.average_rate),
                  "time_base":str(stream.time_base),
                  "duration_s":float(stream.duration*stream.time_base) if stream.duration is not None else None,
                  "reported_frames":stream.frames}
        for i, frame in enumerate(container.decode(stream)):
            if i >= FRAMES+1:
                raise ValueError("Video exceeds expected frame count")
            dimensions.add((frame.width,frame.height))
            actual = Fraction(frame.pts)*frame.time_base if frame.pts is not None else None
            if actual != Fraction(i,FPS):
                pts_errors.append({"frame":i, "got":str(actual), "expected":str(Fraction(i,FPS))})
            # Hash actual active luma bytes, excluding decoder alignment padding.
            gray = frame.reformat(format="gray").to_ndarray()
            digest = hashlib.sha256(gray.tobytes()).digest()
            thumb = frame.reformat(width=240,height=135,format="gray").to_ndarray()
            interior = i-1 >= 12 and i < 3582
            if prev_hash is not None:
                delta = float(np.abs(thumb.astype(np.int16)-prev_thumb.astype(np.int16)).mean())
                deltas.append(delta)
                if interior and digest == prev_hash:
                    exact_pairs.append(i)
                if interior and delta <= .02:
                    still_pairs.append(i)
            prev_hash, prev_thumb = digest, thumb
            if i in sample_rows:
                samples.append(picture_match(frame,sample_rows[i],titles,i))
            count += 1
    exact = runs(exact_pairs)
    near = [r for r in runs(still_pairs) if r["frames"] >= 12]
    checks = {"exact_frame_count":count == FRAMES, "all_pts_exact_n_over60":not pts_errors,
              "all_frames_1920x1080":dimensions == {(1920,1080)},
              "reported_rate_60":header["rate"] == "60",
              "video_duration60":header["duration_s"] is not None and abs(header["duration_s"]-60)<1e-8,
              "no_exact_interior_duplicates":not exact,
              "no_near_static_runs_12frames":not near,
              "sampled_pictures_match_sources":len(samples)==len(sample_rows) and all(s["passed"] for s in samples)}
    return {"header":header,"decoded_frames":count,"dimensions":sorted(dimensions),"checks":checks,
            "pts_errors":pts_errors, "exact_duplicate_runs":exact, "near_static_runs":near,
            "frame_delta_percentiles_255":{str(p):float(np.percentile(deltas,p)) for p in (0,1,5,50,95,100)},
            "picture_checks":samples,
            "freeze_scope":"Only global edge fades [0,0.2) and [59.7,60) excluded. Exact full-luma repeats fail; near-static thumbnail luma MAD <=0.02/255 over >=12 frames fails pending visual review. Not a general visual-quality assessment."}


def decode_audio(path):
    count, peak, nonfinite, clipped, valid_samples, energy = 0, 0., 0, 0, 0, 0.
    gaps, rates, channels, digest = [], set(), set(), hashlib.sha256()
    max_end, first_start = Fraction(0), None
    with av.open(str(path)) as container:
        if len(container.streams.audio) != 1:
            raise ValueError("Expected exactly one audio stream")
        stream = container.streams.audio[0]
        header = {"codec":stream.codec_context.name, "time_base":str(stream.time_base),
                  "duration_s":float(stream.duration*stream.time_base) if stream.duration is not None else None,
                  "sample_rate":stream.codec_context.sample_rate,
                  "channels":stream.codec_context.channels}
        for frame in container.decode(stream):
            rates.add(frame.sample_rate)
            channels.add(len(frame.layout.channels))
            stamp = Fraction(frame.pts)*frame.time_base if frame.pts is not None else None
            if first_start is None:
                first_start = stamp
            expected = Fraction(count,RATE)
            if stamp is None or abs(stamp-expected) > Fraction(1,RATE):
                gaps.append({"sample_index":count,"got":str(stamp),"expected":str(expected)})
            a = frame.to_ndarray()
            if not frame.format.is_planar:
                a = a.reshape(-1,len(frame.layout.channels)).T
            if np.issubdtype(a.dtype,np.integer):
                a = a.astype(np.float32)/(2**(a.dtype.itemsize*8-1))
            else:
                a = a.astype(np.float32,copy=False)
            if a.shape != (2,frame.samples):
                raise ValueError(f"Unexpected decoded audio shape {a.shape}")
            raw = np.ascontiguousarray(a.T)
            digest.update(raw.tobytes())
            nonfinite += int((~np.isfinite(raw)).sum())
            clipped += int((np.abs(raw)>=1).sum())
            peak = max(peak,float(np.max(np.abs(raw))))
            n = max(0,min(frame.samples,SAMPLES-count))
            energy += float(np.square(raw[:n],dtype=np.float64).sum())
            valid_samples += n
            count += frame.samples
            if stamp is not None:
                max_end = stamp+Fraction(frame.samples,frame.sample_rate)
            if count > SAMPLES+2*1024:
                raise ValueError("Audio is longer than valid AAC padding")
    decoded_duration = count/RATE
    checks = {"audio48k_stereo":rates=={RATE} and channels=={2},
              "audio_metadata_duration_in_range":header["duration_s"] is not None and 59.99<=header["duration_s"]<=60.03,
              "decoded_duration_in_range":59.99<=decoded_duration<=60.03,
              "aac_padding_within_one_frame":0<=count-SAMPLES<=1024,
              "starts_at_zero":first_start==0, "continuous_decoded_timestamps":not gaps,
              "no_nonfinite_audio":nonfinite==0,"no_audio_clipping":clipped==0}
    return {"header":header,"checks":checks,"decoded_sample_frames":count,
            "decoded_duration_s":decoded_duration,"audible_timeline_s":60,
            "aac_tail_padding_samples":max(count-SAMPLES,0), "padding_treatment":"Reported separately; valid 60s program used for RMS. Padding not silently counted as additional program duration.",
            "first_pts_s":float(first_start) if first_start is not None else None,"last_end_s":float(max_end),
            "sample_peak_dbfs":db(peak),"rms_dbfs_first60s":db(math.sqrt(energy/max(valid_samples*2,1))),
            "nonfinite_samples":nonfinite,"clipped_samples":clipped,"timestamp_gaps":gaps,
            "decoded_float32_interleaved_sha256":digest.hexdigest()}


def loudness(path,out,name):
    command = [imageio_ffmpeg.get_ffmpeg_exe(),"-hide_banner","-nostdin","-i",str(path),
               "-vn","-af","ebur128=peak=true","-f","null","-"]
    proc = subprocess.run(command,capture_output=True,text=True,timeout=120)
    (out/f"{name}_loudness.log").write_text(proc.stderr)
    tail = proc.stderr.rsplit("Summary:",1)[-1]
    result = {"command":command,"exit_code":proc.returncode}
    for key,pattern in [("integrated_lufs",r"I:\s+(-?[\d.]+) LUFS"),
                        ("loudness_range_lu",r"LRA:\s+(-?[\d.]+) LU"),
                        ("true_peak_dbfs",r"Peak:\s+(-?[\d.]+) dBFS")]:
        m = re.search(pattern,tail)
        result[key] = float(m[1]) if m else None
    result["passed"] = (proc.returncode==0 and result["true_peak_dbfs"] is not None
                        and result["true_peak_dbfs"] < 0)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master",type=Path,required=True)
    parser.add_argument("--edit-manifest",type=Path,required=True)
    parser.add_argument("--marked",type=Path)
    parser.add_argument("--out",type=Path,default=ROOT/"artifacts/tidebreak_trailer_60/verification")
    args = parser.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    (args.out/".gdignore").touch()
    report_path = args.out/"report.json"
    if report_path.exists():
        raise SystemExit("Refusing to overwrite evidence; choose a fresh --out directory")
    start = time.monotonic()
    report = {"schema":"tidebreak-trailer-independent-verification/v1",
              "verifier_sha256":sha(Path(__file__)),"pyav_version":av.__version__,
              "subjective_audio_listen":False,"clips":{},"errors":[]}
    try:
        schedule,manifest,sample_rows = check_frame_map(args.edit_manifest.resolve())
        report["frame_map"] = schedule
        for name,path in [("master",args.master),("marked",args.marked)]:
            if path is None:
                continue
            path = path.resolve()
            before = sha(path)
            print(f"Decoding {name}: {path}",flush=True)
            item = {"path":str(path),"sha256":before,"bytes":path.stat().st_size}
            item["video"] = decode_video(path,sample_rows,manifest["titles"])
            item["audio"] = decode_audio(path)
            item["loudness"] = loudness(path,args.out,name)
            item["input_unchanged"] = sha(path)==before
            item["passed"] = (all(item["video"]["checks"].values()) and all(item["audio"]["checks"].values())
                              and item["loudness"]["passed"] and item["input_unchanged"])
            if name == "master":
                item["matches_edit_manifest_hash"] = before==manifest.get("output_sha256")
                item["passed"] &= item["matches_edit_manifest_hash"]
            report["clips"][name] = item
        if args.marked:
            master = report["clips"]["master"]["audio"]
            marked = report["clips"]["marked"]["audio"]
            report["marked_audio_identical_to_master"] = (
                master["decoded_float32_interleaved_sha256"]==marked["decoded_float32_interleaved_sha256"]
                and master["decoded_sample_frames"]==marked["decoded_sample_frames"])
        report["passed"] = (schedule["passed"] and all(c["passed"] for c in report["clips"].values())
                            and report.get("marked_audio_identical_to_master",True))
    except Exception:
        report["errors"].append(traceback.format_exc())
        report["passed"] = False
    report["wall_s"] = round(time.monotonic()-start,3)
    report_path.write_text(json.dumps(report,indent=2)+"\n")
    lines = ["# Independent trailer verification", "", f"Result: **{'PASS' if report['passed'] else 'NOT MET'}**.", "",
             "Full frame/audio decoding; source schedule checked independently of builder code. Exact source-picture identity and subjective viewing/listening quality are not claimed.", ""]
    for name,item in report["clips"].items():
        lines.append(f"- {name}: {item['video']['decoded_frames']} frames; {item['audio']['decoded_sample_frames']} audio sample frames; "
                     f"{item['audio']['aac_tail_padding_samples']} samples AAC padding; {item['loudness']['integrated_lufs']} LUFS; "
                     f"{item['loudness']['true_peak_dbfs']} dBFS true peak; {'PASS' if item['passed'] else 'NOT MET'}.")
    lines.extend(["", "See `report.json` for every timestamp/format/freeze/picture/audio check, full source hashes and limitations. Loudness logs are retained alongside it.", ""])
    (args.out/"README.md").write_text("\n".join(lines))
    print(json.dumps({"passed":report["passed"],"wall_s":report["wall_s"],"report":str(report_path)},indent=2),flush=True)
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
