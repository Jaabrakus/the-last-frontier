# Tidebreak lighting — 2026-10-07

The reported gameplay view had broad glare around clouds, pennants and banners. A controlled comparison of the actual ring isolated the glow contribution: disabling glow or restricting it removed the surrounding haze while retaining the fighters and deck. The chosen noon treatment also reduces the sun/exposure gain and contrast, with a little more sky fill in shadows.

## Installed change

`scripts/ring/ring_look.gd` owns the changes; the shared world sky, shaders and environment defaults are untouched.

| Noon setting | Before | Installed |
| --- | ---: | ---: |
| Glow threshold / intensity | 1.4 / 0.35 | 4.0 / 0.22 |
| Sun shaft strength | 0.9 | 0.25 |
| Sun / exposure multipliers | 1.12 / 0.98 | 1.0 / 0.9 |
| Sky ambient contribution | 0.42 | 0.5 |
| AgX contrast | 1.45 inherited | 1.2 |
| Display contrast / saturation | 1.04 / 1.12 | 1.0 / 1.06 |

Golden and night retain their prior lighting values, with their prior AgX contrast now set explicitly so it is restored after switching from noon. RingLook also honors an explicit `WorldSettings.glow = false`; it previously forced glow back on for every mood. Element effect strength is unchanged.

## Visual evidence

The initial comparison rendered four treatments from three fixed cameras at 1280×720, high quality and native scale: the original settings, glow disabled, selective glow, and the selected treatment. Fighter positions, camera transforms, hour 12.25 and sky time 1.1666667 were held constant. Each camera received 40 settling frames. This is an engine-rendered comparison, with no image retouching.

The still fixture pauses actors and sets `Engine.time_scale = 0` to freeze animated shader time. DayNight continues to set its baseline before RingLook each frame with zero delta; its sun/exposure therefore do not accumulate. The measured original sun/exposure were 4.102 / 1.02034, versus 3.6625 / 0.93705 for the selected treatment. Forest cover was zero and forest eye gain was 1.0. These measurements distinguish the controlled still fixture from normal-speed gameplay capture.

Review captures and manifests are retained under `artifacts/tidebreak_lighting/`. The existing full trailer predates this lighting adjustment; the separate `artifacts/tidebreak_lighting_preview.mp4` shows the updated build.

## Checks

Copies of the check logs are retained in `artifacts/tidebreak_lighting/checks/`.

- The existing RingLook integration test passed 14/14 checks for loading, dressing, mood selection, clock selection and singleton behavior.
- Project compilation after the lighting edit passed 860 scripts, zero failures (`/private/tmp/frontier-astra-verify/lighting-final-compile.log`).
- `tests/ring/test_ring_lighting.gd` passed 17/17 rendered checks with no script errors. It exercises the actual EnvironmentRig and DayNight, explicit graphics choices across mood changes, stopped-clock stability, restoration of the initial night grade, and a round trip back to noon including its AgX grade. Measured frame drift and round-trip difference were both zero. Headless invocation exits with a clear message because it cannot exercise RingLook's render-side writes. Log: `/private/tmp/frontier-astra-verify/ring-lighting-rendered-regression.log`.
- Installed noon, golden and night were rendered from the same three cameras. `artifacts/tidebreak_lighting/comparison_before_noon_golden_night.png` shows the original noon, installed noon, golden and night in that column order. The matched noon before/after comparison restores definition around the clouds and banners while retaining visible fighters, water and deck details.

The updated gameplay preview is **8.00 seconds, 1280×720, constant 60 fps, with game audio**. All 480 frames decoded; there were zero black or repeated frames. Presentation timestamps are exactly `frame / 60`, and both tracks are 8.00 seconds. Audio alignment was checked against matching first, middle and final frames from the engine movie. The capture record and source hashes are under `artifacts/tidebreak_lighting/`; the normal-speed recording workflow is described in [the capture notes](gameplay_trailer_capture.md).
