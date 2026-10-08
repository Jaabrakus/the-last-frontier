# Gameplay reuse notice and Reddit draft

Prepared October 7, 2026. The public draft and video notices use **Tidebreak** as a working name. The intended final game title is **Crowns of the Monsoon: Warring Heavens**; that title is not embedded in these video notices.

Follow-up: the user subsequently authorized an actual pixel watermark and a local service prototype. Those are implemented separately in `tools/watermark/` and `services/watermark/`, with new `*_pixel.mp4` derivatives. See `docs/tidebreak/watermark_service_design.md` and `artifacts/tidebreak_pixel_watermark/` for their validation. The metadata-only originals and records documented below remain intact.

Current follow-up: [TBW2 pixel restrictions](pixel_policy_verification.md) now encode explicit copying, redistribution, AI training and AI-use denials in the pixels themselves. The new `*_pixel_policy.mp4` exports and compatible service/gate behavior are documented there; this page preserves the earlier metadata-only work.

## Draft

The copy-ready post is in `artifacts/tidebreak_reddit_post.md`. It uses ordinary fighting-game slang. No wording is represented as defeating AI analysis. The post has not been published.

## Notice

The exact caller-supplied notice is:

> Tidebreak — working-title gameplay footage. No permission is granted by this file for copying, redistribution, or AI training. Contact the creator for permission.

No creator or studio identity was supplied, so the creator field is omitted. The notice makes no claim of trademark registration or independently verified ownership of every bundled asset. Existing animation provenance records remain authoritative for their documented observations and the owner's account.

`tools/showcase/video_rights.swift` adds the notice to a new MP4 copy using AVFoundation passthrough. The standard ISO MP4 description field contains JSON with the exact notice, a UUID asset identifier, and the original file's SHA-256. The original remains unchanged. Existing AVFoundation-readable metadata must survive validation before the new output is published.

This is removable, human-readable and machine-readable container metadata. It is not an invisible pixel watermark, an AI-only message, access control, a digital signature, or a C2PA credential. It does not prevent copying or guarantee exclusion from AI training. Uploading, remuxing, or re-encoding can remove it. A trademark identifies a brand; registration and copying rights are separate questions. See the [USPTO trademark overview](https://www.uspto.gov/trademarks/basics/what-trademark).

## Invisible watermark feasibility

An imperceptible pattern inside the video pixels is technically possible, with a matching detector to recover an identifier or message. [Google SynthID](https://deepmind.google/models/synthid/) demonstrates this approach for identifying AI-generated media. It does not establish that an arbitrary AI viewing our gameplay can recognize a custom pattern. People using the same detector can read the information too.

[Meta's VideoSeal](https://github.com/facebookresearch/videoseal) is an available implementation for embedding and detecting hidden messages in video pixels. At the metadata-only stage it was a candidate and had not been installed or applied. The subsequent implementation and footage tests are recorded in the follow-up above. A recovered identifier can link to a reuse notice; that does not by itself make another service enforce the notice.

Detection and compliance are separate steps. [Adobe documents a generative AI training and usage preference](https://helpx.adobe.com/uk/creative-cloud/apps/adobe-content-authenticity/generative-ai-training-preferences.html) carried in Content Credentials and honored by supporting services. That is a concrete example of a machine-readable restriction influencing a cooperating service. It does not impose that behavior on other systems. No such credential or pixel watermark is applied by this metadata-only tool, and no external upload or identity verification has been performed.

## Outputs

- `artifacts/tidebreak_gameplay_trailer_rights.mp4`: a metadata-only derivative of the existing 33.75-second, 1080p60 trailer. It retains the older trailer's captured lighting and gameplay tuning.
- `artifacts/tidebreak_lighting_preview_rights.mp4`: a metadata-only derivative of the existing 8-second, 720p60 preview, which shows the newer lighting and installed balance tuning.

Both remain at normal speed. These exports do not create a new gameplay recording or change the footage.

Validation reports and independent read-backs are saved in `artifacts/tidebreak_rights/`. The trailer retains 2,025 video frames and 1,620,000 decoded audio sample frames over 33.75 seconds; the preview retains 480 video frames and 384,000 decoded audio sample frames over 8 seconds. Encoded audio/video payloads, decoded float32 audio, and video display timestamps match their respective originals. Both original file hashes remain unchanged. Refusal checks for overwriting an existing file and using the same input/output passed. Root independently checked the exported file hashes against the reports and confirmed metadata and decoded playback results matched the read-backs.

## Reproduce and inspect

```sh
swiftc -O tools/showcase/video_rights.swift -o /private/tmp/video_rights
/private/tmp/video_rights input.mp4 output.mp4 --notice 'Your exact reuse notice'
/private/tmp/video_rights inspect output.mp4
```

The tool refuses to overwrite an existing output. Its successful export report includes source and output file hashes, read-back metadata, stream properties, encoded audio/video payload hashes, sample counts, and timing hashes. It requires matching compressed audio/video payloads, decoded video presentation timestamps, decoded float32 PCM audio, durations, preserved existing metadata, and an unchanged source file before publishing the copy. These checks validate a metadata-only export; they do not verify legal ownership or watermark robustness.

AVFoundation can regroup compressed AAC read buffers and change how the last packet's padding duration is reported during passthrough. Buffer-level timing hashes are therefore retained as diagnostic records, while matching decoded playback and stream payloads determine acceptance. Float32 PCM is used because repeated decoding of the same original into 16-bit integer PCM produced differing quantization/dither results.
