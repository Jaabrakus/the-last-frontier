# Cleanup plan: worktree-spellcraft (Tidebreak), merged from the five audits

Written 2026-10-06, read-only. Nothing in any repo or worktree was changed, and Godot and Blender were not run.
Sources: code.md (code graph), assets.md, features.md (retired features, with line hooks in g1_hooks.txt and
g_tests.txt), hygiene.md and thuyvan.md (the Thủy Vân overlap), all in this folder. Rulings come from
thuyvan_answer.md (= docs/tidebreak/cleanup_thuyvan_keep_retire.md). Sizes come from `plan_sizes.py` in this folder,
which sums the tracked files on disk; the .import and .uid companions are counted. 1 MB here is 1024 KB.

**Scope.** Every deletion below is on branch worktree-spellcraft only. The thuyvan branch inherits each one through
its one-way merge. Branch main keeps its copies, and git history keeps everything deleted from the tree.

**Before starting**
- The worktree has uncommitted changes from other work: docs/bending_design.md, tests/ring/test_ring_rules.gd and
  tools/loop/recover.py. Commit only the cleanup's own hunks and never sweep those files in (concurrent-sessions rule).
- Gate R2 is still running: logs/gate_r2_* were written at 09:27 today. Start the cleanup after it finishes.
- Every test run needs the one-at-a-time Godot lock, so run each through scratchpad/godot_run.sh or run_test.sh.

## Summary

| Tier | Items | Reclaimed | Risk | Gate |
|---|---|---|---|---|
| 1 safe | 7 groups (68 files) | 32.8 MB | none | none |
| 2 retired, ungated (2.0-2.5) | 6 steps | about 78.8 MB | low to medium | none |
| 2 retired, gated (2.6-2.9) | 4 steps | about 24.4 MB (+1.9 MB if the carry pieces go too) | high | Thủy Vân and owner answers |
| 3 hygiene | 24 merged branch refs, 3 scratchpad groups (+6 unmerged refs flagged IRREVERSIBLE) | 0.47 MB now, +7.7 MB later | none, except the flagged refs | Gate R2 must finish |
| ASK | 26 questions (15 owner, 11 Thủy Vân) | up to about 328 MB, of which 308 MB is music | n/a | n/a |

## How conflicts between the audits were settled (by evidence)

| Item | Audits said | Evidence | Result |
|---|---|---|---|
| jog_aim_arm.gd | features: delete. thuyvan: keep (sway_arm uses it) | sway_arm.gd names JogAimArm only in comments (lines 4, 112). Its only code user is player_anim.gd:385/538-542/1068-1080/1116, through `JOG_AIM_ARM = {"pistol": ...}`. The plan retires only "JogAimArm's musket use". | Remove the pistol hook in 2.7 and keep the file. Whether the class itself goes is ASK O10. |
| npc_skirmish.gd | thuyvan: only duel_mode uses it | npc_brain.gd:104 and 113 also build NpcSkirmish. | Deleted in step 2.9 (duel), with edits to npc_brain. |
| npc_ball.gd | thuyvan: part of the NPC core (keep) | Its only user is npc_fighter.gd:878, the musket shot (Kind.BALL). | Deleted with the guns (2.7). |
| quick_offhand.gd, shot_making.gd | code: ask | QuickOffhand's header and player.gd:1074 say "the long gun kept in the left hand". ShotMaking's header says "casting balls ... paper cartridge". | RETIRE-dep, so they are deleted in 2.7 and 2.5. |
| limb_carcass.gd | features: edit only | Its only game users are mammoth_butchery.gd:499 and 507. wildlife_spawner.gd:23 names it only in a comment. | Deleted with the mammoth (2.8). tests/wildlife/test_scavengers.gd gets rewritten. |
| melee_duel_ai.gd | thuyvan: player_controls uses it | player_controls.gd:5 is a comment. No game code reaches it. | Not ruled on, so ASK O8. |
| Fort and range | code, thuyvan: delete with edits. features: ask | thuyvan's scripts/world/story_layer.gd:454/473 (KEEP) calls FortPlan.stake_ground and FortPlan.settle. Its baseline tests/world/test_story_layer.gd:352-353 (UNDECIDED) uses FrontierStructures.FORT_HALF. frontier_level.gd (UNDECIDED) loads FrontierStructures. | ASK T3. Only fort_gate.gd, which nothing entangles, goes now (2.5). |
| Two Fires data, 1757.json | code, thuyvan: delete. assets: ask | thuyvan test_story_layer.gd:139 reads storylines/two_fires.json. 1757 is story_layer's DEFAULT_LAYER. | The stage code goes (2.1) and the data is ASK T4. |
| Mammoth | all: delete with edits | thuyvan tests/world/test_river.gd:248 (a baseline) runs `StandInGiant.new()`. | Gated on ASK T2. |
| Firearms | all: delete with edits | thuyvan tests/thuyvan/test_greybox.gd:158-164 uses FrontierPlayer.FIREARMS and Firearm, and thuyvan_level.gd:80 sets player.no_firearms. | Gated on ASK T1, because the merge would conflict and break that test. |
| Colonial garments | assets: whole folder ask. thuyvan: split | Only shirt_tucked, breeches, sash_worsted, shift_linen, petticoat and shirt_linen are hard-coded defaults or Mountain Folk fallbacks (mountain_folk.json: shirt, legs.lower, accessories.waist). | The rest of colonial goes in 2.4. The six defaults are ASK O5. |
| middle_east | assets: delete. thuyvan: keep salvar_mens | player_appearance ARENA_LEGS (women) uses salvar_mens. | The rest of middle_east goes in 2.4. salvar_mens is ASK O5. |
| southeast_asia (filipino_salakot) | thuyvan: delete. assets: ask | It is a real-people set (RETIRE), but Mountain Folk does not use it. It may suit a Southeast Asian world. | ASK T9. |
| giant_battle.wav | assets: ask. thuyvan: keep | data/ring/rules.json:40 has `fight_cues: ["ring_fight","giant_battle"]`. | KEEP (Tidebreak uses it). |
| tools/anim_author/author_reload.gd | features: delete | docs/animation_provenance.md:43 and :49 cite it as the generator of the reload clips. It names no gun class in code, so it still runs without them. | KEEP as a provenance record (CLAUDE.md). See O11. |
| check_eye_contact.gd | code: delete (broken) | It lives in features/tandem, which the plan does not rule on. | ASK O9. |
| audio/sfx/impacts/ball_* | listed only by thuyvan.md | sfx.gd:260 plays ball_hit_ for any non-ARROW Projectile. The only BALL launchers are firearm.gd:223 and npc_ball.gd:10. | Deleted with the guns (2.7). |

---

## TIER 1: safe (no code edits, no test is affected)

Each item was proved by a zero-hit `git grep` of its path, basename and stem across scripts, data, scenes, tests,
tools and project.godot, plus the asset index (res://, uid://, relative paths, glTF URIs, dynamic patterns).

| # | Files | Size | Proof |
|---|---|---|---|
| 1.1 | 23 review screenshots at the repo root, each with its .png.import (46 files): animals_hair_lineup, animals_heads, animals_smoothed_lineup, asian_faces_women_men, bison_clips_now, bison_gallop_strip, bison_hump_lineup, bison_old_vs_new, clouds_before_after, fell_cut_strip, god_rays_plains, god_rays_strength_lineup, hall_rifle_breech, hall_rifle_side, mammoth_eyes, men_lineup_before_after, saber_grip_hand, saber_hammer_grip, saber_in_fist, saber_on_axe_clips, saber_one_hand, trade_musket_side, wonder_look_before_after | 31.7 MB | No stem is named anywhere in the repo, docs included. |
| 1.2 | assets/weapons/hall_rifle.glb, hall_rifle_musket_walnut.png, trade_musket.glb, trade_musket_musket_walnut.png (+.import, 8 files) | 1.0 MB | WeaponModels builds only musket, pistol and over_under. tools/models/musket.py only writes these files. The optional VARIANT branch in musket.py is deleted with the guns in 2.7. |
| 1.3 | tools/environment/baselines/colliders_baseline_59_placeholder.json | 21 KB | Named only in comments (fort_structures.gd:29, dump_colliders.gd:16). No code reads it. |
| 1.4 | shaders/env/frontier_sky.gdshader (+.uid) | 5 KB | A stale copy. The code loads shaders/sky/frontier_sky.gdshader (environment_rig.gd:63, environment_rig_dev.gd:59). The two files differ (cmp). |
| 1.5 | assets/environment/props/shrub_04/shrub_04.glb.import; tests/compute_weapon_offsets.gd.uid | 1 KB | Orphans: the .glb and the .gd do not exist. The shrub_04 textures stay because build_atlas.py and make_textures.py use them. Optionally drop README.md:642. |
| 1.6 | r1_0.jsonl .. r1_5.jsonl at the repo root (tracked, 0 bytes) | 0 | Nothing reads or writes r1_*.jsonl. |
| 1.7 | docs/main_story.md, docs/maps.md, docs/peoples_world.md | 123 KB | Named RETIRE. Nothing loads them; about 50 files cite them in comments, which will dangle. |

- **Count:** 7 groups, 68 files. **Reclaimed:** 32.8 MB. **Risk:** none.
- **Tests after:** tools/compile_check.gd, tests/smoke_test.gd, and one ring match (scenes/ring.tscn), to confirm that
  nothing imports the removed files. Do it as one commit.

---

## TIER 2: retired features (edits in shared files)

**Order rule.** In each step, edit the referrers first and then delete the files in the same commit, so that every
commit compiles. Run tools/compile_check.gd after every step. The steps are ordered leaves first. Steps 2.6-2.9 are
GATED: do not start one until the ASK it names has an answer.

**Files left alone in every step:** these are UNDECIDED and are only ever edited, never deleted:
- frontier_level.gd
- data/survival
- the thuyvan baseline tests
- squares.json and the terrain

Where a step touches one of them, it says so.

**Line numbers** come from HEAD 473c441. The complete file:line list for the guns is in g1_hooks.txt, and the full
list of tests to rewrite is in g_tests.txt.

### 2.0 Tidebreak prep (edits only, nothing deleted). Ungated, risk: none

- data/sway/moves.json:1757: form_sfx `crackle: "pan_flash"` makes a Form cast play a gun sound. Point it at a bend
  sound such as lightning_crack. This has to happen before 2.7 deletes the flintlock audio.
- tools/sfx/bend/review.py:84: drop its pan_flash reference.
- data/ring/rules.json: delete the unread words controls_line, controls_head and controls_how. The menus read KitWords
  from screens.json, and no code reads controls_how.
- scripts/ui/hud.gd:22-27: refresh the header comment (variation pips, "(2/3)", the water bar, "rooted, slowed").
- Tests: tests/ring/*, tests/sway/*.

### 2.1 Old story stages. Ungated, risk: medium. 28 files, 382 KB

- **Delete:**
  - scripts/story/{raid_stage, march_stage, rook_walk, sky_battle, wreck_fall, story_slice}.gd (+.uid)
  - tests/story/{sky_battle_shots, test_raid_stage, test_sky_battle, test_slice, test_slice_fixes, test_wreck, test_two_fires_slice}.gd
  - tools/showcase/raid_preview.gd
- **Edits:**
  - story_effects.gd:25, 102-106 (stage dispatch)
  - story_objectives.gd:54, 145-164
  - story_director.gd:27, 95-119, 171-176, 871, 903
  - story_actor.gd:5-6, 56
  - main_menu.gd:348: New game must stop setting `StoryDirector.incoming = "two_fires"`, because the stages it plays
    are gone.
- **Keep:**
  - The story engine and the story_actor, story_bark, story_contact, story_dialogue and story_walker scripts.
  - The Two Fires data files (ASK T4).
- **Rewrite** (they mention frontier content: re-stage them, do not delete them):
  - tests/story/test_mission_flow.gd
  - tests/story/test_captivity.gd
  - tests/sway/test_free_use.gd
  - tests/customizer/test_new_garments.gd
- **Tests after:** tests/story/*, tests/sway/*, tests/customizer/*. Then the thuyvan baseline test_story_layer.gd,
  which still reads the kept two_fires.json.

### 2.2 Wonder sky, sky galleons, SkyTear. Ungated, risk: medium (sky shader). 36 files, 10.2 MB

Do this after 2.1, because sky_battle and story_slice use SkyTear and WonderLook.

- **Delete:**
  - scripts/world/env/{wonder_look, sky_traffic, sky_tear}.gd (+.uid)
  - shaders/sky/wonder_sky.gdshaderinc
  - assets/sky/
  - tools/environment/{wonder_shots, galleon_shots, tear_shots}.gd
  - tools/models/sky_galleon*.py
  - tests/env/test_sky_tear.gd
- **Edits:**
  - environment_rig.gd:97-100, 144-153 (the SkyTraffic spawn, which today makes the RING load sky_galleon.glb),
    172-184 and 206-210
  - frontier_sky_dynamic.gdshader:281 (#include) and 326-348
  - data/ring/prefetch.json:22-24 and the matching data/startup/prefetch.json entries. Re-record both with
    tools/perf/ring_prefetch_list.py, which needs the Godot lock.
- **Keep:** tools/music/cues/story_wonder.py and story_wonder.wav. The music cues are UNDECIDED (ASK O2).
- **Tests after:**
  - tests/env/*
  - a ring match, looking at the sky: day and night, no shader errors
  - tests/world/* baselines

### 2.3 Invented test peoples. Ungated, risk: low. 5 files, 18 KB

- **Delete:**
  - data/customizer/world_peoples.json
  - tests/customizer/test_world_peoples.gd
  - tools/character/world_peoples_shots.gd
- **Edits:**
  - peoples.gd:31/87: the WORLD_* code. It already tolerates the missing file.
  - people_emblem.gd:603: the world-peoples section.
  - The world notes in hair_colors.json.
- **Keep:** every face preset (owner rule).
- **Tests after:** tests/customizer/*.

### 2.4 Period dress (sets with no default role). Ungated, risk: medium. About 68.2 MB

- **Delete:**
  - assets/character/garments/{frontier, drift, military, woodlands, militia, highland, africa, spanish}/ (47.2 MB,
    275 files). militia/ includes 8 orphan glbs that are not in the catalog.
  - middle_east/ except salvar_mens* (3.8 MB)
  - colonial/ except shirt_tucked, breeches, sash_worsted, shift_linen, petticoat and shirt_linen (13.0 MB)
  - assets/character/hair/hair_{bag_wig, chonmage, qing_queue}* (5.2 MB)
- **Edits:**
  - Rebuild assets/character/catalog.json with tools/character/lib/catalog.py.
  - data/npc/factions.json: the garment ids of the period factions. Dress them in the BASIC defaults; the factions
    themselves are ASK T6.
  - outfit_tab.gd
  - player_outfit.gd: rigging_harness, and slops in CLOSED_IDS.
  - worker_gear.gd: ew_sash.
  - The tricorn in cloth_materials.gd, creator_stage.gd and character_body.gd.
  - inventory_state.gd: the frontier powder_horn garment.
  - story_walker.gd COSTUMES, and the garment ids in data/story/costumes.json (that file stays, ASK T4).
  - camp_station.gd: moccasins.
  - data/survival/items.json garment rows (UNDECIDED file: edit those rows only).
  - assets/character/body/peoples.json: remove the chonmage and qing_queue hair ids from the presets only. The faces
    stay.
- **Leave for a follow-up:** the legacy builders tools/character/garments/{frontier, militia, woodlands, military_*}
  (0.9 MB). tools/character/build_character.py and check_body_deform.gd import them.
- **Rewrite:** tests/customizer/test_clothing.gd and test_new_garments.gd.
- **Tests after:**
  - tests/customizer/*
  - tests/npc/* (faction dress)
  - the creator outfit tab
  - a ring match: the arena dress still uses breeches, shirt_tucked and sash_worsted
  - thuyvan's test_greybox after its merge (the Mountain Folk preset)

### 2.5 Small retired leaves: musket club, shot making, FortGate. Ungated, risk: low. 7 files, 17 KB

- **Delete:**
  - data/melee/musket_club.json
  - scripts/survival_game/shot_making.gd
  - tests/melee/test_musket_club.gd
  - scripts/world/structures/fort_gate.gd
- **Edits:**
  - gather_tools.gd: 73-78 (MELEE_TOOLS), 155, 185 (CLUB_ACTION, the middle mouse button), 468, 508, 678-690, 921
    and 1770-1782 (the musket club). Leave the `is Firearm` checks for 2.7.
  - axe_melee.gd:53 DATA_PATHS
  - campfire.gd:260-278 (ShotMaking)
  - game_items.json: the bar_lead note
  - tools/showcase/showcase_video.gd and trailer.gd (FortGate)
  - The cast_balls recipe row in data/survival is UNDECIDED data. Leave it; it goes dead without crashing.
- **Rewrite:** tests/survival_game/test_gear.gd.
- **Tests after:** tests/melee/*, tests/gathering/*, tests/survival_game/*, tests/fire/*.

### 2.6 Loadout / SlingRig. GATED on ASK O4 (bow and spear carry). Risk: high. 154 files, 7.0 MB (+1.9 MB)

This step comes before the guns so that the gun step never edits sling_rig.gd.

1. **Moves first** (one commit, compiles):
   - scripts/loadout/reach_ik.gd to scripts/player/anim/reach_ik.gd, with its .uid. Keep class_name ReachIK. It is
     the base of the kept PalmReachIK and TorchCarryIK, and arm_solve.gd and horse/foot_drag.gd use it.
   - data/loadout/loadout_items.json (the item-kind registry) into inventory data. Update inventory_state.gd,
     storage_chest.gd:47 and player_grip.gd.
   - SlingRig.HAND_OFFSET into its user: npc_fighter.gd:349, or WeaponModels.
2. **Edits:**
   - player.gd:316-336, 417-427, 886-938, 1055, 1129, 1811, 1910
   - player_grip.gd, worker_gear.gd, tool_carry.gd, hunt_run.gd
   - player_appearance.gd, and player_outfit.gd:22 (it reads sling_runtime.json)
   - inventory_state.gd, hotbar.gd, inventory_screen.gd, item_icons.gd, item_info.gd
   - captivity.gd
   - save_parts.gd: old saves that carry loadout blocks must still load.
   - death_rule.gd, bare_start.gd, sway_caster.gd, player_traversal.gd, foot_drag.gd, fishing_gear.gd,
     gather_tools.gd, arm_solve.gd, npc_fighter.gd
   - features/tandem/tandem_arm_hold.gd
   - data/gathering/gathering.json
   - addons/release_metadata/policy.gd:18 (res://data/loadout/)
   - data/startup/prefetch.json:151-190
   - LoadoutInput's sling_all action (X)
   - tests/building/test_building.gd (LoadoutInput)
3. **Delete:**
   - scripts/loadout/ and data/loadout/, minus the moved files
   - assets/loadout/{musket_sling, pistol_sling_buckle, pistol_sling_loop, pistol_belt_hook, powder_horn}*
   - scenes/loadout_preview.tscn
   - tools/loadout/, tests/loadout/
   - If O4 = "no body carry": also assets/loadout/{quiver, bow_cord, spear_pair_tie, dart_bundle, tomahawk_frog}*,
     MANIFEST.json and strap_routes_bind.json. If O4 = "keep the bow/spear carry", keep a trimmed SlingRig for them
     instead, and delete only the gun pieces and the powder horn.
- **Rewrite:** the 17 tests in thuyvan.md's loadout row and g_tests.txt.
- **Tests after:**
  - tests/inventory/*, tests/ui/test_hotbar.gd, tests/save/test_save_game.gd
  - tests/companion/*, tests/climb/*, tests/torch/*
  - the anim suite tests/anim/run_all.gd
  - the owner plays the bow and spear draw/holster (an animation-regression risk)

### 2.7 Firearms. GATED on ASK T1 (coordinate with the Thủy Vân session). Risk: high. About 13.2 MB

- **Delete code** (34 files, 150 KB):
  - scripts/weapons/{firearm, musket, pistol, over_under, musket_reload, musket_butt_ground}.gd and
    scripts/weapons/over_under/
  - scripts/player/anim/{left_grip_ik, gun_carry_damper, gun_middle_carry_ik, trigger_finger, right_seat_ik}.gd
  - scripts/player/quick_offhand.gd
  - scripts/npc/npc_ball.gd
- **Delete assets** (239 files, 12.4 MB):
  - assets/weapons/{musket.glb, musket_walnut.png, pistol.glb, pistol_pistol_walnut.jpg, over_under*}
  - audio/sfx/flintlock/ (75 wav + flintlock_manifest.json)
  - audio/sfx/impacts/ball_*
- **Delete tests, tools and data** (27 files, 658 KB):
  - tests/weapons/{test_over_under, over_under_preview, range_crosscheck}.gd
  - tests/anim/{test_reload_legs, test_weapon_holds, pistol_shots}.gd and tests/anim/tools/rifle_hold_shots.gd
  - tests/torch/test_two_muskets.gd, tests/check_weapon_axes.gd
  - tools/weapons/{build_over_under, long_gun_clip_probe, long_gun_clip_report, range_sim}.py and
    range_research_input.json
  - data/weapons/range_research.json
  - tools/models/{musket, pistol}.py
  - tools/sfx/flintlock.py
- **KEEP:**
  - tools/anim_author/author_reload.gd (provenance)
  - jog_aim_arm.gd (O10)
  - left_arm_pose, aim_stabilizer, aim_idle_pose, palm_reach_ik, prop_flip_guard and hand_holds
  - NpcCover and HuntAim
  - weapon.gd, projectile.gd, weapon_models.gd, weapon_balance.gd, ballistics_util.gd and ballistics.json (with their
    gun rows trimmed)
- **Edits** (file:line):
  - **Player:**
    - player.gd: 54, 165, 177-182, 207-208, 257, 298-299, 479 (start with the hands free instead of
      switch_weapon('musket')), 540-545, 581, 1074-1077, 1217, 1444.
    - player_anim.gd: 339-394, the gun vars plus the JOG_AIM_ARM pistol entry. 498-542: keep LeftArmPose,
      TorchCarryIK and AimStabilizer; drop the gun modifiers and the pistol JogAimArm hookup. Also 942-943,
      1067-1080, 1116 and 1133-1134.
    - hand_holds.gd:72, 110, 133, 234, 243, 295, 538, 543
    - upper_body.gd:423
    - anim_graph_data.gd:39 WEAPON_ORDER
    - anim_inputs.gd:23
    - The order comments in torch_carry_ik.gd, left_arm_pose.gd and player_ragdoll.gd:21.
  - **Audio:**
    - weapon_audio.gd:30-50, 76, 152-178, 241-249
    - sfx_manifest.gd:21-28, 59-65, 187-194, 225-231
    - sfx.gd:256-278 (ball_hit / ball_whizz become arrow-only)
    - projectile.gd:60 (the whizz) and 85
    - impacts_manifest.json: the ball_* entries
    - tools/sfx/gen_manifest.py and gen_all.py
    - npc_fighter.gd:892, story_director.gd:740, hunt.json:51/91
  - **Fx:** fx.gd: muzzle_blast, pan_flash, SMOKE and warm_up:146-147. Also npc_senses.gd:214-218 and
    hunt_run.gd:997.
  - **NPC:**
    - npc_fighter.gd: header 14-30, 117, 332-349, 440-478, 603-742, 878, 891-892, 1084, 1205, 1391-1407. It also
      hosts the Tidebreak element bots ("bend" tactics), so edit around them carefully.
    - npc_brain.gd:501-503, npc_body.gd:397
    - factions.json "weapon": "musket" at 37, 82, 129 and 212
    - story_actor.gd
  - **Household:**
    - jobs.json:116-117, tools.json:27-37 and 52-53
    - worker_gear.gd:24-27, 145, 219-221
    - hunt_job.gd:253 (the default becomes "bow")
    - hunt_run.gd:998, 1376-1377
  - **UI and interact:**
    - weapon_state.gd:9-27
    - item_info.gd:219-228, item_icons.gd:25-29, 146, 275-280
    - inventory_state.gd:16-18, 80, 86
    - hotbar.gd:69, how_to.gd:56-58, 195, hud.gd:61, inventory_screen.gd:468
    - weapon_rack.gd:12 LONG
    - player_interactor.gd:1286 (keep the spear barrel)
    - placed_weapon.gd
  - **World and other:**
    - player_torch.gd:578-582, player_grip.gd:53
    - bird_life.gd:22, wildlife_spawner.gd:52 (LOUD)
    - bare_start.gd:34-39, camp_station.gd:76-82, 113
    - gather_tools.gd:75, 455-456, 1782
    - sway_moves.gd:60 and moves.json:20 (pistol)
    - weapon_models.gd:32-33, 253+
    - the weapon_balance.gd gun keys
    - ballistics.json: the gun rows and the "research" key (keep the bow, spear and atlatl rows)
    - trajectory_preview.gd (its range_research mention)
    - weapon.gd:83 (comment)
    - item_text.json and building.json: the gun entries
    - tools/weapons/check_balance.py: the gun rows
    - tools/models/musket.py goes entirely
    - data/survival gun rows: UNDECIDED. Leave them for the Thủy Vân rewrite, since they are only strings once the
      classes are gone.
  - **Prefetch:** data/startup/prefetch.json:131-134 and its flintlock entries. Re-record data/ring/prefetch.json,
    which today lists 75 flintlock files.
- **Rewrite:** the mixed tests in g_tests.txt.
  - tests/anim: test_contract, test_hand_grips, test_carry_layers, test_continuity, test_actions, test_weapon_aim,
    test_aim_pitch, test_tree_build, test_overlay, test_hit_death, test_mode_select, test_rates, test_graph_data,
    test_direction_weights, test_replay, facade_rig, lib/crouch_harness, lib/hand_grip_meter,
    fixtures/mini_metrics.json, test_throw_switch_grip
  - tests/weapons/test_range_ladder.gd, aim_alignment
  - tests/climb/test_hang_aim.gd, test_knockdown.gd
  - tests/torch/test_torch.gd, test_hand_holds.gd
  - tests/interact/test_torch_set.gd
  - tests/inventory/test_inventory_equip.gd, test_equip_wheel.gd
  - tests/ui/test_hotbar.gd, test_tab_drops.gd
  - tests/save/test_save_game.gd
  - tests/smoke_test.gd
  - tests/survival_game/{test_bare, test_gear, test_vices, test_camp_stations}
  - tests/sway/test_sway.gd
  - tests/npc/test_npc_fighter.gd
  - tests/companion/test_hunt.gd, test_tool_pool.gd
  - tests/boats/test_boat_ride.gd is a thuyvan baseline-adjacent file: only with that session.
- **Tests after:**
  - tests/anim/run_all.gd, tests/torch/*, tests/throwables/*
  - tests/weapons/test_bow_hand_arrows.gd and the rewritten range tests
  - tests/climb/*, tests/npc/*, then the full Tidebreak set (tests/ring, bending, sway)
  - tests/companion/*, tests/save/*
  - thuyvan's test_greybox after the merge
  - the owner plays the bow, spear and torch (the plan flags this as an animation-regression risk)

### 2.8 Mammoth. GATED on ASK T2 (thuyvan baseline test_river.gd). Risk: medium. 28 files, 4.1 MB

- **Delete:**
  - scripts/climb/{stand_in_giant, mammoth_temper, mammoth_butchery}.gd
  - scripts/wildlife/limb_carcass.gd
  - assets/wildlife/ice_age/ and assets/wildlife/smooth/mammoth.glb
  - tools/wildlife/mammoth_* (mammoth_clips.py, mammoth_film.gd). Neither provenance doc cites mammoth_clips.py.
  - tests/climb/{mammoth_shots, test_mammoth_butchery, test_mammoth_knee, test_mammoth_pace, test_mammoth_temper,
    test_no_fling}.gd
- **Edits:**
  - climb_yard.gd:22-36 (the giant station)
  - river_water.gd (MammothButchery)
  - music_director.gd: the giant-fight trigger. The cue files stay (O2).
  - player_grip.gd, animal_hair.gd, gather_tools.gd
  - the wildlife_spawner and ecology mammoth counts
  - tools/wildlife/smooth_models.py:34 and animal_hair.py
- **Rewrite:**
  - tests/climb/test_grip.gd
  - tests/wildlife/test_ecology.gd, test_scavengers.gd (LimbCarcass)
  - tests/audio/test_music_director.gd (the giant triggers)
  - tests/world/test_river.gd:43, 245-260: the Thủy Vân session makes this edit.
- **Tests after:** tests/climb/*, tests/wildlife/*, tests/audio/*, and the five thuyvan baselines.

### 2.9 Old DuelMode and NpcSkirmish. GATED on ASK T11 + O12 (the test migration). Risk: high until the tests move. 10 files, 88 KB

- **Prerequisite:** move the 15 harness tests that use DuelMode (incoming, find, COUNTDOWN_S) onto
  ring.tscn/RingMode:
  - tests/bending/{test_bend_cast, test_bend_caster, test_bend_poses, test_bend_throw, test_flow, test_knock}
  - tests/npc/{test_bend_bots, test_duel_bar, test_duel_bender}
  - tests/ring/{test_guard_matrix, test_player_words, test_quick_spell, test_schemes}
  - tests/sway/{test_bending, test_duel_spells}
- **Edits:**
  - main_menu.gd:41-42, 354-366, 385-397 (the duel fallback), 817-819
  - frontier_level.gd:27, 48-49, 209 (UNDECIDED file: edit only, as agreed in T11)
  - bend_poses.gd:258-260, player_interactor.gd:215-216
  - npc_brain.gd:104, 113 (NpcSkirmish), npc_body.gd:45, npc_cover.gd:13 (comment)
  - npc_fighter.gd: the "cover" tactic
  - the comments in kit_words, ring_menu and ring_mode
- **Delete:** scripts/duel/{duel_mode, duel_menu, duel_arena}.gd, tests/npc/test_duel.gd and
  scripts/npc/npc_skirmish.gd.
- **Tests after:** all of tests/ring, tests/bending, tests/sway and tests/npc, then the main menu (the ring row,
  with no Duel (test) row).

**Tier 2 totals**
- **Ungated (2.0-2.5):** 6 steps, about 78.8 MB.
- **Gated (2.6-2.9):** 4 steps, about 24.4 MB, plus 1.9 MB if O4 drops the carry pieces.
- **Prefetch:** the lists must be re-recorded after 2.2, 2.4, 2.6 and 2.7, or the ring prefetches missing files.

---

## TIER 3: repo hygiene

Run `git worktree list` first, and do nothing while Gate R2 or any lane holds godot.lock.

### 3.1 Merged branch refs: `git branch -d` (refuses anything unmerged). 24 refs, 0 MB, risk none

- **After Gate R2 finishes:** tb/R2-CLIPS, tb/R2-CORE, tb/R2-HUD_LESSONS, tb/R2-KITS, worktree-wf_a5f9a2af-ea8-1..4,
  worktree-wf_1890677f-aae-1 and -2. Each is an ancestor of worktree-spellcraft (merge-base --is-ancestor), and its
  worktree is already gone.
- **Any time:** anim-overhaul, claude/frontier-id-schema-audit-e1bf45, land/farming-clothing, main-work,
  part/farming, part/snow, part/yoga-poses, trim/legacy-actor-b-clips, worktree-anim-retime-pipeline,
  worktree-crouch-under and worktree-wf_c7a79ae5-f5c-2/3/5/6. Each is an ancestor of main, spellcraft and thuyvan,
  and none is checked out.

### 3.2 Scratchpad junk (not in git). 0.47 MB, risk very low (recover.py can rebuild from transcripts)

- smash_r3/aerials_v1_prev.md: byte-identical to aerials.md.
- look_a/, look_c/, look_c2/, lookb/, edit_lookdev.py: rejected or merged lookdev.
- The 106 finished-round helpers listed in hygiene.md: r1b/, r1m/, t5/, t7a/, t9/, qa/, cc_broken/, clips3_blocks/,
  the loose assets_*, clips3_*, ctrl_*, g2_*, learn_*, perf_*, play_*, q3_*, scr_*, t1a_*, t1b_*, t2_*, t4_* and
  t6_* files, w3*, r1_peek.py, r1s_*.py, wave_peek.py, journal_peek.py and design_peek.py.
- No live reader names them: tools/loop, docs/tidebreak/r3_task_*.md, gate_r2_batch.sh and run_test*.sh were
  grepped. Keep every gate* and baseline_* file, godot_run.sh, run_test*.sh, blender_run.sh, skills_r2/, smash_r3/,
  critic_r*/, review/, baseline/, logs/, anim*/ and the recover/persist helpers.

### 3.3 Later: 7.7 MB

- The round-2 helpers (hl/, kits/, r2core/, r2cw/, r2kits/, r2m/, r2_done.json, r2_save.py, mk_r2_tasks.py,
  wip_branches.py; 0.32 MB) once Gate R2 is closed.
- This audit's own cleanup/ folder (7.4 MB) once the plan is applied.

### 3.4 IRREVERSIBLE: unmerged branches. Each is lost for good once the reflog expires

Each needs `git branch -D`. Recommendation: archive first with
`git bundle create frontier_rejected.bundle <refs>` and keep the bundle outside the repo.

| Ref | Content | Why it can go |
|---|---|---|
| worktree-arena-8v8 (3f9fdaa) | The 8v8 musket arena: scripts/arena, tests/arena, tools/arena | Its commit message says it was judged not fun (2026-10-04), and firearms are RETIRE. |
| tb/LOOK-A, worktree-wf_3fb435cb-c62-1 (57c3c28), worktree-wf_3fb435cb-c62-5 (59d5ce7) | ToonLook cel shading: scripts/look, shaders/look, stencil_probe | The owner rejected cel shading, and every r3 task says "NO cel shading". |
| worktree-wf_3fb435cb-c62-6 (79c590c) | An unused toon_water_sheet.gdshader draft | LOOK-B is merged as 983e508, and toon_water_sheet appears nowhere. |
| worktree-wf_3fb435cb-c62-7 (9e6c1cf) | The LOOK-C round-1 merge | git cherry finds 0 unique patches. It needs -D only because it is not an ancestor. |

### 3.5 Not removable now (KEEP or ASK)

- **Worktrees:**
  - main checkout: out of scope.
  - spellcraft: live.
  - thuyvan: live.
  - wf_297b9d95-fea-1 (tb/ANIM): the live anim lane, locked by pid 1106.
  - wf_1d34e212-ad4-2/3/4 (tv/LOOK-ROCK, VILLAGE, PAINT): UNCOMMITTED. They hold about 47 MB of untracked
    assets/thuyvan and tools/thuyvan_art that exist nowhere else (ASK T7).
  - Frontier_wt/agls-comparison: UNMERGED, plus 18 untracked .uid files (ASK O13).
- **Branches:** main, worktree-spellcraft, thuyvan, tb/ANIM, worktree-wf_297b9d95-fea-1 and tv/LOOK-*: live.
  tv/LOOK-FONT has 1 commit (a font) that is not in thuyvan. tv/T1-4 and worktree-wf_1d34e212-ad4-2..5 are ASK T8.
  The Codex branches are ASK O13.
- **Stale lock notes:** spellcraft names dead pid 28073, and the look lanes name dead pid 62517. Leave them to their
  owners.

**Tier 3 totals**
- **Branches:** 24 safe ref deletions, plus 6 flagged irreversible.
- **Scratchpad:** 0.47 MB now, plus 7.7 MB later.
- **Tests after:** none. Check `git branch --merged worktree-spellcraft` before and after.

---

## ASK

### For the owner (O)

**O1. Peoples' music** (audio/music/people_*.wav: 35 cues, 70 files, 243.6 MB)
- *Question:* "The 35 real peoples are retired, but their 35 music themes (244 MB) are still in the game. Delete all
  of them, keep only vietnamese/thai/malay for Thủy Vân, or keep them all?"
- *Note:* tools/music/cues/peoples.py and render.py can regenerate them. Edits if yes: music_manifest.gd and the
  people pick in music_director.gd:248.

**O2. Retired-theme music** (loc_fort, loc_wreck, story_wonder, giant_lament, giant_upper_hand: 64.0 MB)
- *Question:* "These cues scored the fort, the wreck, the wonder sky and the mammoth, which are all retired. Delete
  them (tools/music can re-render them), or keep them as your score?"
- *Note:* giant_battle stays either way, because the ring's fight cue uses it.

**O3. Tomahawk and atlatl** (9.0 MB of models plus throwable_tomahawk.gd and throwable_atlatl.gd)
- *Question:* "Thủy Vân keeps only the bow and the throwing spear by name. Do the tomahawk and the atlatl (keys 5-6)
  stay or go?"
- *Note:* scripts/bending/bend_throw.gd names the tomahawk, so that hunk needs checking if they go.

**O4. Bow and spear body carry**
- *Question:* "Retiring the loadout also removes the quiver, the bow cord and the spear-pair tie that show the bow
  and spears on the body. Keep a trimmed carry for the bow and spear, or let them be held only?"
- *Note:* this decides step 2.6.

**O5. Default clothes and hair**
- *Question:* "Every default body and the arena wear colonial shirt_tucked, breeches, sash_worsted, shift_linen,
  petticoat and shirt_linen, middle-eastern salvar_mens and the queue-ribbon hair (6.4 MB). These are period items
  the plan retires. Keep them until new defaults exist, or design the new defaults first?"
- *Note:* Mountain Folk also falls back on three of them.

**O6. Cel-banded bend VFX**
- *Question:* "Does 'no cel shading' also cover ToonFx, the live cel-banded bend effects?"
- *Note:* the default is to keep them. They are the only bend VFX the game has, and the rejected ToonLook never
  reached this branch.

**O7. Water meter**
- *Question:* "The water meter's spending is off and its bar is hidden. Delete the dormant water meter from
  bending.gd, bend_effects, ring_mode, npc_bending, hud.gd and 8 tests, or keep it for later?"

**O8. Melee AI**
- *Question:* "melee_duel_ai.gd and sparring_partner.gd (24 KB) are reached only by tests, trailer.gd and
  climb_film.gd. Keep them for the dao, or delete them?"

**O9. Tandem demos**
- *Question:* "features/tandem has stand-alone demos (demo, crawl_demo, tandem_crawl_pair, tandem_yoga_stack,
  yoga_mannequin; 25 KB) that nothing loads, and tools/check_eye_contact.gd, which cannot run (it loads the deleted
  reverse_plank.gd). Delete them? The in-game tandem stays."

**O10. Unreachable small files inside kept folders**
- *Question:* "Delete these files, which nothing in the game uses?"
  - traversal/markers/trav_beam.gd
  - companion/head_round.gd (test only)
  - survival/survival_runtime.gd (test only, 'not in any scene yet')
  - assets/bison/materials/bison_coat.tres (no load)
  - jog_aim_arm.gd once the pistol is gone

**O11. Provenance records**
- *Question:* "tools/retarget/render_compare.gd cannot run (it loads the missing characters/Actor_A.tscn) but is in
  the retarget toolchain README. author_reload.gd and forage_grab.blend are the recorded generators of your reload
  and forage clips. Keep all three as provenance records?"
- *Note:* the default is to keep them, per CLAUDE.md.

**O12. Duel harness migration**
- *Question:* "OK to move the 15 Tidebreak tests that run in the old DuelMode onto the ring, so that duel/ can be
  retired?"
- *Note:* this is step 2.9's prerequisite.

**O13. Codex work**
- *Question:* "Codex's agls-comparison worktree and branch (7 unique commits, +55.5k lines, unmerged) and
  backup/agls-comparison-before-main: keep or delete?"
- *Question:* "OK to `git branch -d` the Codex branches already merged or patch-equivalent: animation-variants-playtest,
  blender-timing-variants, protected-release, trim-actor-a-animations, and tandem-animations (-D, 0 unique patches)?"

**O14. Fort props**
- *Question:* "stone_fire_pit, wooden_axe and hatchet (2.4 MB) were placed only by the retired fort. Delete them, or
  keep them in the structures kit for reuse?"

**O15. Paintings and research**
- *Question:* "Keep the North American menu paintings (assets/ui/paintings) and docs/research until the menu reskin?"

### For the Thủy Vân session (T)

**T1. Firearms**
- *Question:* "Spellcraft will delete Firearm, Musket, FlintlockPistol, OverUnder* and the FrontierPlayer gun hooks.
  Your player.gd no_firearms/FIREARMS hunks would conflict, and tests/thuyvan/test_greybox.gd:158-164 would break.
  Should spellcraft do the removal, with you dropping no_firearms and rewriting the greybox check, or will you do it
  on thuyvan?"

**T2. Mammoth**
- *Question:* "Your baseline tests/world/test_river.gd:248 runs StandInGiant.new(). Will you edit it (lines 43 and
  245-260) so the mammoth can go?"
- *Note:* RiverWater's MammothButchery hook goes with it.

**T3. Fort and range**
- *Question:* "story_layer.gd:454 and :473 call FortPlan.stake_ground and FortPlan.settle, test_story_layer.gd:352-353
  uses FrontierStructures.FORT_HALF, and frontier_level loads FrontierStructures. Should spellcraft move
  stake_ground and settle into the building engine now and retire the fort, or leave fort and range until your
  cutover?"
- *Note:* this blocks fort_structures, fort_hollow, fort_pieces, fort_plan, palisade_cuts, target_dummy,
  dummy_style, data/building/fort_*, audio/sfx/targets and tools/sfx/targets.py (0.6 MB). PalisadeCuts has 8
  kept-building users, and TargetDummy has 11 test users.

**T4. Two Fires data**
- *Question:* "test_story_layer.gd:139 reads storylines/two_fires.json, and story_layer's DEFAULT_LAYER is 1757. Keep
  data/story/{storylines,missions,dialogue}/two_fires.json, data/story/costumes.json and data/world/layers/1757.json
  until you re-stage those tests?"

**T5. Real peoples' data**
- *Question:* "Mountain Folk takes its faces from assets/character/body/peoples.json and uses people_like
  vietnam/thai/malay. Which keys of peoples.json presets, creator.json (groups, peoples, emblems) and recruit.json
  region_peoples can go now?"

**T6. Period factions**
- *Question:* "Keep or drop the period factions french_marine, canadian_militia, militia, toughs, city_guard and
  sky_crew in data/npc/factions.json?"
- *Note:* ring_team_a and ring_team_b stay.

**T7. Look lanes**
- *Question:* "wf_1d34e212-ad4-2/3/4 hold about 47 MB of untracked assets/thuyvan and tools/thuyvan_art that exist
  nowhere else. Commit them, then remove the worktrees?"

**T8. Merged lane refs**
- *Question:* "OK to `git branch -d` the merged refs tv/T1-T4 and worktree-wf_1d34e212-ad4-2..5?"

**T9. Salakot**
- *Question:* "garments/southeast_asia (filipino_salakot, 0.3 MB) is a real-people set. Retire it, or keep it for
  Thủy Vân?"

**T10. Frontier baselines**
- *Question:* "Keep tools/environment/baselines/colliders_baseline.json, tools/environment/structures/colliders_with_structures.json
  and tests/world/fixtures/fort_heights_before_squares.json until frontier_level is retired?"

**T11. frontier_level edit**
- *Question:* "OK for spellcraft to edit frontier_level.gd:27, 48-49 and 209 (its DuelMode hooks) in step 2.9?"

### Kept by default (no question needed unless the owner wants otherwise)

- scripts/survival/sim/ and survival_almanac.gd: "rewrite, don't delete".
- climb_yard and traversal_course: test fixtures for KEEP features.
- bend_cast.gd: loaded by name from npc_bending.gd.
- ballistics_util.gd and ballistics.json: shared with the bow and spear.
- Throwables, the bow, the sway lock UI and the wheel step modes.
- assets/polyhaven: CC0, KEEP.
- The terrain, vegetation, wildlife and music cues: UNDECIDED.
- The thuyvan baseline tests.
- snow/ and data/survival: UNDECIDED.
- The tattoo designs: tattoos.json says they are the project's own, with no people-specific marks.
