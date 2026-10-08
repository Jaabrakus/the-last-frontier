# Character repair, beginner entry and ring polish — 2026-10-07

This follows the historical [restart handoff](astra_restart_handoff.md). The restart focused on the reported character glitches and on making the first game easy to learn. The saved integration remains in the working tree; no commit or push was made.

## Reproduced character faults

The focused regression loads the actual clip library and applies the same `ToolPose` layers as the player. Before the repair, a fall-to-helpless state change moved a sampled joint 1.1501 m at zero elapsed time. A falling layer also overwrote an airborne attack, displacing its striking foot 0.7965 m from the cast pose. Clearing hit metadata on reset left the cached struck pose at full weight.

`scripts/sway/sway_pose.gd` now blends sampled outgoing states into incoming states, including interrupted transitions and root/pelvis translations. Ordinary falling supports the air legs and attack layers. Mandatory reactions remain above attacks, and contact states retain immediate timing. Empty struck metadata clears the cached hit pose.

`tests/bending/test_ring_pose_transitions.gd` verifies the resulting bone poses, rather than merely counting active layers. The first repaired run passed 12 checks, including an exact halfway blend, uninterrupted and interrupted handoffs, visible air legs and attacks, contact priority, and reset cleanup.

Direct scene loading exposed another visible problem: the performance warm-up drew an enormous KO splash over live competitors. `scripts/ring/ring_level.gd` now runs that large splash only while the loading screen covers the game. Normal menu loading retains the warm-up.

Recording consecutive gameplay takes exposed a separate scene-removal error. An active NPC attack trail tried to reparent while its parent was removing the fighter, then accessed a missing scene tree. `scripts/bending/bend_looks.gd` now stops emission immediately and defers the reparent/timer work with weak references. The focused regression recreates that locked-parent removal, checks that a surviving trail keeps its world position, and checks both timed expiry and complete scene teardown. It passed all four checks without script errors or leaked objects.

## Beginner flow

The permanent **Start here** menu row offers **Learn the basics** and **Play an easy match**. Both explicitly enable Basic controls, strong aim help, and easy difficulty. Lessons clear saved practice speed and repeated-launch options, include recovery, and allow the player to proceed at their own pace. Opening the panel alone preserves settings. The menu and its clickable controls scale together in smaller windows; the 1280×720 layout also reserves a gap above the picture caption.

Basic-mode hints no longer advertise the disabled Wall, Heal, and air-dodge inputs. Help updates when the control preset changes. Recovery wording explains assistance without promising a guaranteed return. These changes apply to any new player; they make no assumptions about skill based on gender.

## Verification record

Logs are in `/private/tmp/frontier-update-verify` and `/private/tmp/frontier-astra-verify`.

| Check | Result |
| --- | --- |
| Project-wide compile | 860 OK, 0 bad (`lighting-final-compile.log`, including the lighting regression, capture tools and trail cleanup regression) |
| Focused pose transitions | 12 passed |
| Attack-trail cleanup during scene removal | 4 passed; no script errors or leaked objects |
| Bending pose integration | 54 passed |
| Real player/bot clip situations | 122 passed; all 65 player and 62 bot clips observed |
| Ring movement / guards / edge recovery | 66 / 61 / 20 passed |
| Ring feel, including returned-stone collisions | 25 passed |
| Combos under the real rules, installed candidate C | 8 passed; Pop→Gust true at 0% and 150% |
| Quantitative stock rules | 36 passed after repairing stale calibration references; independent invariants and tolerances preserved |
| Element balance, installed candidate C | 144 equally scheduled cross-element games; unchanged 40–60% personal-win screen passed |
| Beginner setup / lessons | 115 / 190 passed; subsequent menu layout changes also passed the menu regression |
| Main menu | 60 passed, including scaled mouse input and caption clearance at 1280×720 |
| Menu-to-match gameplay, earth / water / fire / air | 38 passed per element; three replays and exact resumes per element |
| Candidate C beginner smoke, Basic / strong aim / Easy | 3/4 wins; 6/6 survivable launches recovered; no falls with recovery resources unused |
| Candidate C Full-control pass-through | Identical input for 8,916 observed frames; no helper presses |
| Animation library preservation | 122 untouched clips identical; timing and non-IK metadata preserved across all 126 clips |

Rendered inspection used the actual ring, player and bot, from front-three-quarter and side cameras during idle, running, falling, air attacks and knock reactions. Captures are in `/private/tmp/frontier-astra-verify/visual-final`; the medium-quality capture allows temporal rendering to settle after each camera move. The four revised clip assets were also inspected across their timelines and loop seams in `/private/tmp/frontier-astra-verify/air-clips`. This is scoped visual inspection, not a claim that every possible outfit and animation combination has been checked.

The beginner smoke used an isolated copy of `tests/ring/test_first_five.gd` with strong aim help (matching **Start here**), the exact candidate C runtime overrides, and its own settings file. It covered all four player elements against Easy Earth; Fire reached the 300-second limit without a win. The one recorded fall was classified unsurvivable by the existing flight predictor. `runs=4 gate=off full_runs=2 full_s=40` makes this a scoped smoke, not the full 20-run win-rate gate or human playtesting. Root checked the explicit `full_unchanged=true` metric and absence of script errors; all snapshotted input hashes were unchanged. Log: `/private/tmp/frontier-astra-verify/beginner-c-strong-smoke.log`; harness and hashes are in the same directory.

## Installed element balance

Candidate C adds commitment to Air's finishers (Ball base lock 0.75 seconds, Gust 0.45) and brings stock-ring Fire NPCs to a 2–6 m range. Damage, launch growth, weight and Earth Catch/return/rally remain unchanged from the inherited baseline. Slice remains 0.5 seconds and Pull/Slam 0.35. The canonical combo check passed 8/8; Pop→Gust still works at 0% and 150%.

Across all 144 fixed cross-element games, Earth won 29/72 personal appearances (40.3%), Water 43/72 (59.7%), Fire 32/72 (44.4%) and Air 40/72 (55.6%). Their shares of all wins were **20.1%, 29.9%, 22.2%, 27.8%**, against the owner's 25% goal. All five samples are retained, with 12 games per ordered pairing. The [original 72-game screen failed narrowly](../../artifacts/tidebreak_balance/combined_c_report.md); exactly 72 fresh replication games were declared before their outcomes were inspected, then all 144 were judged against the same band. The [final report and matchup matrix](../../artifacts/tidebreak_balance/final_c_144_report.md) and [full balance record](astra_balance_verification.md) preserve both decisions, source hashes, exact harnesses and seeds.

This passes the declared finite-sample normal-bot screen, not exact equality or human skill-curve validation. Earth and Water remain near the band edges, matchup differences remain, and median true-string length is still 1. The original quantitative regression had nine stale reference failures after the inherited data changes; its repair preserves independent launch arithmetic, volley counting, staling, guards, Catch/rally and healing restrictions without widening tolerances.

## Gameplay recording

The finished trailer is `artifacts/tidebreak_gameplay_trailer.mp4`: **33.75 seconds, 1920×1080, constant 60 fps, stereo game audio**, with a Fireball knockout and a charged Gust knockout. All 2,025 frames decoded; none were black or repeated. Every video presentation timestamp is exactly `frame / 60`, including the two edit boundaries. Audio and video both span 33.75 seconds. The capture manifest, poster and contact sheet are beside the video. The footage records the canonical build before the subsequent balance candidates; its hashes and that scope are explicit in the manifest.

The user asked for normal-speed gameplay with visible knockouts. The initial recording driver repeatedly chose quick attacks at close range; the new capture-only input driver alternates normal attacks and commits to charged finishers. It does not write damage, fighter positions or outcomes. The existing newcomer model used by behavioral tests remains unchanged.

The first encoded timing preview, `artifacts/tidebreak_realtime_preview.mp4`, is 9.00 seconds at 1920×1080 and 60 fps. AVFoundation decoded all 540 frames with no repeated or near-black frames. At output times 0 and 8 seconds, the visible match clock reads 7:55 and 7:47. This verifies normal playback speed for that excerpt despite the much slower offline render window. The preview is silent; it is not the finished trailer or a real-time rendering performance benchmark. Timing sheet: `/private/tmp/tidebreak-realtime-preview/timing.png`.

The user then supplied a screenshot of the capture window frozen at countdown “1.” The capture-only `fast_lead` shortcut disabled viewport drawing while simulating the unrecorded lead-in, leaving that old image in the visible window. That shortcut was removed; subsequent takes draw throughout the countdown and lead-in. Frame/timing logs are also flushed during recording, so a terminated capture does not lose the completed frame map.

## Lighting

The default noon ring now has less cloud/banner bloom, weaker sun shafts, a gentler contrast curve, and more sky fill. Golden and night keep their existing treatment and explicitly restore their AgX grade when switching moods. Explicit glow-off settings are honored. These changes are confined to RingLook.

The same three camera views were rendered before the change and with the installed noon, golden and night moods. The rendered regression passed 17 checks, including graphics choices, restoration of the initial night grade, and zero measured light/exposure/grade drift after repeated frames and a round trip through other moods. The existing RingLook integration test passed 14 checks. See [lighting evidence and settings](lighting_verification.md); `artifacts/tidebreak_lighting_preview.mp4` is the separate normal-speed preview of the new lighting and installed balance.

## Remaining integration limits

- The installed balance passed the declared 144-game screen; it does not establish exact 25% pooled shares, all historical soak targets, or human skill curves. Strong matchup differences and a separate High Kick NPC lob-lead mismatch remain documented in [the balance record](astra_balance_verification.md).
- The earlier cold-project-cache performance run met its fight, fall, replay and restart checks, but its longest loading frame was 513 ms, above the 250 ms aim. Loading thresholds were explicitly disabled in that run. OS/driver caches were retained.
- The four clip revisions do not complete or rescore every historical art note in `anim_under_bar_notes.json`.
- Existing horse-helper errors on scene removal and ObjectDB/resource warnings at process exit remain. The listed animation integration checks had no script errors.

No animation-origin conclusion is made here. The provenance records and actual input attribution remain in place.
