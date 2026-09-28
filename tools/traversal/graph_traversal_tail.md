## 12. Integration hooks implied by the graph

This extract only creates files: `tools/traversal/`, `data/traversal/` and this document. The rebuilt animation system (plan `graph_analysis/design/plan.md`, runtime `scripts/player/anim/`) will need the following changes to play the traversal states as full-body lower inputs with the graph's fades. The transition records in `data/traversal/graph_traversal.json` come from the same decoder as `animations/actor_b_graph.json` `graph_states`: same fields, same `use` block, same condition layout. So `LocoBrain._eval_records` can evaluate them unchanged once the states are known.

1. **`scripts/player/anim/anim_graph_data.gd` (AnimGraphData).**
   - Load `data/traversal/graph_traversal.json`, or a trimmed runtime table built from it by `tools/traversal`.
   - Merge its `states[*]` into the lookup that `LocoBrain._eval_records` reads (`graph.graph_states[gs].transitions`).
   - Expose its `clips` through `clip_info` / `clip_length` / `godot_anim`.
2. **`scripts/player/anim/tree_builder.gd` + `tree_index.gd` (TreeBuilder / TreeIndex).**
   - Build one lower input per traversal state content. The content is the clip for the current weapon × mode from `leaves[].resolutions[]`, plus that group's arm-part layers (`layers[]`, slot `arms`, weight 1.0).
   - Build the ladder inputs from the `overlay_variants` whose `set` is `anim-overlay-player-ledge-ladder`.
   - Build mirrored inputs for states with `mirrored: true`, or `"runtime: ..."` when the side flag is set.
   - Map every traversal graph state to its input so that `LocoBrain._resolve(gs)` finds it.
   - For the states whose phase the graph sets directly (`*-mid-jump`: air progress; `vault`: 1.0), the input needs a TimeSeek-driven timeline instead of free play.
3. **`scripts/player/anim/loco_brain.gd` (LocoBrain).**
   - (a) Add an entry point for code-started traversal states, for example `enter_traversal(gs, fade, entry_phase, info)`, on top of `_enter_gs`, plus a TRAVERSE state tag. While traversing, the locomotion code rules (takeoff, fall, land, hit entries) are suspended unless the controller cancels.
   - (b) Add a way to post traversal requests into `_requests` / `_held`: `idle`, `run`, `vault`, the four vault exits, `ledge-climb-*` and the hashed corner requests, `reverse`, `fall`, `#8e6fcc68` / `#e2d1872c` / `shimmy-idle`.
   - (c) `_conditions_ok`: add the variable `ledge_free_hang` (second condition of the settle records). Today every non-phase, non-frames variable reads `move_dir_deg`.
   - (d) Per-state phase handling: a set phase for air progress; a rate scale per state from `callbacks.phase_update_cb`.
   - (e) Exits into `fall`, `idle`, `run-fw`, `idle^run-fwd` and `fall-land-soft-idle` are existing graph states, so the hand-back needs no new code beyond clearing TRAVERSE.
   - (f) Code-started exits: the contact / landing choice after the air states.
4. **`scripts/player/anim/anim_inputs.gd` (AnimInputs).** Add fields for the values in §8:
   - `mirror_side` (D4+32 / D8+744);
   - `air_progress` (D8+276);
   - `traversal_rate`, `traversal_rate_end`, `climb_rate`, `ledge_climb_rate` (D4+128 / 132 / 136, D8+96 × D4+124);
   - `ledge_free_hang` (C8+84), `ledge_shimmy_stride` (C8+80), `shimmy_rate` (D8+92), `ledge_look_dir` (C8+108).
5. **`scripts/player/anim/upper_body.gd` (UpperBody).**
   - While a traversal input is dominant, drop aim, grip and carry, so that the traversal clip and its `-bow--part` / `-rifle--part` layers own the arms.
   - The ladder, narrow-ledge and hang states have no weapon layer (only `actor_b-p-ledge-idle--hands` on the narrow ledge), so the weapon has to be holstered or hidden there.
6. **`scripts/player/player_anim.gd` (PlayerAnim facade).**
   - Public API: `start_traversal(entry_state, params)`, `traversal_request(req)`, `set_traversal_params(dict)`, and a signal `traversal_state_changed(from, to, info)` or `traversal_finished(exit_state)`.
   - Register an extra animation library if mirrored clips are baked offline (for example from `tools/traversal/` into `data/traversal/`).
7. **`scripts/player/player.gd` (FrontierPlayer).**
   - While traversing, hand body motion to the traversal controller: no gravity or velocity integration; the capsule follows the warped path.
   - Sprint (Shift) held = free-run intent.
   - Forward jump and crouch as traversal requests (gap jump / far jump; drop from a ledge).
   - Change the capsule on ladder and hang.
8. **`scripts/weapons/*.gd`.** Lower or holster on ladder / hang entry, and block fire and aim while traversing. Bow and musket keep their arm parts during vaults and jump-ups.
9. **`scripts/ui/anim_debug_overlay.gd` (F4).** Show the traversal graph state, the pending request, the phase and the overlay context.
10. **Optional, `tools/anim_graph/export_actor_b_graph.py`.** The WP1 exporter could export traversal roles itself. This is not required, because `graph_traversal.json` already uses its decoder and resolver.

Motion options for the missing free-hang network (design decision, not made here):
- (a) Drive the graph's ledge states with the Actor_B motion that exists:
  - hang pose: `idle-jump-up-3m^ledge-hang-mid` / `fall-ledge-grab`;
  - climb-up from the hang: `ledge-hang-climb-up^ledge-knee`;
  - catch: `fall-ledge-grab`;
  - vertical hand-over-hand: the ladder clips;
  - sideways: procedural hand IK over the hang pose.
- (b) Use the narrow-ledge wall shimmy (complete for Actor_B) for sideways routes along cliff faces and tree trunks.
- (c) Retarget other motion: the Actor_A → Actor_B prototype in `tools/retarget/` exists, but Actor_A has no hang-network clips either.
- (d) Use the companion's modular `actor_b-climb-on-*` / `actor_b-ambi-*` sets with proposed fades.

## 13. Open questions

- The unit of the fade scalar (seconds, inferred), the start phase at +0x24 (inferred) and the meaning of `scalar_0x20`, the +0x04 flags and byte +0x28.
- The variable of the second condition on the ledge settle states (free hang, inferred).
- The mirror flag reading of state +0x2c (inferred, strong).
- Default values of the rate fields (`D4+124/128/132/136`, `D8+92/96`); the graph stores only where they are read.
- Which `ledge` overlay the game used for real ledges. `ledge-hang` and `ledge-grab` are empty sets, so on ledges the graph clips play unchanged, and those clips are absent from both libraries.
- The two hashed wall-jump targets (`#9dcc9cf6`, `#fe1da2d7`), which are not states in the table.
- The leaves whose clip IDs have no name (`#...`) in the look, vault-kick, carry and wall-jump trees.
- Crouched jump-ups collect two arm parts at weight 1.0: the crouch part (keyed on the crouch intermediate) and the standing part (keyed on the source clip). Layer order (overlay priority, then record offset) decides which one shows; the exporter's layer rules apply.

## 14. Regenerating

```
cd /Users/kiwimango/Downloads/Frontier
python3 tools/traversal/extract_graph_traversal.py            # writes data/traversal/graph_traversal.json and this file
python3 tools/traversal/extract_graph_traversal.py --check    # exit 2 if either output is stale
python3 -m unittest discover tools/traversal/tests            # structural tests of the extract
```

Inputs are read-only. `meta.inputs_sha256` records the graph, the clip index, the WP1 exporter, its bindings and the vendored decoders.

