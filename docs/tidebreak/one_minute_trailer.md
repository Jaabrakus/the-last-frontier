# Tidebreak — one-minute gameplay trailer

The edit is exactly **60 seconds, 1920×1080 at 60 FPS**, with five title overlays, a procedural instrumental score, and synchronized game sound. It shows the local arena demo build preserved in the capture source snapshots, with automated normal player controls. No damage, cooldowns, combat outcomes, or playback speeds were changed for the trailer.

The owner subsequently confirmed **Planetes, the space anime**, as the palette reference. The arena palette pass and its new gameplay preview are documented in `docs/tidebreak/planetes_palette.md`; this completed one-minute trailer predates that pass.

## Deliverables

- Clean master: `artifacts/tidebreak_60s_trailer_master.mp4`
- Pixel-marked delivery: `artifacts/tidebreak_60s_trailer.mp4`
- Edit, source records, audio stems, titles and verification: `artifacts/tidebreak_trailer_60/`

The opening reads **TIDEBREAK / ELEMENTAL ARENA COMBAT**. The ending reads **TIDEBREAK / EARLY PLAYABLE DEMO / IN DEVELOPMENT**. The intermediate titles are **FOUR ELEMENTS.**, **ONE ARENA.**, and **MAKE WAVES.** There is no claim of a public release or download.

## Selected gameplay

| Trailer time | Element | Captured source interval |
| --- | --- | --- |
| 0–12 s | Water | Main take, 0–12 s |
| 12–24 s | Earth | Main take, 0–12 s |
| 24–39 s | Air | Camera-aim take, 38–53 s |
| 39–54 s | Fire | Main take, 0.783333–15.783333 s |
| 54–60 s | Earth | Main take, 14–20 s |

Fire's earned knockout lands at **52 seconds**, with the music accent aligned to it. Air shows close, readable gust exchanges; this selected excerpt does not contain an Air knockout. The original source events are retained. Every output frame maps to a distinct source frame, with continuous source time within each cut. Titles overlay moving gameplay, including the end card.

Only the two corner fighter panels are hidden. The clock, events, lower controls, aiming dot and combat feedback remain. The title cards shade the footage for contrast.

## Camera and aim

Matched old/new Water frames show the same framing. The recorder copies the live player's camera without an added zoom. A narrow portrait viewport can show less horizontal world than the widescreen trailer; spring-arm collision and recovery also affect framing.

The crosshair is used for aiming. The focused game regression passed **15/15 checks**, including actual hits at 15 m with aim assist off in all four camera variants. A body-origin aiming estimate in the rejected Air recording could place the crosshair too high; the delivered Air excerpt was recorded again using camera-origin aiming. No game FOV or reticle offset was changed.

See `artifacts/tidebreak_trailer_60/camera_checks/` for the test, preserved comparison frames and detailed findings.

## Validation and reproduction

The independent master check passed: 3,600 decoded frames at exact n/60 presentation times, all five source cuts verified, 15 title-aware image comparisons passed, and no unexpected repeated-frame freezes. Stereo audio is 48 kHz, with zero clipped samples, −18.7 LUFS integrated loudness and −2.3 dBFS true peak. The 512 decoded AAC padding samples are accounted for separately from the 60-second track duration.

`artifacts/tidebreak_trailer_60/edit.json` defines the edit. `edit/manifest.json`, `edit/frame_map.csv`, capture logs, source snapshots and audio alignment records preserve the evidence. Raw capture frames remain in the recorded `/private/tmp/tidebreak-trailer-60-*` take directories. The stored `edit/mix.wav` and `edit/game_sfx.wav` allow later audio revisions.

Build with `tools/ring/build_tidebreak_trailer.py` using the local `services/watermark/.runtime/bin/python` runtime. Use a new output directory and MP4 path; the builder refuses to overwrite an existing result. `tools/ring/verify_tidebreak_trailer.py` independently verifies the master and optional marked export. Exact capture and encode commands are stored with the artifacts.

The pixel watermark carries a TBW2 asset identifier and restriction flags. The readable notice is preserved in metadata and the manifest. A compatible detector can recover the pixel policy; this is not a guarantee that other AI systems recognize or obey it, nor a trademark registration or proof of ownership. Export-specific results are stored in `pixel_policy_manifest.json` and the final verification records.
