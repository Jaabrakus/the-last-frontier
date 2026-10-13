# Tidebreak palette — Planetes reference

The owner confirmed **Planetes, the space anime**, as the reference for the game's colors and look. This pass applies a restrained slate, cream, clay and brass palette to the actual arena, with a little more cool fill and softer noon contrast.

## Reference and interpretation

Nine stills from [Sunrise's official Planetes feature](https://www.sunrise-world.net/titles/pickup_154.php) were visually reviewed. Observed cues include chalky whites, cool slate shadows, dark silhouette separation and warm accents concentrated in machinery or action. The [daylight scene](https://www.sunrise-world.net/img/titles/154/w02.jpg) has a blue sky and cream clouds; the [action scene](https://www.sunrise-world.net/img/titles/154/s03.jpg) carries orange-red accents.

The working colors are interpretations for Tidebreak, **not sampled or asserted official palette values**: ink `#1C2535`, slate `#586B80`, pale blue-gray `#A9BBC6`, ivory `#E4E0CE`, weathered stone `#A49A86`, and clay `#B96043`. They guided the choices; existing texture multipliers and lighting determine the final on-screen colors. Reference images were viewed in browser memory and were not added as game assets.

## Installed values

- `scripts/ring/ring_look.gd`: noon sky contribution 0.50→0.54, a small cool ambient fill, AgX contrast 1.20→1.12, saturation 1.06→1.02, and SSAO intensity 1.50→1.30. Existing selective glow remains. Attack-effect gain stays at 1.0.
- `data/ring/ring.json`: cream/weathered deck and surround tints; blue-gray water-curtain color and off-white foam; surface-water roughness 0.03→0.10. All twelve changed data paths are visual; dimensions, water flow, colliders, sockets and combat values are preserved.
- `scripts/ring/ring_dressing.gd`: muted element banners, clay/blue-gray canopies and pennants, restrained brass, matte paint/tile materials, and slate water tints. The dressing's own water overrides are adjusted because they supersede the base water colors during a dressed match.

Shared world environment, LUT and shader defaults are not edited by this pass. Material changes stay in the arena's own material instances. Fighter and attack hues remain distinct. The game camera is unchanged.

[Godot's Environment reference](https://docs.godotengine.org/en/latest/classes/class_environment.html#class-environment-property-ambient-light-sky-contribution) documents the blend between sky illumination and ambient color. The installed Godot version is 4.7.2; the actual blend and rendering were checked in that engine rather than inferred from documentation alone.

## Evidence

`artifacts/tidebreak_planetes_palette/` contains before/after stills, original source snapshots, comparison records, checks and the new gameplay preview. Three still views match actor positions, camera transforms, FOV, hour and shader time exactly. These comparison stills intentionally freeze the scene; the gameplay preview runs at normal speed.

Existing tests passed without assertion changes: RingLook integration **14/14** and the rendered lighting regression **17/17**. The rendered test measured zero frame drift and zero change after the noon→golden→night→noon round trip. It also verified that graphics settings still control glow and SSAO. Matched-camera stills were reviewed for fighter visibility, deck material separation, sky highlights and banner contrast.

The completed sixty-second trailer predates this palette pass. The separate preview shows the updated game build; capture and export records preserve its exact source hashes and timing.

The finished preview is `artifacts/tidebreak_planetes_preview.mp4`: **16 seconds, 1280×720, 60 fps**, with four seconds per element, normal gameplay speed and game sound. Only the two corner fighter panels are hidden. Its actual game camera and camera-origin aiming match the demo. All 960 final frames decode, timestamps equal frame number divided by 60, and there are no black or repeated frames. Twelve sound-alignment anchors cover the first, middle and last frames of each element segment.

The preview retains the requested pixel policy watermark. The matching detector recovered its UUID and all deny flags from pixels without container metadata; sound packets and frame timing are unchanged from the unmarked master. Eight sampled final frames were visually reviewed. These restrictions need a compatible reader and cooperation; they cannot force compliance.

`artifacts/tidebreak_planetes_palette/comparison.html` provides an interactive comparison of the original renders, with three camera views and keyboard/pointer controls. Browser checks passed for desktop and mobile layouts, with no page errors or external requests.

## Flight-sound cleanup found during capture

The capture logged one `SCRIPT ERROR` in `BendSounds._Voices._flying`: a class check was attempted on a previously freed projectile. The original trace is retained at `artifacts/tidebreak_planetes_palette/previewrecords/run.log:100`. It appears after the completed Fire segment and before the completed Earth segment. A match-restart cause is an inference; the exact engine frame was not logged. The preview completed and its saved timing and sound-alignment checks passed. It was captured before the repair and was not recaptured.

`scripts/bending/bend_sounds.gd` now validates object type and liveness before class checks in the flight watch, position, fade and cleanup paths. Invalid positions return zero. A live owner with a freed/null stone now ends its flight sound instead of falling through to the generic live-node branch. The first regression run exposed that second cleanup defect with five failed lifecycle assertions; the test stayed strict.

`tests/bending/test_bend_sounds.gd` adds a `freed` partition using actual destroyed projectiles and stones, typed return assertions, real loop fade/watch/physics cleanup, and continuation of a following live flight. **40/40 focused route/voices/freed checks passed**, including 22 new lifecycle assertions. The freed partition also passed **22/22 on its own**, with zero script errors in both passing runs. Existing route and voice assertions are unchanged. Pre-repair snapshots, final source hashes, the failed run and passing runs are retained in `artifacts/tidebreak_planetes_palette/checks/freed_flight/`; the snapshots were taken before repair, not before capture.

Other observed capture diagnostics remain recorded: animation-loop endpoint warnings, the missing `lightning_crack` sound-file warning, and teardown disconnect/resource warnings. Zero missing extracted sound blocks does not establish that every game sound asset exists. These records do not claim a complete game-wide or animation-origin audit.
