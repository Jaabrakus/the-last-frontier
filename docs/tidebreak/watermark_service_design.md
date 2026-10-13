# Pixel watermark service: scope and verification

This document preserves the initial **TBW1 UUID-only** design and verification. The current TBW2 payload additionally carries explicit restrictions; see [current pixel-policy verification](pixel_policy_verification.md). The old exports and test evidence remain intact.

The initial 2026-10-07 prototype marked short videos and recovered their identifiers. It had no public deployment, account system, permanent registry, issuer signature, or ownership verification. The pixel marker can help identify a copy; it cannot prevent someone from copying viewable footage, extracting delivered game assets, removing a marker, or embedding somebody else's identifier.

## What the prototype implements

The [engine](../../tools/watermark/pixel_watermark.py) embeds a 256-bit payload in video pixels: `TBW1` (32 bits), a UUID (128), CRC32 (32), and the first 64 bits of a SHA-256 checksum. Detection validates that structure before returning a recovered UUID. Supplying an expected UUID only adds a comparison; it does not make an invalid extraction valid. These public checksums detect encoding corruption, **not issuer authenticity**.

The notice and optional creator name are self-supplied statements in container metadata and a downloadable JSON manifest. They are not text hidden verbatim in the pixel payload. The manifest records the UUID, source/output SHA-256 digests, model digest, media checks, and detection results. A digest identifies exact bytes; a reencoded copy has a different digest even when its pixel UUID survives. Existing source files and provenance records are not rewritten.

The [service](../../services/watermark/server.py) runs on loopback only. It accepts multipart video uploads, returns an unpredictable job capability, and exposes only that job's completed artifacts. It has one processing worker, bounded queue/upload/HTTP concurrency, byte and media-work limits, process-group timeouts, generated storage names, Host/Origin checks, and no cross-origin API access. Uploads are spooled to private temporary directories; sources are removed after processing, and retained jobs expire after 24 hours. A capability grants access to a job; it is not an identity credential.

**Save the manifest with the marked video.** Job expiry removes the service's temporary linkage. A UUID may remain recoverable from the pixels after expiry, but this prototype does not provide a permanent public lookup of its notice or creator. The UUID itself is not a secret or an access token.

Supported media is deliberately narrow: self-contained MP4/modern MOV or WebM/Matroska, one video stream and at most one audio stream, known duration up to 60 seconds, bounded resolution/frame rate/decoded pixel work, and 8-bit SDR without rotation. Embedding checks zero-start constant frame timing, frame count and audio preservation. Unsupported media should fail clearly rather than be silently normalized.

## Upstream model and licensing

Meta's current stable VideoSeal v1.0 has a 256-bit message, and the upstream project states that its models and software use MIT. This implementation pins the official `y_256b_img.jit` file by SHA-256 (`5c7a4581c36fc6090aafdcfb3999123bae5172a4847f22e2da4e7fd1a39d1e1b`) and retains [the upstream notice](../../tools/watermark/LICENSE.videoseal). MIT permits commercial reuse with its notice; it does not supply hosting, compute, or rights to uploaded media. Dependency and bundled codec notices still need their own distribution review. [Official repository](https://github.com/facebookresearch/videoseal), [model card](https://github.com/facebookresearch/videoseal/blob/main/videoseal/cards/videoseal_1.0.yaml), [license](https://github.com/facebookresearch/videoseal/blob/main/LICENSE).

The upstream examples are inference examples, not a hardened upload service. Their deployment guide supports CPU or CUDA execution and discusses chunk-size memory tradeoffs. The prototype uses a pinned local model and runtime rather than downloading a model for each upload. Robustness remains a measured property of particular transformations, not a promise to survive every edit. [Official TorchScript guide](https://github.com/facebookresearch/videoseal/blob/main/docs/torchscript.md), [Meta research description](https://ai.meta.com/research/publications/video-seal-open-and-efficient-video-watermarking/).

## Verification and review

Independent HTTP boundary tests passed **30 checks**, including foreign Host/Origin rejection, traversal/token paths, oversize and chunked requests, duplicate/unknown fields, playlist signatures, malformed UUIDs, admission limits, abandoned-upload cleanup, ignored client filenames, and unavailable queued artifacts. A real continuously trickling socket also hit the absolute upload deadline; that test accelerated the server's monotonic clock 600× rather than waiting two minutes. These tests used a real loopback HTTP server with its inference worker disabled and readiness stubbed; they do not validate the model. [Runner and report](../../artifacts/tidebreak_watermark_service/review/).

The actual browser integration separately passed **16 checks with the real engine**, including a two-second 720p upload, pixel embedding, playable output, downloaded manifest, blind re-upload verification, server-path sanitization, deletion, keyboard/mobile layout, and no JavaScript errors. [Browser report](../../artifacts/tidebreak_watermark_service/browser_report.json).

Independent whole-clip pixel checks passed **8 controls: four for each export**. [Exact commands, hashes and reports](../../artifacts/tidebreak_pixel_watermark/validation/independent_export_validation.json).

| Control | Lighting, 8 seconds | Gameplay, 33.75 seconds |
| --- | --- | --- |
| Original footage returns no valid supported marker | Pass | Pass |
| Marked footage yields exact UUID with no expected ID supplied | Pass | Pass |
| Deliberately wrong expected ID reports a mismatch | Pass | Pass |
| Full clip reencoded at 720p, H.264 CRF28, source metadata removed; blind UUID recovery | Pass | Pass |

Reencode probes confirm that neither UUID nor `pixel_watermark` tag remains in metadata. Both transformed clips retain 60 fps. The marked deliverables retain their source frame counts (480 and 2,025), exact 60 fps presentation timestamps, audio compressed payloads/packet timing and decoded PCM; the supplementary audio checks also confirm continuity. [Playback evidence](../../artifacts/tidebreak_pixel_watermark/audio_continuity_checks.json). Twelve-frame quality samples average 37.42 dB and 37.95 dB PSNR against the respective sources; those numbers include H.264 reencoding loss and are not a substitute for visual review. [Export evidence](../../artifacts/tidebreak_pixel_watermark/README.md).

These controls do not calibrate a population false-positive rate or demonstrate resistance to arbitrary cropping, edits, overlays, frame interpolation, screen recording, attacks, or repeated recompression. Those remain future robustness tests. Native adversarial-media fuzzing and production load tests are also outstanding. File signatures alone are insufficient: the implemented decoder restrictions also constrain formats, protocols and external references. [FFmpeg formats](https://ffmpeg.org/ffmpeg-formats.html#Format-Options), [FFmpeg protocols](https://ffmpeg.org/ffmpeg-protocols.html#Protocol-Options).

Review prompted decoded-frame/pixel and audio-work limits independent of container declarations, fixed native demuxers with external references disabled, HTTP connection bounds, an absolute upload deadline, server-path sanitization, failed-job partial-file cleanup, and safe handling of expired queued jobs. Neither a valid payload nor a negative result establishes who owns footage or whether other watermarks exist.

## A free public tier and future assets

Free to users still consumes compute, temporary storage, bandwidth, and operational support. The local CPU exports took 32.0 seconds for the eight-second 720p clip and 146.5 seconds for the 33.75-second 1080p clip, including verification; these two observations are not a capacity benchmark. Before any public launch, benchmark latency and peak memory on the intended hardware, then size duration/resolution quotas, concurrency, daily usage, output retention and a global spend limit. Put patched media decoders in an isolated worker with restricted filesystem access and egress; add HTTPS, abuse controls, privacy/retention policy, monitored cleanup and queue recovery. The local server is not approved for direct Internet exposure. No public deployment has been performed.

For game data and apps, a future manifest can give each asset a stable UUID and record each version's content digest, type, issuer, issued time, supplied rights statement, and retained source/derivation references. Different file bytes require a new digest; preserve the relationship to earlier versions. Suitable formats could carry a marker or signed manifest, but not every binary supports an imperceptible robust watermark. Access control and package signatures address delivery and integrity separately; a client that can use an asset can often extract it.

Optional signing can attest that a particular issuer made a statement about a particular digest. It does not by itself establish legal ownership, independently verify the creator, or make an inaccurate statement true. A durable opt-in registry could later resolve pixel UUIDs to records, with identity verification and dispute handling as separate processes. C2PA offers a standardized future path for signed assertions, cryptographic content bindings and watermark-based manifest discovery; this prototype is not C2PA-compliant. Ordinary signed records and optional trusted timestamps are sufficient design options; blockchain is not required. [C2PA 2.4 technical specification](https://spec.c2pa.org/specifications/specifications/2.4/specs/C2PA_Specification.html).
