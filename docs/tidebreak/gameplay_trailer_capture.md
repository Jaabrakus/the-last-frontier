# Tidebreak gameplay capture — 2026-10-07

Final: `artifacts/tidebreak_gameplay_trailer.mp4` — **33.75 seconds, 1920×1080, constant 60 fps**, H.264 with stereo AAC game audio, **85,314,229 bytes**. Poster: `artifacts/tidebreak_gameplay_poster.png`. Review sheet: `artifacts/tidebreak_gameplay_contact_sheet.png`.

`artifacts/tidebreak_gameplay_manifest.json` contains the complete SHA-256 hashes of the gameplay configuration/source files for each take, source directories, cuts, KO events and timing evidence. These are the canonical baseline files before any later balance candidate was accepted; the capture used no balance-test overrides. All recorded gameplay files checked for Fire/Air predate their process starts. The video SHA-256 is `6571ba42437986b3317df2f6e023afb161ca0fd4c6e1b881e65c3fceaefa9856`.

## What is shown

| Video time | Source excerpt | Event |
| --- | --- | --- |
| 0–7 s | Water, 0–7 s | Normal exchange against Fire |
| 7–18.5 s | Fire, 0.5–12 s | Grown Fireball sends Earth into the water |
| 18.5–33.75 s | Air, 0–15.25 s | Varied strikes and a grown Gust send Water into the water |

Both KOs are earned in ordinary matches. Fire's logged KO is `fire_blast/punch.grown`, 112.518%, opponent lives 3→2, at source 8.783333 s / match 33.8 s (video 15.283333 s). Air's is `air_gust/gust.grown`, 86.792%, opponent lives 3→2, at source 12.316667 s / match 32.325 s (video 30.816667 s). The approach, launch, flight and splash remain in the excerpts. All four elements appear across the fighters.

`tools/ring/highlight_input.gd` drives normal mouse/key actions under **Full** controls, normal difficulty and strong aim help. It varies strikes, makes space for finishers, selects second moves with an actual double-tap and holds RMB to grow a move. It does not inject damage, launch velocity, cooldown changes or results. The base newcomer simulation and gameplay runtime were not changed for filming. The game camera, score, percentages and key strip remain; tutorial cards and replays are hidden/off. This is automated gameplay, not a recording of a person's physical input.

## Normal-speed and audio checks

- Final decode: **2,025 frames, zero black frames, zero repeated frames**. The two intentional cuts are at 7 and 18.5 s. Other detected image changes are combat effects/camera motion.
- Decoded display timestamps are exactly `frame_index / 60`: first 0, last 33.7333333333 s, maximum error **0.0**. Nominal rate is **60.0**. Video and audio durations are both **33.75 s**. A passthrough draft with ambiguous nominal-rate metadata was replaced by one complete encode.
- Fire and Air `timing.jsonl` logs show one process frame and two 120 Hz physics ticks per saved frame, process delta 1/60 s, and `Engine.time_scale == 1` throughout. Fire's phase and video elapsed time both equal 12.7666666667 s; Air's both equal 16.3 s. There is no added slow motion or speed-up.
- Audio comes from the engine's movie writer, selected by the saved engine-frame numbers: **48 kHz stereo, zero missing blocks**. The selected PCM clips peak at −1 dBFS with zero clipped samples; the final track uses AAC 192 kbps and a short ending fade. Music is enabled with `music=on`, alongside the game's SFX.
- Water's interrupted take retained complete frames and a finalized AVI. Three image matches recover the same audio alignment: saved frames 0/120/539 match AVI frames 662/782/1201. Its 9 s preview also shows the game clock advancing normally. The final uses the first 7 s.

## Capture and assembly

Godot **4.7.2 Mono**, high graphics, native scale, TAA, 4096 shadows, no upscaling. The small host window mirrors a full-resolution offscreen view. Its font oversampling is explicitly 1 so the HUD remains sharp. Full commands for the final knockout takes:

```sh
GODOT_TIMEOUT=600 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 --write-movie /private/tmp/tidebreak-film-fire-live/raw.avi -s tools/ring/gameplay_highlight.gd -- out=/private/tmp/tidebreak-film-fire-live fps=60 size=1920x1080 quality=high upscale=off music=on howto=off only=fire lead_fire=25 seconds_fire=90

GODOT_TIMEOUT=600 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 --write-movie /private/tmp/tidebreak-film-air-live/raw.avi -s tools/ring/gameplay_highlight.gd -- out=/private/tmp/tidebreak-film-air-live fps=60 size=1920x1080 quality=high upscale=off music=on howto=off only=air mouse=body lead_air=20 seconds_air=75
```

The Water source is `/private/tmp/tidebreak-film-knockouts`, recorded at the same graphics/fps with a 5 s live lead-in. Its earlier `fast_lead` draw suppression caused a frozen countdown in the visible host and was **removed**. Final Fire/Air takes draw continuously through countdown and lead-in. Rendering/writing frames can take longer than their gameplay time; the window is titled “Video rendering — saved playback at normal speed.” This affects capture wall time, not the encoded timing checked above.

`tools/ring/edit_highlight.py` selects unchanged frame ranges, preserving engine-frame indices. `tools/showcase/video_audio.py` extracts the corresponding game audio. Final frames and PCM are concatenated in the cut order above, then encoded once with the existing native AVFoundation encoder:

```sh
swiftc -O -module-cache-path /private/tmp/tidebreak-film-bin/swift-cache tools/showcase/video_encode.swift -o /private/tmp/tidebreak-film-bin/video_encode
/private/tmp/tidebreak-film-bin/video_encode encode /private/tmp/tidebreak-trailer-final/frames 60 /private/tmp/tidebreak-trailer-final/trailer.mp4 /private/tmp/tidebreak-trailer-final/audio.wav 20000000
/private/tmp/tidebreak-film-bin/video_encode check artifacts/tidebreak_gameplay_trailer.mp4
```

The completed single encode was copied atomically into the artifact path. Timing, audio extraction, encode and decode logs remain beside the temporary takes; configuration evidence and final validation are retained in the durable manifest. Existing user MP4/GIF files were preserved. The capture logs include an existing missing `lightning_crack` sample warning; the selected footage has its other game audio. An earlier interrupted process finalized its AVI before an engine shutdown backtrace; the completed final takes and encoded media were independently checked.

## Installed-lighting preview

After balance C was accepted and the ring's noon lighting was adjusted, a separate **8.00 s, 1280×720, constant 60 fps** Water-versus-Fire preview was recorded at `artifacts/tidebreak_lighting_preview.mp4` (**12,391,617 bytes**). The original trailer above remains unchanged. This new preview uses the installed C gameplay and lighting; `artifacts/tidebreak_lighting/capture_manifest.json` retains their exact source hashes, source snapshots, commands and checks.

The preview contains 480 consecutive frames, with zero black/repeated frames or detected jumps. Decoded timestamps are exactly frame index /60, and audio/video both last 8 s. Recorded gameplay uses `Engine.time_scale == 1`, one process frame and two physics ticks per saved frame; gameplay and video elapsed times agree at 7.9833333333 s between first and last frame. Game music/SFX are 48 kHz stereo AAC; selected PCM peaks at −1 dBFS with zero clipped samples and zero missing audio blocks. Matching source pictures at saved frames 0/240/479 established AVI frames 662/902/1141, so this take uses audio extraction `--offset -1`. Live Water's blue effects and Fire's orange effects remain distinct in the preview contact sheet.

`artifacts/tidebreak_lighting/` also preserves the controlled before/after stills, installed noon/golden/night views, a native Godot-composed comparison sheet, preview contact sheet/poster and validation logs. The still fixture freezes actors, camera and shader time with time scale 0; this is separate from the normal-speed gameplay recording. Existing missing-sample and shutdown resource warnings are retained in the log; the preview has no script errors.
