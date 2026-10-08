# Pixel-carried restrictions: TBW2 verification

The current exports carry four explicit restrictions in their video pixels, together with the asset UUID. A compatible reader recovers the instruction:

> Do not copy, redistribute, train AI on, or use this content with AI.

Both complete exports passed independent recovery after source metadata removal and a 720p H.264 CRF28 reencode. The instruction is reconstructed from versioned policy bits; it is not inferred from a creator name, UUID, expected answer, or metadata notice. The editable notice remains separate metadata/manifest text.

## Current deliverables

| Export | UUID | Playback |
| --- | --- | --- |
| [Lighting preview](../../artifacts/tidebreak_lighting_preview_pixel_policy.mp4) | `34c32632-111f-4fd5-8020-0c2ea7e476ff` | 8 seconds, 1280×720, 480 frames, 60 fps |
| [Gameplay trailer](../../artifacts/tidebreak_gameplay_trailer_pixel_policy.mp4) | `1d983974-425b-47e2-ae24-f156b118afef` | 33.75 seconds, 1920×1080, 2,025 frames, 60 fps |

The payload is 256 bits: `TBW2`, UUID, one flag byte, three reserved zero bytes, CRC32, and a truncated SHA-256 check. Flags `1`, `2`, `4`, and `8` respectively deny copying, AI training, AI inference/use, and redistribution. New service outputs encode all four (`15`) and must recover them before publication. Checksums validate encoding, not issuer identity or ownership. [Engine](../../tools/watermark/pixel_watermark.py), [shared policy mapping](../../tools/watermark/policy.py).

## Independent results

**Ten full-clip controls passed**, five per export. All blind reads omitted both expected UUID and expected policy flags. The frozen detector source SHA-256 was `b53b76b95b9f2878dc4fcf38c120dc6c47b179294c4a5aa3adf500999744930b` throughout these runs.

| Control | Lighting | Gameplay |
| --- | --- | --- |
| Original unmarked footage → no recovered UUID, policy unknown | Pass | Pass |
| Preserved TBW1 export → correct UUID, policy unknown | Pass | Pass |
| New TBW2 export → correct UUID, flags `15`, all four denials and exact instruction | Pass | Pass |
| Wrong expected UUID → mismatch, while recovered denials remain intact | Pass | Pass |
| Whole clip at 720p CRF28, source metadata stripped → blind exact UUID and denials | Pass | Pass |

The legacy videos already contain denying metadata notices; they still return unknown pixel policy. This controls against promoting notice text into a decoded restriction. Transformed-file probes contain no UUID, `pixel_watermark` notice, denial fields, or canonical instruction. Container/encoder housekeeping tags do not carry the policy. The trailer was downscaled from 1080p; the preview was reencoded at its existing 720p size.

An additional standard-library parser checked all ten actual extracted bit vectors without importing the engine: UUID, flag byte, reserved bytes and corruption checks agreed. The service's policy functions were then applied to the ten real detection reports and two final embed manifests: **12/12 mappings passed**. Current denials remained denials; legacy/unmarked results remained unknown; ID mismatch did not clear a restriction.

- [Exact commands, input/source hashes, ten controls](../../artifacts/tidebreak_pixel_policy/validation/independent_policy_validation.json)
- [Independent extracted-byte checks](../../artifacts/tidebreak_pixel_policy/validation/independent_payload_bytes.json)
- [Service mapping checks and source hashes](../../artifacts/tidebreak_pixel_policy/validation/service_policy_validation.json)
- [Reproduction scripts, reports, logs and transformed inputs](../../artifacts/tidebreak_pixel_policy/validation/)
- [Export playback/audio/quality evidence](../../artifacts/tidebreak_pixel_policy/README.md)

The final real-browser flow passed **24 checks** with the actual VideoSeal engine. Its editable notice contained only “Contact the creator for permission.” The service still recovered all four restrictions, played the two-second result at normal speed, recovered restrictions after metadata removal, refused re-marking with no downloads/API video, deleted temporary jobs, and read the legacy UUID with unknown policy. Mobile cards fit and no JavaScript errors occurred. [Browser evidence](../../artifacts/tidebreak_pixel_policy/browser/report.json), [final source/output hashes and verification index](../../artifacts/tidebreak_pixel_policy/final_review.json).

The export checks retain source frame counts, exact presentation timestamps and audio. Average twelve-frame PSNR was 37.38 dB for lighting and 38.03 dB for gameplay, including H.264 reencoding loss. These measurements do not substitute for perceptual review or establish robustness on other footage and transformations.

## How a cooperating app acts

The [AI-use gate](../../tools/watermark/ai_use_gate.py) decodes the actual candidate video and evaluates the requested action before a downstream operation. Its CLI returns explicit denial or permission unknown; it cannot supply a positive license. A separate caller permission system is required for unknown cases. Expected-ID mismatch, absent marks, legacy marks and zero-policy payloads never become automatic permission. The detector itself performs a narrow model pass to read the policy; the gate controls the subsequent requested use.

The [local service](../../services/watermark/README.md) also checks incoming footage before marking it. A recovered copying or AI-use denial produces a terminal `denied` result, no new video/download, and removal of the uploaded source and partial files. Verification remains available so restrictions can be read. Requests to mark previously unmarked footage do not establish ownership or permission for unrelated uses.

Independent gate execution passed **two real CLI controls**: the metadata-stripped TBW2 preview returned exit `2`/deny, and the preserved TBW1 browser clip returned exit `3`/unknown. Two additional actual pixel detections fed **nine library callback checks**. All four denied actions blocked the callback even with `independently_authorized=True`; unknown policy blocked absent/non-boolean authorization and reached the callback only with explicit separate authorization. No downstream AI call was made; the test callback records whether the protected code was reached. [Gate commands, hashes, reports and callback evidence](../../artifacts/tidebreak_pixel_policy/gate/gate_verification.json).

### Gate integration

Run the CLI with the persistent local runtime before a downstream operation:

```sh
services/watermark/.runtime/bin/python tools/watermark/ai_use_gate.py \
  --input video.mp4 --use ai_use --report new-gate-report.json
```

Exit `2` means the requested action is explicitly denied; `3` means permission is unknown; `1` means the reader failed. All three stop an automatic downstream action. The CLI does not return an affirmative permission result. Supported actions are `ai_use`, `ai_training`, `copying`, and `redistribution`.

Library callers can use their separate permission system for unknown cases. Put `tools/watermark` on the Python import path, supply the usual detector model/device arguments, and keep the checked video bytes private and immutable until consumed:

```python
from pixel_watermark import detect
from ai_use_gate import require_action_permission

detection = detect(immutable_video_path, detector_args)
require_action_permission(
    detection, "ai_use",
    independently_authorized=separate_permission_system_authorized,
)
downstream_ai_callback(immutable_video_path)  # reached only after the gate returns
```

Use a fresh result from this trusted detector, not an uploaded JSON report. The separate authorization argument must be the boolean `True`; a name, metadata notice, missing mark, truthy string or integer is insufficient. Explicit recovered denial still raises `UseDenied` when that argument is true. Unknown policy raises `PermissionUnknown` unless separate authorization is supplied. This authorization branch does not verify ownership; the calling application's permission system is responsible for it.

This supplies a concrete refusal signal and a cooperating implementation. Other AI systems must integrate a compatible reader and honor the result; an imperceptible marker cannot force every AI to recognize it, block all copying, or prove ownership. The two-clip tests cover this particular reencode, not arbitrary cropping, editing, screen recording or deliberate removal. There is no public deployment or permanent lookup registry.

The earlier UUID-only [TBW1 evidence](../../artifacts/tidebreak_pixel_watermark/README.md) and [initial service design review](watermark_service_design.md) remain preserved as history. They do not describe the current payload's policy capabilities.
