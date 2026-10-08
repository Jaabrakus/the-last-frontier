# Tidebreak Mark

A free local video watermark prototype. It embeds four hidden instructions in the actual pixels: **do not copy, redistribute, train AI on, or use this content with AI**. It also embeds an asset ID, produces an MP4 and a manifest, and reads the instructions back from the finished video before making it available. A compatible app can recover the instructions and refuse a restricted action. Other AI systems do not automatically recognize or obey this protocol; the watermark cannot force compliance or prevent copying.

The fixed instructions are independent of the editable notice and creator name, which remain self-supplied metadata/manifest claims. No ownership or issuer identity is verified. An older ID-only mark, absent mark, unreadable mark or unspecified restriction means **permission unknown**, never permission granted.

## Run

On this configured workstation, double-click **Open Video Mark.command**, or:

```sh
./services/watermark/run.sh
```

Open http://127.0.0.1:8765. The launcher finds the configured engine runtime; the server binds only to localhost. `Ctrl+C` stops it. There are no accounts, payments, external uploads, or public deployment steps.

For a fresh checkout, install Python 3.11 first, then run the explicit bootstrap once. It downloads the pinned, official MIT-licensed VideoSeal model and Python dependencies; normal processing stays local.

```sh
./services/watermark/bootstrap.sh
./services/watermark/run.sh
```

Use `WATERMARK_SETUP_PYTHON=/path/to/python3.11` for setup if needed. Bootstrap stores the isolated runtime and model in ignored `.runtime/` and `.model/` directories. See [engine documentation](../../tools/watermark/README.md) and its retained upstream license for the pinned model hash, dependencies, supported transformations, and limitations.

Explicit runtime configuration is also supported:

```sh
WATERMARK_PYTHON=/path/to/runtime/bin/python \
VIDEOSEAL_MODEL=/path/to/y_256b_img.jit \
./services/watermark/run.sh --port 8765
```

`WATERMARK_ENGINE` can point to a compatible engine script. `--storage /private/tmp/my-video-mark` changes the local job directory. Do not share one storage directory between simultaneously running servers. The default is the OS temporary directory under `tidebreak-mark-<uid>`.

## Using it

1. Choose **Mark a video** and upload a video. The four restrictions are embedded automatically; no extra switches are needed. You can edit the additional notice and optionally add a creator/studio name.
2. Wait for the local processor. It first reads any existing pixel instructions. **If those instructions deny copying or AI use, this app refuses to re-mark the video and creates no output.** The policy check is narrow inspection; the subsequent embedding would use neural inference. Original or legacy-unknown inputs may proceed with your requested marking; this does not establish ownership or grant rights. A single worker processes the queue; CPU processing can take longer than the clip's playback time.
3. Review the recovered restrictions, then preview and download the MP4. **Save the manifest too:** the pixel payload carries the instructions and UUID; the manifest adds your notice, creator, hashes and processing facts. No permanent notice lookup registry exists.
4. Use **Check a video** to recover supported restrictions and an identifier directly from its pixels. Optionally paste a UUID from a manifest to compare it. A different UUID does not cancel a recovered restriction. A negative result means this detector did not recover a supported payload; it grants no permission.

Uploads are modern self-contained MP4/MOV (`ftyp`) or WebM/Matroska, at most 100 MiB and 60 seconds. The engine supports one constant-frame-rate, zero-start, unrotated 8-bit SDR video stream and optional supported audio; HDR, VFR, rotation and incompatible audio can be rejected. The service caps dimensions, 120 fps, 3,600 declared frames and eight billion pixel-frames. The engine also bounds actual decode work. Output is H264 MP4; the engine verifies playback facts and exact UUID recovery before publication. Sources are removed after processing, including failures. Job files expire after 24 hours while the service runs or on the next startup; the UI can remove finished jobs immediately.

The UI works with a keyboard, narrow screens, and screen readers. Progress reports upload bytes and real processing phases; it does not fabricate an inference percentage.

## API

All browser requests must come from the server's own origin. No cookies or CORS are used. An unpredictable job token is the capability to read its result: keep job URLs private. The token is omitted from access logs and downloadable manifests.

| Request | Body/result |
|---|---|
| `GET /api/health` | Cached runtime/model readiness and supported limits |
| `POST /api/jobs` | Multipart: `video`, required `notice`, optional `creator`; returns `202` job |
| `POST /api/verify` | Multipart: `video`, optional UUID `asset_id`; returns `202` job |
| `GET /api/jobs/<token>` | `uploading → queued → probing → processing → complete/error/denied`; completed outputs include download URLs |
| `GET /api/jobs/<token>/video` | Completed MP4; single HTTP byte ranges supported for preview |
| `GET /api/jobs/<token>/manifest` | Portable JSON attribution manifest |
| `GET /api/jobs/<token>/report` | JSON detection report; `permission` gives the action decision; `valid` and `matches_expected` describe extraction and ID comparison separately |
| `DELETE /api/jobs/<token>` | Remove completed, failed or denied local job records/files |

The job schema is `tidebreak-mark.job.v1`; manifests include `service.schema=tidebreak-mark.asset.v1` and `asset_type=video`. This leaves room for future apps/game assets, but **only video is implemented**. There is no ownership registry or issuer signature.

### Reading a permission decision

A completed check exposes `job.result.permission` and the same object in its downloadable report. New embed manifests also contain it, derived from `manifest.detection` of the actual output pixels. The service never interprets notice keywords as policy. A current mark with all four instructions returns:

```json
{
  "schema": "tidebreak-permission/v1",
  "decision": "deny",
  "restrictions": ["copying", "redistribution", "ai_training", "ai_use"],
  "instruction": "Do not copy, redistribute, train AI on, or use this content with AI.",
  "source": "pixel_payload"
}
```

`ai_use` corresponds to the pixel protocol's `deny_ai_inference` flag and means using the content with AI, separately from training. The raw reader fields (`payload_version`, `policy_state`, `policy`) remain available. A valid older `TBW1` mark can supply an ID while its permission decision is `unknown`. Unmarked, invalid and zero-policy payloads also yield `unknown`; the API has no `allow` decision. A partial external TBW2 policy lists only the recovered denials. The UI's new marks always embed all four.

If preflight refuses an embed, the terminal job state is `denied`, its human-readable `message` explains why, and `result` contains `permission`, the raw `detection`, and `denied_action="re_watermark"`. No `downloads` are returned. The source and processor files are removed; only the expiring job status remains. Checking the same file through `/api/verify` is still available as policy inspection. The shared interpreter is [tools/watermark/policy.py](../../tools/watermark/policy.py).

### Connect it before an AI action

An integration must submit the actual candidate video to `POST /api/verify`, poll its returned job URL until `complete`, and apply the result **before** sending the video to a model. Do not trust a user-uploaded JSON report, notice or manifest instead of running the detector. This conservative example blocks any recovered denial and pauses unknown cases for independently established permission:

```python
def require_ai_permission(completed_job):
    if completed_job.get("state") != "complete":
        raise PermissionError("Video check has not completed; do not send to AI.")
    permission = completed_job.get("result", {}).get("permission", {})
    if permission.get("decision") == "deny":
        raise PermissionError("Embedded instructions deny use; do not send to AI.")
    # Unknown includes old marks, missing/damaged marks and unspecified policy.
    raise PermissionError("Permission is unknown; obtain separate permission first.")

require_ai_permission(job_from_this_local_service)
# A downstream AI call belongs after the gate. This API never grants permission.
```

This is a refusal signal for cooperating consumers. It is not a prompt hidden for arbitrary language models to read, a universal training opt-out, a copyright determination or a replacement for the consumer's permission process.

The stdlib server limits simultaneous HTTP connections and uploads, spools bounded bodies to disk, requires Content-Length, rejects cross-origin/Host spoofing, ignores uploaded filenames, and never interpolates paths/text into shell commands. Native engine work has a 30-second probe deadline and a 30-minute processing deadline with process-group termination. It is a localhost prototype; it is not a production public upload service.

## Tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s services/watermark/tests -v
```

Core tests use a clearly labeled fake engine for queue ordering, processing states, report sanitization, work limits, source/partial cleanup, restart recovery and expiry. They also cover current-deny versus legacy/invalid/unknown policy, expected-ID mismatch, partial restrictions, inconsistent flag rejection, refusal before re-marking restricted input, and refusal to publish an output whose restrictions were not recovered. They do not establish pixel watermark efficacy. Real engine/browser end-to-end and independent HTTP boundary evidence is recorded separately under `artifacts/tidebreak_watermark_service/`.
