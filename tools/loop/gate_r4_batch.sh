#!/bin/zsh
# Gate R4 (round 4: IMPACT, READ, LOOKS, HUD, SHOW, VIRAL, SIMPLE, BOTS2 merged on worktree-spellcraft; ONLY=r4 runs
# round 4's own rows) then, as gate R3,: round 3's own rows first (ONLY=r3: PERCENT, MOVE, AIR,
# BOTS, the seams, the stock play-check and the classic pins), then every row of the cleanup gate (gate_clean_batch.sh:
# ring, bending, sway, npc, hud/ui, perf, smoke, the play-check per element and scheme, the Thuy Van baselines,
# tests/customizer, tests/story, tests/env). Logs: logs/gate_r4_<name>.log. Compare with gate_r2.tsv and the cleanup gate
# (logs/gate_clean_*). Prints "DONE <name> <EXIT> | <result> | SE <n>".
S=${TB_SCRATCH:-${TMPDIR:-/tmp}/tidebreak-scratch}
W=/Users/kiwimango/Downloads/Frontier/.claude/worktrees/spellcraft
R="${0:A:h}/run_test_fps.sh"      # (the sibling in tools/loop, not a copy in some session's scratchpad)
export TB_SCRATCH="$S" GODOT_TIMEOUT=420
mkdir -p "$S/logs"

one() {
  local fps="$1"; local name="gate_r4_$2"; shift 2
  FPS="$fps" zsh "$R" "$W" "$name" "$@" > "$S/logs/$name.summary" 2>&1
  local ex=$(grep -m1 '^EXIT' "$S/logs/$name.summary")
  local res=$(grep -E "PASSED|FAILED|TEST OK|TESTS OK" "$S/logs/$name.log" | tail -1)
  local se=$(grep -c 'SCRIPT ERROR' "$S/logs/$name.log")
  echo "DONE $name $ex | $res | SE $se"
}

if [[ -z "$ONLY" || "$ONLY" == "r4" ]]; then
# round 4: IMPACT
one 60  r4_bend_clock    tests/bending/test_bend_clock.gd
one 60  r4_ring_feel     tests/ring/test_ring_feel.gd mode=ring element=earth foe=water
one none r4_mammoth_knee  tests/climb/test_mammoth_knee.gd --no-capture
one none r4_mammoth_temper tests/climb/test_mammoth_temper.gd --no-capture
one 60  r4_soak_ee_ts1   tests/ring/test_ring_soak.gd mode=ring element=earth foe=earth rules=stock seed=7300 ts=1
one 60  r4_soak_ee_ts4   tests/ring/test_ring_soak.gd mode=ring element=earth foe=earth rules=stock seed=7300 ts=4
# READ
one 60  r4_ring_read     tests/ring/test_ring_read.gd
one 60  r4_ring_camera   tests/ring/test_ring_camera.gd
# LOOKS
one 60  r4_looks         tests/bending/test_r4_looks.gd
# HUD
one 60  r4_hud           tests/ring/test_r4_hud.gd
one 60  r4_sides         tests/ring/test_ring_sides.gd
# SHOW
one 60  r4_music         tests/ring/test_ring_music.gd mode=ring element=earth foe=water
one 60  r4_crowd         tests/ring/test_ring_crowd.gd
one none r4_music_director tests/audio/test_music_director.gd
# VIRAL
one 60  r4_replay        tests/ring/test_ring_replay.gd mode=ring element=earth foe=water
one 60  r4_highlights    tests/ring/test_ring_highlights.gd mode=ring element=earth foe=water
one 60  r4_clash         tests/bending/test_bend_clash.gd mode=ring element=earth foe=water
one 60  r4_photo         tests/ring/test_photo_mode.gd mode=ring element=earth foe=water
# SIMPLE
one 60  r4_assist        tests/ring/test_ring_assist.gd
one 60  r4_basic_scheme  tests/ring/test_basic_scheme.gd
# BOTS2
one 60  r4_bots_pct      tests/npc/test_bots_pct.gd
# the merged build's play-check from the menu, every element (Basic, three falls with the splash and the Splash Cam, the
# slow beat, the highlight cards, Full, the Basics lessons)
one 60  r4_pc_earth      tests/ring/test_r4_playcheck.gd pc_el=earth
one 60  r4_pc_water      tests/ring/test_r4_playcheck.gd pc_el=water
one 60  r4_pc_fire       tests/ring/test_r4_playcheck.gd pc_el=fire
one 60  r4_pc_air        tests/ring/test_r4_playcheck.gd pc_el=air
# SIMPLE's first five minutes in parts (each under the runner's timeout), then its gate
GODOT_TIMEOUT=900 one 60 r4_first_five_p1 tests/ring/test_first_five.gd part=1
GODOT_TIMEOUT=900 one 60 r4_first_five_p2 tests/ring/test_first_five.gd part=2
GODOT_TIMEOUT=900 one 60 r4_first_five_p3 tests/ring/test_first_five.gd part=3
GODOT_TIMEOUT=900 one 60 r4_first_five_p4 tests/ring/test_first_five.gd part=4
GODOT_TIMEOUT=900 one 60 r4_first_five    tests/ring/test_first_five.gd part=sum
# the climb test whose camera read the merge changed
one none r4_tree_climb   tests/climb/test_tree_climb.gd --no-capture
fi

if [[ -z "$ONLY" || "$ONLY" == "r3" ]]; then
# round 3: the seams
one 60  r3_seams        tests/ring/test_r3_seams.gd
# PERCENT
one 60  r3_ring_pct     tests/ring/test_ring_pct.gd mode=ring element=earth foe=water
one 60  r3_hitstun      tests/ring/test_ring_hitstun.gd mode=ring element=earth foe=water
one 60  r3_stage        tests/ring/test_ring_stage.gd mode=ring element=earth foe=water
one 60  r3_percent_hud  tests/ring/test_percent_hud.gd mode=ring element=earth foe=water
one 60  r3_rules_stock  tests/ring/test_ring_rules.gd mode=ring element=earth foe=earth
one 60  r3_match_stock  tests/ring/test_ring_match.gd mode=ring element=earth foe=earth round_s=60
one 60  r3_match_classic tests/ring/test_ring_match.gd mode=ring element=water foe=fire round_s=60 to_win=2 rules=classic
# MOVE
one 60  r3_moves        tests/ring/test_ring_moves.gd
one 60  r3_edge         tests/ring/test_ring_edge.gd
one 60  r3_predict      tests/ring/test_ring_predict.gd
one 60  r3_player_gate  tests/player/test_player_gate.gd
# AIR
one 60  r3_air          tests/bending/test_r3_air.gd
one 60  r3_combo        tests/bending/test_r3_combo.gd
one 60  r3_combo_real   tests/bending/test_r3_combo.gd real=on
one 60  r3_guard        tests/bending/test_r3_guard.gd
# BOTS (the stand-ins' rows, then the merged game's)
one 60  r3_bot_pct      tests/npc/test_bot_pct.gd
one 60  r3_bot_recovery tests/npc/test_bot_recovery.gd
one 60  r3_bot_recovery_real tests/npc/test_bot_recovery.gd mover=real
one 60  r3_practice_stock tests/ring/test_practice.gd practice=throw element=earth foe=earth
one 60  r3_soak_stock_ew tests/ring/test_ring_soak.gd mode=ring element=earth foe=water rules=stock ts=1
one 60  r3_soak_stock_fa tests/ring/test_ring_soak.gd mode=ring element=fire foe=air rules=stock ts=1
# the stock play-check from the menu, every element, and Practice with the % rows
one 60  r3_pc_earth     tests/ring/test_playcheck.gd pc_el=earth pc_scheme=keys
one 60  r3_pc_water     tests/ring/test_playcheck.gd pc_el=water pc_scheme=keys
one 60  r3_pc_fire      tests/ring/test_playcheck.gd pc_el=fire pc_scheme=keys
one 60  r3_pc_air       tests/ring/test_playcheck.gd pc_el=air pc_scheme=keys
one 60  r3_pc_practice  tests/ring/test_playcheck.gd pc_practice=throw pc_el=earth pc_foe=earth
fi

if [[ -z "$ONLY" || "$ONLY" == "r2" ]]; then
# round 2's new tests
one 60  r2_cast        tests/bending/test_r2_cast.gd
one 60  r2_guards      tests/bending/test_r2_guards.gd
one 60  kits           tests/ring/test_kits.gd
one 60  guard_matrix   tests/ring/test_guard_matrix.gd mode=duel
one 60  pg_earth       tests/ring/test_practice_guards.gd practice=throw element=earth foe=earth
one 60  pg_water       tests/ring/test_practice_guards.gd practice=throw element=water foe=water
one 60  pg_fire        tests/ring/test_practice_guards.gd practice=throw element=fire foe=fire
one 60  pg_air         tests/ring/test_practice_guards.gd practice=throw element=air foe=air
fi

if [[ -z "$ONLY" || "$ONLY" == "new" ]]; then
# round 1's new tests (gate R1's)
one 60  ring_hitches     tests/perf/test_ring_hitches.gd
one 60  balance          tests/ring/test_balance.gd
one 60  bend_sounds      tests/bending/test_bend_sounds.gd
one 60  lessons          tests/ring/test_lessons.gd
one 60  soak_ee_s7300    tests/ring/test_ring_soak.gd mode=ring element=earth foe=earth seed=7300
one 60  flow_r1a         tests/bending/test_flow.gd mode=duel
one 60  flow_r1b         tests/bending/test_flow.gd mode=duel
one 60  flow_r1c         tests/bending/test_flow.gd mode=duel
fi

if [[ -z "$ONLY" || "$ONLY" == "gate3" ]]; then
# gate 3's wave-3 rows
one 60  schemes        tests/ring/test_schemes.gd
one 60  schemes_duel   tests/ring/test_schemes.gd mode=duel
one 60  bend_throw     tests/bending/test_bend_throw.gd mode=duel
one 60  soak_ee        tests/ring/test_ring_soak.gd mode=ring element=earth foe=earth
one 60  soak_wf        tests/ring/test_ring_soak.gd mode=ring element=water foe=fire
one 60  soak_ae        tests/ring/test_ring_soak.gd mode=ring element=air foe=earth
one 60  ring_screens   tests/ring/test_ring_screens.gd
one 60  practice       tests/ring/test_practice.gd practice=throw element=earth foe=earth
one 60  ring_teams     tests/ring/test_ring_teams.gd mode=ring element=earth foe=fire
one 60  ring_assets    tests/ring/test_ring_assets.gd
one 60  quick_ring     tests/ring/test_quick_spell.gd
one 60  quick_duel     tests/ring/test_quick_spell.gd mode=duel
one 60  ring_look      tests/ring/test_ring_look.gd
one 60  ring_dress     tests/ring/test_ring_dress.gd mode=ring element=earth foe=water light=golden
# wave 2 and before
one 60  bend_cast     tests/bending/test_bend_cast.gd mode=duel
one 60  flow          tests/bending/test_flow.gd mode=duel
one 60  bend_bots     tests/npc/test_bend_bots.gd mode=duel
one 60  ring_rules    tests/ring/test_ring_rules.gd mode=ring element=earth foe=earth
one 60  ring_hud      tests/ring/test_ring_hud.gd
one 60  ring_hud_s7   tests/ring/test_ring_hud.gd seed=7
one 60  match_earth   tests/ring/test_ring_match.gd mode=ring element=air foe=earth round_s=60 to_win=2
one 60  match_water   tests/ring/test_ring_match.gd mode=ring element=earth foe=water round_s=60 to_win=2
one 60  match_fire    tests/ring/test_ring_match.gd mode=ring element=water foe=fire round_s=60 to_win=2
one 60  match_air     tests/ring/test_ring_match.gd mode=ring element=fire foe=air round_s=60 to_win=2
one 60  match_ee      tests/ring/test_ring_match.gd mode=ring element=earth foe=earth round_s=60 to_win=2
one 60  bend_caster   tests/bending/test_bend_caster.gd mode=duel
one 60  knock         tests/bending/test_knock.gd mode=duel
one 60  ring          tests/ring/test_ring.gd baseline=$S/baseline
one 60  bend_poses    tests/bending/test_bend_poses.gd mode=duel
one 60  bend_clips    tests/bending/test_bend_clips.gd
one 60  match_setup   tests/ring/test_match_setup.gd mode=ring element=air foe=earth difficulty=hard
one 60  player_words  tests/ring/test_player_words.gd
# baseline rows (bending, sway, duel, npc, hud, ui, perf; the smoke test)
one 60  bending       tests/sway/test_bending.gd mode=duel
one 60  duel_spells   tests/sway/test_duel_spells.gd mode=duel
one 60  duel_bar      tests/npc/test_duel_bar.gd mode=duel
one 60  duel_bender   tests/npc/test_duel_bender.gd mode=duel
one 60  duel          tests/npc/test_duel.gd mode=duel
one 60  form          tests/sway/test_form.gd survival=on
one 60  sway          tests/sway/test_sway.gd survival=on
one 60  free_use      tests/sway/test_free_use.gd survival=on
one 60  wall_matter   tests/sway/test_wall_matter.gd survival=on save=on
one 60  spike_faces   tests/sway/test_spike_faces.gd
one 60  smoke         tests/smoke_test.gd --no-capture
one 60  hotbar        tests/ui/test_hotbar.gd survival=on
one 60  tab_drops     tests/ui/test_tab_drops.gd survival=on
one 60  hud_skills    tests/ui/test_hud_skills.gd
one 60  hud_vitals    tests/ui/test_hud_vitals.gd survival=on survival_seed=7
one 60  main_menu     tests/ui/test_main_menu.gd
one 120 how_to        tests/ui/test_how_to.gd
one 60  menu_background tests/ui/test_menu_background.gd survival=on
one 60  startup       tests/perf/test_startup.gd
one 60  npc_fighter   tests/npc/test_npc_fighter.gd survival=on
one none main_menu_nofps  tests/ui/test_main_menu.gd
one none hud_vitals_nofps tests/ui/test_hud_vitals.gd survival=on survival_seed=7
one none hud_skills_nofps tests/ui/test_hud_skills.gd
fi

if [[ -z "$ONLY" || "$ONLY" == "pc" ]]; then
# the play-check from the menu: every element under the default scheme, Practice
one 60  pc_earth_keys     tests/ring/test_playcheck.gd pc_el=earth pc_scheme=keys
one 60  pc_water_keys     tests/ring/test_playcheck.gd pc_el=water pc_scheme=keys
one 60  pc_fire_keys      tests/ring/test_playcheck.gd pc_el=fire pc_scheme=keys
one 60  pc_air_keys       tests/ring/test_playcheck.gd pc_el=air pc_scheme=keys
one 60  pc_practice_throw tests/ring/test_playcheck.gd pc_practice=throw pc_el=earth pc_foe=earth
one 60  pc_fire_first     tests/ring/test_playcheck.gd pc_el=fire pc_scheme=first_moves
one 60  pc_water_direction tests/ring/test_playcheck.gd pc_el=water pc_scheme=direction
one 60  pc_air_radial     tests/ring/test_playcheck.gd pc_el=air pc_scheme=radial
one 60  pc_practice_fire  tests/ring/test_playcheck.gd pc_practice=throw pc_el=fire pc_foe=fire
fi

if [[ -z "$ONLY" || "$ONLY" == "clean" ]]; then
# the cleanup's own rows: the five Thuy Van baselines, tests/customizer, tests/story, tests/env (args as cleanup/apply's specs)
one 60   tv_river        tests/world/test_river.gd
one 60   tv_story_layer  tests/world/test_story_layer.gd survival=on
one 60   tv_fish         tests/wildlife/test_fish.gd
one none tv_boat         tests/boats/test_boat.gd
one 60   tv_fishing      tests/fishing/test_fishing.gd survival=on survival_seed=7
one none cz_clothing           tests/customizer/test_clothing.gd
one none cz_creator            tests/customizer/test_creator.gd
one none cz_creator_integration tests/customizer/test_creator_integration.gd
one none cz_customizer_ui      tests/customizer/test_customizer_ui.gd
one none cz_faces              tests/customizer/test_faces.gd
one none cz_head_v3            tests/customizer/test_head_v3.gd
one none cz_jewellery          tests/customizer/test_jewellery.gd
one none cz_new_garments       tests/customizer/test_new_garments.gd
one none cz_new_peoples        tests/customizer/test_new_peoples.gd
one none cz_sea_peoples        tests/customizer/test_sea_peoples.gd
one none cz_slots_patterns     tests/customizer/test_slots_patterns.gd
one none cz_tattoos            tests/customizer/test_tattoos.gd
one 60   st_captivity    tests/story/test_captivity.gd survival=on save=on
one 60   st_dialogue     tests/story/test_dialogue.gd survival=on
one 60   st_mission_flow tests/story/test_mission_flow.gd survival=on
one 60   st_story        tests/story/test_story.gd survival=on story=two_fires
one none env_sun_moon     tests/env/test_sun_moon.gd
one none env_forest_light tests/env/test_forest_light.gd
one none env_weather      tests/env/test_weather.gd
fi
echo "GATE R4 BATCH FINISHED"
