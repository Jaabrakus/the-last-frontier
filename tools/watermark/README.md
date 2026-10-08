# Invisible video restrictions and identifiers

This local prototype uses Meta's genuine [VideoSeal 1.0 TorchScript model](https://github.com/facebookresearch/videoseal/blob/main/docs/torchscript.md) to alter video pixels and its matching detector to recover an identifier **and explicit usage restrictions**. New TBW2 payloads default to denying copying, redistribution, AI training and use with AI, including inference, generation and reference use. The canonical instruction is: **“Do not copy, redistribute, train AI on, or use this content with AI.”** These restrictions are recovered from the pixels without reading metadata or fetching a registry record. Reading the restriction for verification is the intended exception.

The model and upstream software use the MIT license; the required notice is retained in `LICENSE.videoseal`. No paid watermark API is used. Processing still needs local compute.

The watermark is intended to be visually subtle. It does not prevent copying, compel an AI to obey, prove ownership, authenticate the issuer, establish registration, or supply C2PA credentials. Robustness is empirical, not guaranteed. Detection with another model is not promised. A negative result means this detector did not recover a valid payload, not that the media contains no watermark.

## Setup

Use Python3.11 and prebuilt dependencies in an isolated virtual environment:

```sh
python3 tools/watermark/bootstrap.py --python /opt/homebrew/bin/python3.11
export WATERMARK_PYTHON=/private/tmp/tidebreak-videoseal-runtime/bin/python
export VIDEOSEAL_MODEL=/private/tmp/tidebreak-videoseal-model/y_256b_img.jit
```

Change `--runtime` and `--model-dir` for durable deployment outside temporary storage. The installer fetches the official `https://dl.fbaipublicfiles.com/videoseal/y_256b_img.jit` and requires SHA256 `5c7a4581c36fc6090aafdcfb3999123bae5172a4847f22e2da4e7fd1a39d1e1b`. The engine checks that hash before loading TorchScript. PyAV and imageio-ffmpeg wheels provide the demuxer/encoder; a separate ffprobe executable is unnecessary. PyTorch, NumPy, PyAV, Pillow and imageio-ffmpeg versions are pinned in `requirements.txt`; their transitive dependencies are supplied by pip.

Automatic device selection uses CUDA when present, otherwise CPU. On the tested Mac, Torch2.6 MPS lacks the model's antialiased resize operation, so it is not selected automatically. CPU processing is slower than video playback. It does not slow the saved video.

## CLI

```sh
"$WATERMARK_PYTHON" tools/watermark/pixel_watermark.py probe --input input.mp4 --report probe.json
"$WATERMARK_PYTHON" tools/watermark/pixel_watermark.py embed \
  --input input.mp4 --output marked.mp4 --manifest marked.json \
  --asset-id 34c32632-111f-4fd5-8020-0c2ea7e476ff \
  --notice 'A caller-supplied notice'
"$WATERMARK_PYTHON" tools/watermark/pixel_watermark.py detect \
  --input marked.mp4 --report detected.json
```

Optional `--creator` records an explicitly supplied name. Detection accepts an optional `--asset-id` only for comparison **after** blind pixel extraction and checksum validation. It never consults container metadata or a notice registry. Embed defaults to `--policy-flags 15` (all four restrictions). An explicit subset can use bits1 copying,2 AI training,4 AI inference/generation/reference use,8 redistribution. An omitted flag does not grant permission. Detection's optional `--policy-flags` compares requested flags only after blind extraction. `--model`, `--device`, and embed `--crf` are advanced options. A source, existing output or existing report cannot be overwritten.

Exit0 means the operation completed; detection can still return `valid:false`. Exit1 means an input, preservation, model or execution failure. Inspect `valid`, `recovered_asset_id`, `payload_version`, `policy_state` and `policy`. When an expected ID was supplied, `matches_expected` compares identity; an identity mismatch does not cancel the recovered restrictions. A mere collection of bit logits is not accepted as a detection.

## Payload and records

The 256 TBW2 pixel bits contain four ASCII bytes `TBW2`, a16-byte UUID in network byte order, one byte of deny flags, three reserved zero bytes, a four-byte big-endian CRC32 of the first24 bytes, and the first4 bytes of SHA256 of the first28 bytes. Bits are serialized most significant first. Unknown flags or nonzero reserved bytes are rejected even when checksums match. CRC/digest detect corruption; anybody with the tool can create a valid payload, so these checks are **not signatures or authentication**. Restriction semantics are defined by the versioned payload format; it encodes the instruction through flags rather than storing its literal text bytes.

The detector also reads legacy TBW1: four-byte header,16-byte UUID, CRC32(first20 bytes), first8 SHA256 bytes of the first24 bytes. TBW1 contains no policy; it returns `policy:null` and `policy_state:"unknown"`, regardless of any denying text in metadata. Invalid/unmarked inputs also return unknown, never permission. TBW2 zero flags is unknown too. A TBW2 policy with any deny bit returns `policy_state:"deny"` and an object with `schema:"pixel-use-policy/v1"`, integer `flags`, booleans `deny_copying`, `deny_ai_training`, `deny_ai_inference`, `deny_redistribution`, and the decoded canonical `instruction`. A matching consumer can act on those fields. Embedding alone cannot compel unrelated systems to recognize or follow them.

The free-text notice and optional creator remain self-supplied claims stored in the manifest and removable MP4 `pixel_watermark` metadata. They do not authenticate the restrictions or establish legal ownership. A registry is unnecessary to recover TBW2 policy.

Current schemas are `pixel-watermark-probe/v1`, `pixel-watermark-detection/v2`, and `pixel-watermark-manifest/v2`. Earlier v1 reports remain valid historical records of TBW1 exports. The manifest records source/output SHA256, model URL/hash, exact UUID/notice, **actually recovered** policy, actual decoded frame/timing facts, compressed and decoded audio hashes, metadata changes, detection results, and sampled RGB quality. Quality measurements include H264 re-encoding loss. Manifests include local source/output paths; a service should sanitize these before publishing records.

## Supported input and preservation

The prototype accepts local, self-contained MP4/MOV with an `ftyp` signature, or WebM/Matroska, containing one video and at most one audio stream. Embedding supports zero-start constant-frame-rate, 8-bit SDR, unrotated video. HDR/PQ/HLG, higher bit depths, rotation, variable frame rate, extra streams and media with unsupported audio codecs are rejected rather than silently normalized. MP4-compatible audio is stream-copied. H264 video is re-encoded at CRF18 by default; resolution, actual frame count and every presentation timestamp are checked, along with audio compressed payload, packet PTS and decoded float sample hashes. Existing descriptive container metadata must survive; encoder/container-brand changes are logged. Track-level technical metadata can be normalized by the new encoder.

Limits:60seconds,120fps,3840×2160 pixels and eight billion pixel-frames. Limits apply to actual decoded frames as well as declarations. Audio is limited to192kHz/eight channels,60seconds plus normal codec padding,100000 compressed packets and256MiB of compressed payload, with actual sample counts and continuity checked. Only local file/pipe protocols are enabled; MOV external data references and absolute paths are disabled. These bounds reduce accidental excess work; a production public service still needs process/container isolation, quotas and sandboxed media parsing. Detection uniformly samples at most64 frames and aggregates model logits. No promise is made about short crops, severe compression, overlays or transformations outside recorded tests.

The tool publishes a new MP4 only after exact UUID **and restriction-bit recovery**, plus playback checks, pass. The original remains unchanged. This is a research-backed local prototype, not a legal enforcement or tamper-proof identity system.
