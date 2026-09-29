# tools/anim_graph: Actor_B graph exporter (WP1)

Converts the extracted player animation graph into the tables Frontier's graph-driven
`PlayerAnim` reads at runtime. Offline only; nothing here runs in the game.

**Provenance.** Every generated file keeps numeric asset IDs, the 32-bit symbol IDs (copied, never
re-hashed from names), overlay record offsets and `native_asset_id` / `source_attribution`.

## Usage

```
python3 tools/anim_graph/export_actor_b_graph.py            # regenerate the outputs
python3 tools/anim_graph/export_actor_b_graph.py --check    # rebuild in memory, run the assertions, exit 0 only if the outputs are current
python3 -m unittest discover tests/source_checks            # WP1 tests (test_vendor, test_export)
```

Rebuilds require `--source-root /path/to/source` or `ANIMATION_SOURCE_ROOT`. No source path is assumed.
Other options: `--out`, `--report`, `--fixture`, `--bindings`. Python 3.9, standard library only.
A full build takes about 1 s.

## Files

| Path | What |
|---|---|
| `export_actor_b_graph.py` | the exporter |
| `dump_keyed_bones.gd` | Godot tool: writes `actor_b_keyed_bones.json` (skeleton bones keyed by every actor_b clip) from `animations/Actor_B.res`; `-- check` exits 1 when the committed file is stale |
| `actor_b_keyed_bones.json` | generated exporter input (layer slot check, prop-bone coverage) |
| `frontier_bindings.json` | hand-authored input: role -> graph state/leaf, overlay selections, runtime transition rules, gameplay overrides, tuning |
| `vendor/` | unmodified copies of the graph-analysis tools plus a path shim; see `vendor/PROVENANCE.md` |
| `schema/actor_b_graph.schema.json` | output contract |
| `fixtures/mini_graph.json` | 1 weapon (musket) x 2 modes (run, crouch) subset with the same schema, for runtime unit tests |
| `tests/test_vendor.py`, `tests/test_export.py` | tests |
| `../../animations/actor_b_graph.json` | generated tables (committed) |
| `../../animations/actor_b_graph_report.md` | generated human-readable report (committed) |
| `measure_clips.gd` | WP2 Godot tool: clip metrics (travel speeds, plant phases, loop check, bone masks, aim-pitch calibration, chest height, Blender ground-truth check); see "Clip metrics (WP2)" below |
| `schema/actor_b_clip_metrics.schema.json` | metrics contract (validated by `tests/anim/test_metrics.gd`) |
| `../../animations/actor_b_clip_metrics.json` | generated metrics (committed); fixture `../../tests/anim/fixtures/mini_metrics.json` from `fixtures/mini_graph.json` |

## Inputs (read-only)

`source/player_blending/player_blending.json`, `source/blender_animation_index.csv`,
`source/graph_analysis/graph/{state_subgraph.json, movement_modes_actor_b.json, actor_b_library_dump.json}`,
`frontier_bindings.json`, `actor_b_keyed_bones.json`, and the `relaxed` / `clips` tables of `scripts/weapons/{bow,musket,pistol}.gd`
(only for the report's Frontier comparison; the output records a hash of the parsed tables, not of the files).

## Resolution (verified overlay semantics)

Per weapon profile (bow, musket, pistol) x mode (walk, run, sprint, crouch):

1. Selection: `actor_b-actor_b`; the move set named by the Actor_B mode record `+0x40`
   (walk `0x00000354`, run `0x00000054`, run-sprint `0x00001954`, walk-crouched `0x00001354`);
   `crouch-crouch` when the record's `+0x80` flag is set; the profile's weapon-base, weapon-sub-type
   (musket rifle-no-scope, pistol revolver) and weapon-draw-holster sets.
2. Clip identity: `OverlayDB.resolve_id(leaf_id, sel, loop)` (IDs only) with one loop for every leaf and
   layer target, `frontier_bindings.json` `resolver_policy.loop` = `asc_once` (restart from the
   lowest-priority layer after each hit; the pistol's revolver grip needs the revisit). The engine's loop is
   not in the data; the policy records the graph evidence (under `asc_fix`, repeated ascending passes, the
   crouch bow-draw records crouch-crouch `0x0001ba58` / `0x0001ba6c` and actor_b `0x00003e60` / `0x00003e74`
   are unreachable from every state leaf and layer target; `test_resolver_policy_evidence` checks it).
   Every leaf is also resolved with the other loop; they disagree on exactly three leaves (bow crouch nock
   and its twin, musket crouch weapon-out fingers), which are marked `resolution: "ambiguous"` with the
   other result in `resolver_alternatives` and listed in `meta.resolver_disagreements`. A
   `resolver_choices` entry may use the other loop for one leaf only with `basis: "frontier_requirement"`
   (a Frontier behaviour to keep, not a claim about the game); the one entry keeps the musket in its grip
   in crouch (user requirement 2: the graph result disables the musket's weapon-out fingers there, and the
   rifle grip sits 4.2 cm / 36 deg from the prop bone's rest pose). `meta.resolver_exceptions` lists it with
   the graph result and the roles it holds up; `enabled: false` exports the graph result and exempts those
   roles from (g).
3. Clip-keyed layer records (byte0 bit0) on the source, every intermediate and the final ID;
   state-keyed records (byte1 & 0x02) chosen by flag on the state's name ID. `00 02` state records are
   state-level substitutions; the build fails if one applies to an exported state.
4. Targets `null`, `null-add`, `null-add-base`, `bindpose-anim` are dropped (listed as `null_layers`).
   Layers are deduplicated by target (maximum weight, every source kept). `kind` comes from the
   library's `additive_source`; `slot` from name, additive flag and bone count, then checked against the
   clip's real keyed bones from `actor_b_keyed_bones.json`: `hands` must key only palm/finger/prop bones,
   `arms`/`other_partial` must key more than hand bones, `full_body` must key leg bones (the build fails
   otherwise); `arms` clips that also key other bones are listed in `meta.slot_notes`
   (`actor_b-p-crouch-hr-fw--rifle` also keys neck and head). Each layer records `keyed_bone_count` and
   `prop_bones_keyed`.
5. Weights: the `raw_0x0c` lambda evaluated with the vendored `symvm`; constants, or a 17-sample phase
   curve (`make-curve 4` = smoothstep, inferred); no lambda = 1.0 (inferred); 9.0 would be clamped.
6. Godot names: every `original_name` / `source_names` alias of the index and library; ties pick
   `action_name == original_name`, else the lexicographically smallest, with a warning.

## What the output contains

- `roles["<w>/<m>/<role>"]`: idle, the six move directions, **start** (`start_*`, idle^run-fwd/bkwd),
  **stop** (`stop_*`, run-fw^idle / run-bk^idle), **reversal** (`rev_*`, with the `-begin` shim state),
  **idle turns** (`turn_l/r`, `turn_*_180`, `quick_turn_180`), takeoff, jump, pre-fall, fall, every
  **landing** the graph authors for the player's fall and long jump (soft / medium / hard fall landings in
  idle, run and backward-run (`*_run_bw`, exit into run-bkwd) versions, the jump landings and their `-med` /
  `-run-hard` siblings, the damage and death landings), hit and death. Each role has the state, leaf ID, full overlay chain and carry layers.
- `aim_trees`, `aim_move` (the graph's aim-run states), `hand_states` (weapon-out fingers), `grips`.
- `weapon_layers`: the layer order the runtime applies (role clip, role layers, weapon partial slot,
  weapon additive slot, runtime additives) and the weapon-out finger state `idle-pistol-out-part`
  (`options.weapon_out_fingers`, default on): a code-entered looping partial at weight 1 over every
  lower-body role while a weapon is out (trigger and weight INFERRED), for the weapons whose weapon-base set
  remaps its leaf `1p-idle-fingers` (musket, pistol; `weapon_out.clips[*].applies`). The bow has no such
  record, and its generic fallback clip would hide the bow's own `bow-hands` layers, so it is not applied
  (`weapon_layers.weapon_out.force` can change that after WP5's screenshots). It is the graph's only source
  of the pistol's `r_hand_prop_attachment` on locomotion.
- `roles.*.prop` (and `runtime_roles.hit_full/death.*.prop`): the clips that drive the weapon's prop bone
  (`weapon_layers.prop_bones`) under the default options. The build fails unless one has full weight
  (`frontier_bindings.json` `prop_exempt` lists the reasoned exceptions: direct hit roles, bow death and
  the bow's death landing).
- `roles.*/hit_full` and `hit_add` are `direct`: their `clip` is null and `use_runtime_roles` points at
  `runtime_roles` (the graph leaf's placeholder resolution is kept only under `graph_leaf`).
- `actions["<w>/<stance>/<key>"]`: grab, **equip (draw)**, **holster** (draw clip backwards, start phase 1.0),
  holster_finish, nock, reload begin/mid/end, each with its `-add` twin state.
- `carry_overrides` (THROW2): Frontier-composed carries from `frontier_bindings.json` `carry_overrides` (see
  its `about`). A row replaces the weapon-base layers of its `replace` slots on the roles of its `modes`
  (except `roles_except`; when given, only `roles_only`, THROW2 review: the spear's sprint idle keeps the
  javelin carry while the sprint's moving roles keep the graph's own arm) with another graph profile's
  weapon-base layers (`from_profile`; a target without an Actor_B action takes the row's `substitute`,
  status `substitute` with a `reason`) and then `poses`: an
  Actor_B clip sampled at `sample_s` on a bone mask (`bones`), status `frontier`, with
  `frontier.{pose, source_state, native_asset_id, why}`. Each role lists the rows that replaced its layers
  in `carry_override`; a grip whose carry is a pose gets `carry_sample_s` / `carry_bones`. TreeBuilder
  bakes each pose once into the `frontier_bank` library (`frontier_bank/p__<clip>__<ms>__<mask hash>`,
  keeping the source clip's `native_asset_id` and attribution). The build fails when a pose's clip does
  not key a masked bone or a hands pose masks a bone outside the hand. Used by the spear (overhand
  javelin carry) and the tomahawk (hatchet carry, knife grip).
- `action_overrides` (THROW2): action rows whose clips Frontier substitutes (status `frontier_substitute`):
  the graph state, its records and callbacks stay; the substitute clips are graph names resolved through
  the actor_b overlay with their records as evidence (`substitute`), and the replaced clips are kept in
  `replaced`. Used by the tomahawk's draw, holster and grab (the thrown-object draw from the back of the
  belt, `molotov-pack-draw^idle`).
- `crouch_change`: the graph's crouch-change additive (resolves per weapon) plus the full-body
  crouch-change state, whose resolved clip is missing for Actor_B and plays the Actor_B `--base` pair
  (status `substitute`; `options.crouch_change_full_body`, default on, so a crouch toggle follows the
  graph's first-match record into that state).
- `runtime_clips` / `runtime_roles`: fire, hit, death and charge clips supplied by gameplay code,
  with the layer records keyed on each clip.
- `transitions[key]`: every runtime rule (`when`) with its graph record(s) (`graph` = the primary record,
  `graph_variants` = all, e.g. the fw/bw, per-landing or use_transition_anims branches). Row-level `use` is
  the **graph-faithful default of the primary record only** (`use_basis` says which); each variant carries
  its own `use` (fade, `gate_phase` from a phase condition, `gate_frames`/`gate_s` only from a frames
  condition) and the runtime must read the variant of the state it is in. A first condition above 1 is read
  as frames whatever its lambda flags word says (graph_understanding correction 9; the other reading is kept
  as `gate_alternative`), so the fall idle landings' crouch toggle gates on 10 frames like their move exits;
  `overrides` lists the opt-in gameplay alternatives, each with its `flag` and plan `rule` label (G1 no start/stop, G2 0.3 s hemisphere fade,
  G5 no idle turns, G6 immediate landing exit, 0.3 s aim-to-move, crouch crossfade, pre-fall fade,
  exact hands grip). All `gameplay_overrides` default to false.
- `graph_states`: every exported state with its decoded tree (blend weights, phase lambdas) and every
  transition record in source order (first match wins), for exact runtime evaluation.
- `landing` (proposed; the game code picks landings): impact bands (soft < 6.0 m/s <= medium < 8.0 m/s <=
  hard), direction at touchdown (idle, run, backward run), the role for every kind x band x direction, the
  fallback for the missing `land_jump_run_hard` clip, the roles never selected (damage, death: Frontier has
  no fall damage) and the graph landing states not exported, each with a reason. The build fails if a
  landing role or graph landing state is unaccounted for.
- `thresholds`, `gates`, `options`, `tuning`, `frontier` (Weapon.relaxed / Weapon.clips vs graph).

## Structural assertions (the build fails otherwise)

(a) the six move-direction leaves of a (weapon, mode) bank carry the same layers (start/stop/reversal
banks are reported when they differ); (b) idle layers are identical for walk/run/sprint; (c) a role's
additive kind never changes across selections; (d) every clip exists in the library dump; (e) every
transition record the runtime uses exists; (f) only `allowed_missing` roles may be missing; (g) every
lower-body role and runtime hit/death role has a full-weight driver of the weapon's prop bone under the
default options unless `prop_exempt` says why not; plus the keyed-bone slot checks, no `00 02` state
substitution on an exported state, no graph-labelled row without a record, a named gate must match the
primary record's frames condition, every `resolver_choices` entry must match a real disagreement and
declare a frontier requirement when it leaves the policy loop, every landing role and graph landing state is
selected, never-selected or not-exported with a reason, and a graph row may not restate a value that differs
from its record.

## Keyed bones

`actor_b_keyed_bones.json` is generated from the Godot library and committed:

```
Godot --headless --path . -s tools/anim_graph/dump_keyed_bones.gd              # regenerate
Godot --headless --path . -s tools/anim_graph/dump_keyed_bones.gd -- check     # exit 1 if stale
```

A rig that fails to load, or lacks `Skeleton3D`, `AnimationPlayer` or the `actor_b` library, prints
`KEYED BONES FAILED: ...` and exits 1 rather than leaving Godot running (`-- rig=<res path>` tests that).

Rerun it (then the exporter) when `animations/Actor_B.res` gains or changes clips. A rig resync that only
restamps skeleton metadata does not make it stale (`check` compares bones and masks, not the file hash).

## Clip metrics (WP2)

This section is maintained by WP2 (`measure_clips.gd`); please keep it when editing this README.

`measure_clips.gd` measures every clip `animations/actor_b_graph.json` references (a built-in list when the
graph file is absent) on the rig with `BindRest.ensure()` applied, and writes
`animations/actor_b_clip_metrics.json` (plan section 5.4; contract `schema/actor_b_clip_metrics.schema.json`).
It takes about 2 s and the output is byte-identical across runs.

```
Godot --headless --path . -s tools/anim_graph/measure_clips.gd                 # regenerate
Godot --headless --path . -s tools/anim_graph/measure_clips.gd -- check        # exit 1 if stale
Godot --headless --path . -s tools/anim_graph/measure_clips.gd -- graph=res://tools/anim_graph/fixtures/mini_graph.json \
      out=res://tests/anim/fixtures/mini_metrics.json fixture=1                # the day-1 fixture
Godot --headless --path . -s tests/anim/run_all.gd -- --no-capture --only=test_metrics
```

Rerun it after the exporter (or a rig resync) changes `actor_b_graph.json` or `Actor_B.res`; `test_metrics`
and `check` report "stale" otherwise. A rig restamp or Godot patch release that leaves every measured value
unchanged is not stale (`meta.rig_sha256` / `meta.godot_version` are ignored by the comparison; rerun to
restamp). `source_root=<dir>` points at external animation source (default as for the exporter, or
`$ANIMATION_SOURCE_ROOT`); only its Blender foot dump `graph_analysis/graph/vmm/bl/dump3.jsonl` is read. Without the
dump the tool warns and writes `gt_check` as skipped, and `check` / `test_metrics` compare everything except
the gt-derived fields (`gt_check`, `clips.*.blender`, `clips.*.fidelity_warning`) and say the dump is
missing instead of "stale".

- `cyclic`: whether a clip loops comes from the graph export: the `loop` flag of every entry that plays it
  (any object with a string `clip` and a boolean `loop`; looped if any is), `travel.cyclic_source:
  graph_loop`. Only clips no entry plays (and the built-in list) fall back to the feet seam test
  (`feet_seam`). `travel.seam_m` keeps the heel/ball seam mismatch: the looped rifle `aim-walk-bw-rt` clips
  pop 3.7 cm there but are cyclic like every other bank clip; the quick-turn and hit clips, whose feet
  happen to meet, are one-shots. `loop` / `loop_err` stay the measured core-bone seam.

- `travel`: GA/vmm/bl/an.py method A at the clip's own sample rate (runs of at least 3 samples, as an.py). It
  reproduces the plan's corrected speeds (walk-fw 1.263, run-fw 3.343, run-bw 2.474, sprint-fw 4.244,
  crouch-walk-fw 1.637; aim-walk 0.544-0.546). One documented fallback fills `speed` / `heading_deg` when
  there is no such run (`estimator`, `quality: fallback`): runs of at least 2 samples at the clip's rate
  (`method_a_run2`; the sprint strafes sprint-fw-rt 3.782 m/s -87.0 deg and sprint-bw-rt 4.313 m/s -91.0 deg,
  which the Blender dump reproduces with the same estimator), else 2x / 4x the rate. `kind: cyclic` speeds
  are playback-rate references; `kind: one_shot_mean` (starts, stops, reversals, landings) is only a mean
  over their stances. `travel.contact` is a secondary, informational estimate.
- `body_profile`: non-cyclic clips only; time-resolved body travel at the clip's sample times (cumulative
  `fwd` / `side` displacement from t = 0, `speed` per sample, `coverage`). WP10's reference for start / stop /
  reversal clips. It is the contact path, not an.py method B: per step every heel/ball point near its
  lowest height is a contact candidate whose displacement implies a body velocity; paths through the
  candidates are weighted by height, vertical speed, steps without a candidate and the body acceleration
  they imply, and each step takes its posterior-mean velocity (`meta.method.body_profile`). Method B took
  the lowest point per step, so a swing foot skimming the ground or a heel still descending at touchdown
  was integrated as body travel (42 of the 66 WP10 clips had a step of more than 2 cm, up to 34 cm, against
  their travel direction). The contact path has none over 1.2 cm, starts end near their bank speed (median
  1.0x) and stops come to rest. A few peaks pass 1.3x the bank speed where the Blender dump's own profile
  does too (idle^run-bw-rt 3.45 m/s against run-bw-rt 2.45). `walk-fw-lt^idle` does not stop (the source
  clip).
- `fidelity_warning`: null, or why a dumped clip's library values are not the authored ones: travel speed
  more than 5 % or heading more than 10 deg off the dump, a heel/ball sample more than 20 mm off
  (`blender.gt_max_mm` at `gt_max_t`), or `body_profile` more than 5 cm off the same estimator run on the
  dump (`blender.profile_diff_m`). Nine clips are flagged, among them the WP10 clips `idle^run-bw` (travel
  0.455 m/s against the dump's 1.304) and `quickstop^run-bw`: the key-reduced `Actor_B.res` drops a key
  there. WP4 / WP10 should not treat flagged values as authored until the library is re-exported without
  key reduction (the WP0 / godot_export owner).
- `plant`: plant-onset phases per foot at 60 Hz. Contact = heel or ball within 5 cm of its lowest height
  and moving over the ground (skeleton velocity + body velocity) slower than max(0.3 m/s, 25 % of the body
  speed). Every locomotion and aim-walk bank clip gets alternating left/right onsets, one pair per gait cycle
  (walk/run 1, sprint 2, crouch-walk 3). One-shot clips get onsets too (best effort, local body velocity).
  `l_contact` / `r_contact` list every contact interval, including a stance already planted at t = 0.
- `pitch.<w>/<stance>`: the runtime's aim composition (base, Add2 up, Add2 down, H filtered to
  `bone_sets.hands`) evaluated in an AnimationTree. `solve_up` / `solve_down` is the range the runtime
  inverts over: the authored additives' full monotonic range (today's aim range; `data_limits` names a side
  where the data stops inside +-60 deg, e.g. bow/crouch down at -55.9 deg). `max_valid_*` (the plan's
  yaw-drift rule) is kept for reference; the drift inside the solve range is in `yaw_deg` and
  `solve_lateral_drift_deg` (up to 9.5 deg) for the AimStabilizer.
- `gt_check`: Godot heel/ball positions vs the Blender dump for every dumped clip (137): median 0.005 mm,
  p95 1.06 mm. The outliers (p99 9.7 mm, max 125 mm at one sample of `idle^run-bw` / `quickstop^run-bw`)
  are samples where the library interpolates across a dropped key (the tracks sit on a key-reduced 30 Hz
  grid); `clips.<name>.blender.gt_max_mm` lists every dumped clip's worst sample.

`meta` records the sha256 of the library, rig, graph and dump.
