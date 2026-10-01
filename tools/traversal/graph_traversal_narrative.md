## 1. Summary

The decoded player graph has {n_states} traversal states in {n_families} families. The graph supplies the move chains: which part follows which, with which crossfade, at which phase, and how each move hands back to locomotion. It also supplies the ledge navigation network. It does not detect obstacles, measure heights or choose a move. {code_entered} of the states have no incoming transition record anywhere in the graph, so gameplay code starts them. The height a move was authored for exists only in the state and clip names, for example `idle^climb-up-jump-1-5m`, `move^vault-2m` and `auto-run^drop-2m-begin`. No traversal lambda reads a height, a distance or an obstacle direction (§8).

What this means for the free-running design:

- **Detection and move choice are ours.** The controller measures the obstacle and picks the entry state whose label fits. It sets the mirror side, then lets the graph chain run and hand back to locomotion with the graph's own fades (§4, §9).
- **The graph is built for flow, and several records support chaining:**
  - Exits to run mostly fire at phase 1 with a 0.2 s fade.
  - Idle-exit states accept a move request early, which cuts the recovery short with a 0.4–0.6 s fade. The window opens at phase 0 on the 0.5 m step-up, 0.2 on the knee catch, 0.5 on the knee climb-up and the vault, and 0.75 on the chest climb-up.
  - The 1 m knee jump-up can turn into a vault at phase 0.8. The `vault` request enters the vault-over at start phase 0.75 (running) or 0.8 (standing).
  - The ladder mount goes straight into a rung climb at phase 0.7.
  - Every hand-over-hand settle state (`climb-*^idle`) chains into the next move without returning to the hang. When braced, the chain uses the alternating-hand `-fast` clips with a 0.1 s fade.
- **Sprint is a movement mode, not a separate state set.** Under the sprint move overlay the same `test-vault` chain plays the four-part `actor_b-p-sprint-vault-1..4`. Crouch plays the crouch variants. Bow and musket add their `-bow--part` / `-rifle--part` arm layers. The pistol and unarmed profiles add none.

### Actor_B coverage

The fraction is the number of states whose every leaf resolves to an Actor_B clip under all 16 base selections (bow, musket, pistol, unarmed × walk, run, sprint, crouch).

| family | Actor_B | what exists for Actor_B |
|---|---|---|
| vault | {cov_vault} | The `test-vault` chain (begin → mid → end → run/idle) carries every Actor_B player vault: `idle^vault-over-1m`, `run^vault-over-1m`, `crouch-run^vault-over-1m`, `sprint-vault-1..4` (sprint), `vault-1m(-crouch)`, `vault-over-1m^vault-end-idle/-run/-idle-crouch`, `vault-end^idle/^run/^crouch-idle`. Also the 2 m vault-over (`idle^vault-over-2m`) and the old 1 m vault exits (`vault-over^idle-close`, `vault-over^run`). The `-close` variants of the jump overlay resolve to the same Actor_B clips. |
| jump_up_ledge | {cov_jump_up_ledge} | Jump-up to a ledge at 1 m and 1.5 m (knee; idle, run, crouch), 2 m (chest; begin/mid/end) and 3 m (hang; begin/mid/end, then `ledge-hang-climb-up^ledge-knee`). Knee and chest climb-ups go to idle, run or crouch. There is also a 2.75 m fail. |
| ladder | {cov_ladder}, plus the rung states of ledge_hang / ledge_climb under `ledge=ladder` | Complete: mount at the bottom (start/end) and at the top, idle, up, down, alternating-hand fast up/down, settle (plus flip), and dismount at the top (with `-vault` variants through `ladder-entry-exit=vault`) and at the bottom. |
| wall_shimmy | {cov_wall_shimmy} | Narrow ledge, facing the wall: enter, idle, idle^move, move loop, move^idle, exits. The left side is the mirrored right side; the left exit has its own clip. The climb-up from a hang onto the narrow ledge is Actor_A only. |
| edge_balance | {cov_edge_balance} | Ledge warn / teeter fw, bw, l, r (plus crouch variants). The lose-balance clip is Actor_A only. |
| gap_jump | {cov_gap_jump} | 1.5 m gap jump: idle / run take-off, air, land to idle / run. The 2.5 m labels play the same 1.5 m clips. Left-foot variants come through `jump=short-jump-*-lt`. |
| drop_down | {cov_drop_down} | Drop into the fall loop (`drop-down^fall`, with a crouch variant) and the air part of the 2 m jump-down. The 1 m drop and the 2 m begin/end have no clip. |
| step_up | {cov_step_up} | 0.5 m step-up (`walk/run/crouch-jump-up-0-5m`). The run-in / climb-onto clips are missing. |
| jump_onto | {cov_jump_onto} | Only the knee endings (`ledge-grab-knee^idle`, `ledge-grab-chest^ledge-grab-knee`). The jump-onto-1 m run-up and air clips are Actor_A only or absent. |
| ledge_catch | {cov_ledge_catch} | The falling edge grab (`fall-ledge-grab`, 0.2 s), the knee contact and chest → knee. The jump into them is `run^jump-long`. |
| ledge_hang | {cov_ledge_hang} | None as a ledge. `ledge-grab` is the ladder idle under `ledge=ladder`. |
| ledge_climb | {cov_ledge_climb} | None as a ledge. The up / down rung states are ladder clips under `ledge=ladder`; a ladder has no left or right moves. |
| drop_to_hang, wall_jump, hang_reactions, water_edge, step_up_carry | {cov_drop_to_hang}, {cov_wall_jump}, {cov_hang_reactions}, {cov_water_edge}, {cov_step_up_carry} | None. |

**The biggest gap is the free-hang ledge network.** It covers the hang idle, hang shimmy, hand-over-hand up / down / left / right / diagonal moves, far jumps, inside and outside corners, swings, looks, drop-to-hang and one- and two-hand catches. None of these has a clip in either bundled library, Actor_A or Actor_B: only their names and IDs survive in the graph. The graph logic itself is intact and reusable, and Actor_B already runs it as a ladder through the `ledge=ladder` overlay. A hang-and-shimmy system therefore needs motion from elsewhere; §12 lists the options.

**The companion's own traversal set is not in the player graph at all** (§10). It includes `actor_b-ambi-*`, `actor_b-climb-on-*m-up/down`, `actor_b-run-jump-across-2m`, `actor_b-balance-beam-*` and `actor_b-crouch-under-*`. The set is modular: run-enter → loop → exit, with left, right and in-place entries, for 0.5, 1, 1.5, 2, 2.5 and 3 m up and down. That suits free-running, but there are no graph fades for it; any fades used with it are proposals.

**Unused Actor_B player clips** are listed in §10. No overlay record names them, so no graph state plays them. They include dedicated chest climb-ups (`actor_b-p-ledge-chest-climb-up^idle/^run/^crouch/^stealth-idle`; the overlay maps the chest climb-ups to the knee climb-up clips instead), the run versions of the 2 m chest jump-up (`actor_b-p-run-jump-up-2m^ledge-chest-mid/-end`), and sprint vault pieces (`actor_b-p-sprint^vault-over-1m`, `actor_b-p-vault-end^sprint`). These are good candidates for code-selected variants.

**Balance** is a movement mode in the player graph, not a state (§11). Actor_B has `walk-balance` and `run-balance` mode records, but their overlays remap locomotion to `base-balance-*` clips that exist only for Actor_A. **Crouch-under** has no state either. The `crouch-under=on` overlay only adds aim-under additives to the aim and quick-throw states (7 state-keyed layer records), and Actor_B's `crouch-under-start/loop/end-a` are companion clips. **Squeeze-through** exists only as a one-off cinematic clip (`out4-actor_b-squeeze-through--actor_b`, 8.3 s).

## 2. What the graph decides and what code supplies

| the graph decides (use as data) | gameplay code supplies (hooks, §12) |
|---|---|
| The order of the parts inside a move (begin → mid → end, contact → climb-up → idle / run) and their fades. Parts cut from one take use 0 s at phase 1; other steps use 0.1–0.2 s. | The entry state, by obstacle height / depth / type, speed and stance. All {code_entered} entries are code-started. |
| Hand-back timing: gates and fades into idle, run, fall and landing (§9), including the early move windows (phase 0–0.75, fade 0.4–0.6 s). | Contact and landing choice after the `*-mid-jump` air states and `chest-grab-air` / `1-hand-grab-air` / `2-hand-grab-air`. These have no outgoing record; code picks the next state when the hands or feet arrive. |
| Ledge navigation: which move follows which, hand alternation (rh / lh), fast chaining only when braced, `reverse` in the first half of a move. Fades: 0.2 s out of the hub, 0.4 s settle → hub, 0.5 s or 0.1 s chaining (§6). | Requests: `idle` / `run` exits; the hashed vault exits; `vault` (knee → vault); the `ledge-climb-*` navigation requests from stick direction plus handhold search; `reverse`; `fall`; the narrow-ledge move and stop requests. |
| Per-mode and per-weapon clip choice through overlays: sprint vault, crouch variants, the bow / musket arm parts. | Overlay context: `ledge=ladder` on a ladder; `ladder-entry-exit=vault/rail/to-left/to-right`; `jump=short-jump-*-lt` for a left-foot take-off. |
| Which states are mirrored: the left twins have a constant mirror flag. | Mirror side for vault / climb / jump (`i32[D4+32]`) and for the auto climb / drop (`i32[D8+744]`). |
| Phase behaviour: `*-mid-jump` phase = air progress; the vault state holds phase 1.0; swings run at half rate. | Values: air progress (`f32[D8+276]`), rate multipliers (`D4+128/132/136`, `D8+92`, `D8+96 × D4+124`), free-hang amount (`C8+84`), shimmy stride (`C8+80`), look direction (`C8+108`). |
| Nothing about root motion. | The body path: the clips carry no root motion (see the clip survey), so the controller moves the capsule (motion warping). |

## 3. Decoding notes and confidence

- **Fades.** Transition scalar +0x1c is read as the crossfade in seconds. This is inferred, not proven (graph_understanding: 0 s on self-loops, never longer than the target clip). Traversal values: 0, 0.05, 0.1, 0.166, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.75, 0.8, 1.0 s.
- **Mirror flag.** The state +0x2c callback is read as "play mirrored". In {mirror_pairs} cases one tree is shared by a state whose +0x2c returns the constant 1 and a state without +0x2c. The flagged state is always the left, `-m` or other-hand twin (for example `ledge-shimmy-left`, `climb-lt-lh`, `wall-shimmy-idle-left`, `flinch-ledge-hang-l`, `throw-grenade-hang-m`). Status: inferred, strong.
  - Vault / climb / jump / drop states return a runtime int (`i32[D4+32]`); the `*-mid-jump` air states return its negation.
  - Godot's AnimationTree cannot mirror at runtime, so mirrored states need baked mirrored clips (§12).
- **Phase callbacks (+0x28).** They return the new phase.
  - `*-mid-jump` states: phase = `f32[D8+276]`. The code flies the jump and the clip follows it; this is a strong fit for motion warping.
  - `vault`: constant 1.0. The state sits on its last frame until code sends one of the four hashed exit requests.
  - `chest-hang-approach`: constant 0 (frozen).
  - Swings (`ledge-grab-fw/bk`): half rate.
  - Shimmy: rate `f32[D8+92]`.
  - Fast / far hand-over-hand moves: rate × `f32[D8+96] × f32[D4+124]`.
  - Vault entries / exits: rate × `f32[D4+128]`.
  - Jump-up / climb-up / ladder dismount: rate × `f32[D4+136]`.
  - `climb-short-run`: rate ramps from `D4+128` to `D4+132` over the clip.
  - Default rate values are not in the data; 1.0 is the natural default.
- **Second condition on the ledge settle states.** Each chaining record is `phase ≥ a AND x ≤ 0.5` or `phase ≥ a AND x ≥ 0.5`. The graph does not say what x is. It is read here as the free-hang amount (`f32[C8+84]`, the blend weight of every hand-over-hand tree): {le_fast} records with x ≤ 0.5 target a `-fast` / `far` / outside-corner state and {le_blend} target a blended state; with x ≥ 0.5, {ge_fast} target a `-fast` state and {ge_blend} target a blended one.
  - The `-fast`, `far` and outside-corner states are braced-only: their free-hang blend weight is the constant 0.
  - So the braced-only moves are reachable only with x ≤ 0.5, which fits "braced vs hanging". Status: inferred.
  - The JSON names this variable `ledge_free_hang`, not `secondary`, because LocoBrain maps `secondary*` to `move_dir_deg`.
- **`reverse`** (flags 0x4, fade 0.1–0.2 s, phase ≤ 0.5) returns any hand-over-hand move to the hang hub when the stick is released or reversed in its first half.
- **Hashed requests.** Their name hashes are not in symbol_candidates, so each is read from its only target(s):
  - the vault exits `#5a28604e`, `#ecb2aea0`, `#fd83b53b`, `#32f79c5e`;
  - the narrow-ledge moves `#2ec95958` / `#a4a2175b`;
  - the corner moves `#85591498` etc.;
  - the wall-jump catches.
  - `#6e07f05e` and `#91b8bb4f` are targets that are not states in the table.
- **Undecoded fields**, copied as-is: `scalar_0x20`, the flags at +0x04 and byte +0x28. Observations: 0x800 is on most chained auto records between parts of one move; 0x20 is on many phase-1 exits (into `run-fw`, `idle` and the vault exit states); 0x84 is on the navigation records out of the hang hub and 0x80 on most chaining records; 0x4 is on `reverse` and the shimmy → hub records. Byte 0x28 = 05 marks the 0.75 s look / swing fades, and 04 marks most returns to the hub.
- **Runtime fields.** The traversal lambdas read {n_fields} distinct runtime fields (§8).
- **Height labels** (`geometry_label` in the JSON) are parsed from names: authoring intent, not measurements. The clip survey (`data/traversal/clip_geometry.json`) holds the measured contacts.
- **Resolver.** The `asc_once` overlay loop comes from `tools/anim_graph/frontier_bindings.json`. It agrees with `asc_fix` on every traversal leaf (`meta.resolver_disagreements` is empty). 

