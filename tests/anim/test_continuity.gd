extends AnimTestSuite
## WP6 (plan section 10 test_continuity; G9 "nothing may pop"): the whole PlayerAnim facade
## (tree, LocoBrain, UpperBody, PropFlipGuard, AimStabilizer) on the real Actor_B rig, measured on
## the pose the player sees: after every PlayerAnim.manual_step() the suite waits for the skeleton
## update, so the modifiers run, and records in Skeleton3D.skeleton_updated the skeleton-space
## rotation of every core bone (the plan's core bones: the ones actor_b-p-run-fw keys), of both
## weapon prop bones (l_ / r_hand_prop_attachment: the weapon models hang off them), and whether
## any bone pose is non-finite.
##
## 1. Deterministic parts.
##    - Raise / lower while moving: each weapon standing still and running forward, left, back and
##      right (and the crouched strafe), the weapon raised then lowered (flat 25 rad/s).
##    - Running jumps (musket walk / run / sprint, bow, pistol): take-off -> jump is the graph's
##      fade-0 join, whose carry-layer stacks differ for the musket.
##    - Weapon switches (each draw) and the bow's shots with the quiver nock and the hand nock
##      while running.
##    - Interrupted draws (WP6 review 2): a second weapon switch 1..20 frames after the first, for
##      all six orders of the three weapons (the first draw's partial fades out while the second
##      fades in; mouse-wheel cycling, player.gd has no switch lockout), and death and
##      action_cancelled 1..20 frames into each weapon's draw.
##    - Shot cancel (WP7; Firearm.shot_cancelled: RMB or R while LMB holds the weapon up, and the
##      bow's let-down): the raise reversed 4..40 frames into it, no shot, still and running; the
##      upper body lowers like an aim release without a shot.
##    - Holster switches (WP7, player.gd switch_weapon): the graph switch, stage by stage as
##      FrontierPlayer.switch_stages() times it: the old weapon's holster (its draw clip backwards,
##      at its draw's speed), its holster finish (the hand back to idle), the new weapon's grab
##      (draw step 1) and its draw; all six weapon pairs, lowered and raised at the switch, still
##      and running; and a further switch 2..16 frames into that draw (the drawing weapon holstered
##      from where its draw is).
##    All but raise / lower use the per-bone rule below on the core bones and both prop bones; the
##    holster switches on the core bones and the prop bone a weapon model hangs off at that frame
##    (the old weapon's through its holster, none through the finish and the grab, the new one's
##    from its draw: a prop bone without a model is not seen).
##    `parts=cancel,holster` runs only the named WP7 parts (`pairs=musket-pistol,...` only those
##    holster pairs); `parts=jumps` only the running jumps, `parts=storm` only the storms (part 2).
## 2. Storm: a long random input and event storm at dt 1/60 with the gameplay rules of player.gd
##    and the weapons (GameSim): walk / run / sprint in 8 directions and standing still, crouch
##    toggles (sprint and jumps stand up), jumps, camera yaw (idle turns), aim toggles and
##    elevation, fire (flintlocks only when up, then the staged reload, interrupted by sprint and
##    jumps; the bow's draw, let-down, shot and nock from the hand or the quiver, the R grab),
##    weapon switches (unequip / set_weapon / equip), light and heavy hits, deaths and respawns.
##    Graph defaults for 10 min (`minutes=`), then the gameplay overrides G1, G2, G5 and the crouch
##    crossfade with join_fade_s 0.1 for 0.3 x that. The core bones follow the per-bone rule and
##    fail the suite; the weapon's prop bone is reported (count, worst, the first 12), not failed.
##
## Per-bone rule: no NaN / INF in any bone pose, ever; each bone's per-frame skeleton-space
## angular speed <= 25 rad/s + that bone's own authored allowance, with exactly these allowances:
##   revive    the respawn frame (straight to idle, by design; storm only);
##   authored  the largest, over the clips playing, of the clip's own motion over the clip time it
##             played this frame (x |rate|), measured on the data as the most it can turn THIS bone
##             in skeleton space whatever the pose under it (the sum of its keyed rotations'
##             angles along this bone's parent chain), x its blend weight (lower inputs: selector x
##             hemisphere weight; OneShots: their fade weight; the bow draw: its add amount). The
##             lower body counts as one clip, its inputs' blend-weighted sum; each OneShot and the
##             draw count alone; the allowance is the largest of these per bone, never a sum
##             across them, and never another bone's.
## and two named terms added on top of it (frames that need them are counted as "named"):
##   kick      authored-kick onset (see KICKS): the onset of a fire additive. Its first frame is
##             already the recoil, and the graph's fire state is entered by code with no transition
##             record (no authored fade; tuning fire_fade, proposed, fades it in over 0.02 s):
##             during its fade-in the bone may also turn by (fade-in weight gained this frame) x
##             (the clip's own chain angle from the bind pose at its current time) / dt;
##   layers    carry-layer change: the lower inputs carry the graph's resolved layers of their
##             states, and those differ between states (the musket's take-off and its walk-mode
##             landings have no rifle-run-arms layer, the run, the jump and the other landings do),
##             so a crossfade between them (or a weapon crossfade) also moves the layers' authored
##             poses in or out: the bone may also turn by, summed over the layers whose effective
##             amount (input weight x hemisphere weight x layer amount) changed this frame, that
##             change x the layer's chain angle (partial: its pose against the input's base clip on
##             the bones it keys; additive: its delta from the bind pose) / dt, the change taken
##             as no faster than a 0.1 s crossfade (the graph's shortest non-zero fade), so a cut
##             that snaps the layers is not covered;
## The base clips' crossfades, joins, fades and anything else the controllers add are not
## covered. Every other
## frame over the rule counts and fails the suite; each one is printed with the state, the
## transitions of the frame, the OneShots and their fades, the draw, the stabilizer weight and
## correction, and the pre-modifier speed. The strict configuration must also never weight an
## idle-turn input. `trace=a-b` prints frames a..b of the graph-default storm; `stages=1` adds to each
## counted (and traced) frame its bone's speed after each modifier (StageProbe); `quick` skips the
## interrupted draws but one order.

const FacadeRig := preload("res://tests/anim/facade_rig.gd")
const StageProbe := preload("res://tests/anim/lib/stage_probe.gd")
const LIMIT := 25.0
const CONFIGS := [
	{"label": "graph default", "exports": {}, "minutes": 10.0, "seed": 20260924, "strict": false},
	{"label": "overrides G1+G2+G5+crouch crossfade, join_fade_s 0.1", "exports": {"override_no_transition_anims": true,
			"override_fast_hemisphere_fade": true, "override_no_idle_turns": true, "override_crouch_crossfade": true,
			"join_fade_s": 0.1}, "minutes": 3.0, "seed": 777, "strict": true},
]
const RAISE_DIRS := [["still", Vector2.ZERO, 0.0], ["forward", Vector2(0, 1), 3.6], ["left", Vector2(-1, 0), 3.6],
		["back", Vector2(0, -1), 3.6], ["right", Vector2(1, 0), 3.6]]
## Interrupted draws: every order of the three weapons (second switch k frames after the first).
const SWITCH_ORDERS := [["bow", "musket", "pistol"], ["bow", "pistol", "musket"], ["musket", "bow", "pistol"],
		["musket", "pistol", "bow"], ["pistol", "bow", "musket"], ["pistol", "musket", "bow"]]
## Death / cancel during each weapon's draw, drawn from the weapon before it.
const DRAW_FROM := {"bow": "pistol", "musket": "bow", "pistol": "musket"}
const INTERRUPT_MAX_K := 20
const INTERRUPT_FRAMES := 70
const SETTLE_FRAMES := 60
## Carry-layer change term: a layer's effective amount counts as changing no faster than a
## crossfade over the graph's shortest non-zero transition fade (0.1 s, e.g. jump_to_land_idle
## 0x000256a0), so a cut (fade 0: the layers snap) is never covered.
const LAYER_FADE_MIN_S := 0.1
## Named authored-kick exemptions: OneShot chains whose fade-in onset is the clip's own first
## frame (fire additives: the runtime fire clip's recoil starts on its first frame).
const KICKS := {"F": "fire kick onset"}

var _sk: Skeleton3D
var _core := PackedInt32Array()           ## core bone indices, then the two prop bones
var _core_names := PackedStringArray()
var _prop := {}                           ## Weapon.Hand -> index in _core of that hand's prop bone
var _n_core := 0                          ## _core[0, _n_core) are the core bones, then the two props
var _wprop := -1                          ## index in _core of the prop bone carrying the weapon model
var _scope := "core"                      ## "core" | "prop" (weapon prop) | "all" (core + weapon prop) | "both" (core + both props)
var _chain_order := PackedInt32Array()    ## core bones and their ancestors, parents first
var _core_chain: Array = []               ## per index in _core: indices into _chain_order of its chain
var _post: Array[Quaternion] = []         ## skeleton-space rotations of _core (post-modifier)
var _nonfinite := 0
var _updates := 0
var _oracle: PoseOracle
var _clip_cache := {}                     ## "clip|t" -> Array[Quaternion] (chain bones, local)
var _bind_cache := {}                     ## "clip|t" -> PackedFloat32Array (chain angle from the bind pose)
var _rest_r: Array = []                   ## bind-pose local rotations (per bone index)
var _kick_nodes := {}                     ## OneShot node of a KICKS chain -> fade_in_remaining path
var _fade_hist := {}                      ## such a node (active) -> [fade_in_remaining after the last advance, its blend then]
var _kick_gain := {}                      ## such a node -> fade-in weight it gained in the frame just played
var _vis_prop := -2                       ## scope "visible": the prop bone with a model (-2 current weapon's, -1 none)
var _layer_prev := {}                     ## carry-layer param -> [effective amount last frame, context]
var _layer_delta := {}                    ## carry-layer param -> [|change of its effective amount| this frame, context]
var _theta_cache := {}                    ## "layer|base|t" -> PackedFloat32Array (layer chain angle per index)


func describe() -> String:
	return "PlayerAnim continuity on the visible (post-modifier) pose: raise / lower, jumps, draws, interrupted draws, shot cancel, holster switches, 10 min storm; no NaN, per bone <= 25 rad/s + that bone's own authored allowance"


func timeout_s() -> float:
	return 1800.0


func run(ctx: AnimTestContext) -> void:
	var parts := String(ctx.arg("parts", "")).split(",", false)
	if not parts.is_empty():
		if "jumps" in parts:
			await _running_jumps(ctx)
		if "cancel" in parts:
			await _shot_cancel(ctx)
		if "holster" in parts:
			await _holster_switches(ctx)
		if "storm" in parts:
			await _storms(ctx)
		return
	await _raise_lower(ctx)
	await _running_jumps(ctx)
	await _actions_moving(ctx)
	await _switch_interrupts(ctx)
	await _draw_interrupts(ctx)
	await _shot_cancel(ctx)
	await _holster_switches(ctx)
	await _storms(ctx)


## The storms, one per configuration (CONFIGS).
func _storms(ctx: AnimTestContext) -> void:
	for cfg: Dictionary in CONFIGS:
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": "musket", "exports": cfg.exports}):
			return
		_hook(ctx, h)
		var minutes := float(ctx.arg("minutes", 10.0)) * float(cfg.minutes) / 10.0
		await _storm(ctx, h, FacadeRig.GameSim.new(h, int(cfg.seed)), cfg, minutes)
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)


# --- capture ------------------------------------------------------------------------------------

func _hook(ctx: AnimTestContext, h) -> void:
	_sk = h.rig.sk
	_core = PackedInt32Array()
	_core_names = PackedStringArray()
	for n in h.core_bones():
		if not n.ends_with("_prop_attachment"):
			_core_names.append(n)
	_n_core = _core_names.size()
	_prop = {}
	for side in [[Weapon.Hand.LEFT, "l_hand_prop_attachment"], [Weapon.Hand.RIGHT, "r_hand_prop_attachment"]]:
		_core_names.append(side[1])
		_prop[side[0]] = _core_names.size() - 1
	_wprop = -1
	_scope = "core"
	for n in _core_names:
		_core.append(_sk.find_bone(n))
	var need := {}
	for b in _core:
		var p := b
		while p >= 0:
			need[p] = true
			p = _sk.get_bone_parent(p)
	var order: Array = need.keys()
	order.sort()
	# Bone indices are parent-first in a Skeleton3D, so sorting keeps parents before children.
	_chain_order = PackedInt32Array(order)
	var at := {}
	for i in _chain_order.size():
		at[_chain_order[i]] = i
	_core_chain = []
	for b in _core:
		var ch := PackedInt32Array()
		var p := b
		while p >= 0:
			ch.append(at[p])
			p = _sk.get_bone_parent(p)
		_core_chain.append(ch)
	_oracle = ctx.oracle(h.rig)
	_rest_r = _oracle.rest().r
	_kick_nodes = {}
	for on: String in h.anim.index.oneshots:
		if KICKS.has(String(h.anim.index.oneshots[on].chain)):
			_kick_nodes[on] = StringName("parameters/%s/fade_in_remaining" % on)
	_fade_hist = {}
	_kick_gain = {}
	_layer_prev = {}
	_layer_delta = {}
	_theta_cache.clear()
	_clip_cache.clear()
	_bind_cache.clear()
	_post.clear()
	_nonfinite = 0
	_sk.skeleton_updated.connect(_on_updated)


func _unhook() -> void:
	if is_instance_valid(_sk) and _sk.skeleton_updated.is_connected(_on_updated):
		_sk.skeleton_updated.disconnect(_on_updated)


func _on_updated() -> void:
	_updates += 1
	_post.resize(_core.size())
	for i in _core.size():
		_post[i] = _sk.get_bone_global_pose(_core[i]).basis.get_rotation_quaternion()
	for b in _sk.get_bone_count():
		if not _sk.get_bone_global_pose(b).is_finite():
			_nonfinite += 1
			break


## One animation frame of the harness, then the skeleton update. False if no update came.
func _frame(ctx: AnimTestContext, h, dir := Vector2.ZERO, speed := 0.0, ex := {}) -> bool:
	h.step(dir, speed, ex)
	_set_weapon_prop(h)
	var n := _updates
	await ctx.idle_frames(1)
	if _updates == n:
		await ctx.idle_frames(1)
	return _updates != n


func _pre() -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	for b in _core:
		out.append(_sk.get_bone_global_pose(b).basis.get_rotation_quaternion())
	return out


## The prop bone that carries the current weapon's model (player.gd attaches the model to l_ or
## r_hand_prop_attachment by Weapon.hand).
func _set_weapon_prop(h) -> void:
	var w: Weapon = h.weapons.get(h.weapon)
	_wprop = int(_prop.get(w.hand if w != null else Weapon.Hand.RIGHT, -1))


func _in_scope(i: int) -> bool:
	match _scope:
		"core":
			return i < _n_core
		"prop":
			return i == _wprop
		"both":
			return true
		"visible":
			# Holster switches: the core bones and the prop bone a weapon model hangs off right
			# now (_vis_prop: -2 = the current weapon's, -1 = none: the hand is empty).
			return i < _n_core or i == (_wprop if _vis_prop == -2 else _vis_prop)
	return i < _n_core or i == _wprop


## Worst per-frame angular speed between two captures over the bones in _scope: [rad/s, bone].
func _speed(a: Array[Quaternion], b: Array[Quaternion], dt: float) -> Array:
	var m := 0.0
	var mb := ""
	for i in mini(a.size(), b.size()):
		if not _in_scope(i):
			continue
		var d := PoseOracle.qdist(a[i], b[i]) / dt
		if d > m:
			m = d
			mb = _core_names[i]
	return [m, mb]


## Per-bone rule on one frame over the bones in _scope. `cache` (optional) keeps the allowance of
## this frame for a second call with another scope. Returns {speed, bone (fastest in scope), over,
## ex_bone, ex_speed, allow (that bone's 25 + allowance), by, excess, kick}.
func _judge(h, a: Array[Quaternion], b: Array[Quaternion], dt: float, charge_prev: float, charge_pos: float,
		cache := {}) -> Dictionary:
	var n := mini(a.size(), b.size())
	var sv := PackedFloat32Array()
	sv.resize(n)
	var m := 0.0
	var mi := -1
	for i in n:
		if not _in_scope(i):
			continue
		sv[i] = PoseOracle.qdist(a[i], b[i]) / dt
		if sv[i] > m:
			m = sv[i]
			mi = i
	var out := {"speed": m, "bone": _core_names[mi] if mi >= 0 else "", "over": false, "ex_bone": "", "ex_speed": 0.0,
			"allow": LIMIT, "by": "", "excess": 0.0, "kick": ""}
	if m <= LIMIT:
		return out
	if not cache.has("al"):
		cache["al"] = _allowance(h, dt, charge_prev, charge_pos)
	var al: Dictionary = cache.al
	var av: PackedFloat32Array = al.v
	var kv: PackedFloat32Array = al.kick
	var lv: PackedFloat32Array = al.layer
	var wi := -1
	var worst := 0.0
	var kick_used := ""
	for i in n:
		if not _in_scope(i) or sv[i] <= LIMIT:
			continue
		var ex: float = sv[i] - (LIMIT + av[i])
		if ex > 0.0 and ex <= kv[i] + lv[i]:
			var names := []
			if kv[i] > 0.0:
				names.append(String(al.kick_by[i]))
			if lv[i] > 0.0:
				names.append("carry-layer change %.1f" % lv[i])
			kick_used = " + ".join(names)
			continue
		if ex > worst:
			worst = ex
			wi = i
	var i := wi if wi >= 0 else mi
	out.allow = LIMIT + av[i]
	out.by = String(al.by[i])
	out.kick = kick_used
	if wi >= 0:
		out.over = true
		out.excess = worst
		out.ex_bone = _core_names[wi]
		out.ex_speed = sv[wi]
	return out


# --- 1. deterministic parts ------------------------------------------------------------------------

func _raise_lower(ctx: AnimTestContext) -> void:
	var rows := []
	var worst := 0.0
	var worst_at := ""
	for w in FacadeRig.WEAPON_KEYS:
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": w}):
			return
		_hook(ctx, h)
		_scope = "all"
		var cases := RAISE_DIRS.duplicate()
		cases.append(["crouched left", Vector2(-1, 0), 1.4])
		for c: Array in cases:
			h.crouched = String(c[0]).begins_with("crouched")
			h.aiming = false
			for i in 100:
				await _frame(ctx, h, c[1], c[2])
			var prev := _post.duplicate()
			var m := 0.0
			var mb := ""
			var peak_c := 0.0
			for i in 90:
				h.aiming = i < 45
				var ok: bool = await _frame(ctx, h, c[1], c[2])
				if not ok:
					ctx.fail("%s %s: no skeleton update after a frame" % [w, c[0]])
					break
				var s := _speed(prev, _post, h.dt)
				prev = _post.duplicate()
				peak_c = maxf(peak_c, h.anim.stabilizer.last_correction_deg())
				if s[0] > m:
					m = s[0]
					mb = "%s f%d aim %.2f" % [s[1], i, h.aim]
			rows.append("%s %s: worst %.1f rad/s (%s), correction up to %.0f deg" % [w, c[0], m, mb, peak_c])
			if m > worst:
				worst = m
				worst_at = "%s %s %s" % [w, c[0], mb]
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)
	for r in rows:
		ctx.info("raise/lower " + r)
	_scope = "core"
	ctx.at_most(worst, LIMIT, "raise and lower while still / running fw, lt, bw, rt / crouched strafe, 3 weapons: worst visible speed of the core bones and the weapon's prop bone (rad/s) [%s]" % worst_at)


## Running jumps: every frame within the per-bone rule. A sixth run, reported only, repeats the
## musket run jump with PlayerAnim.strict_graph_cuts (the carry layers cut with the base clip at
## the take-off -> jump fade-0 join, the literal reading of the graph; tuning carry_join_s off).
func _running_jumps(ctx: AnimTestContext) -> void:
	var rows := []
	var bad := 0
	var worst_at := ""
	for c: Array in [["musket", 1.6, false], ["musket", 3.6, false], ["musket", 5.6, true], ["bow", 3.6, false], ["pistol", 3.6, false],
			["musket", 3.6, false, "strict"]]:
		var strict: bool = c.size() > 3
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": c[0], "exports": {"strict_graph_cuts": true} if strict else {}}):
			return
		_hook(ctx, h)
		_scope = "both"
		h.sprinting = c[2]
		h.walking = float(c[1]) < 2.0
		for i in 120:
			await _frame(ctx, h, Vector2(0, 1), c[1])
		var st := _measure_state(h)
		for i in 110:
			await _frame(ctx, h, Vector2(0, 1), c[1], {"jump": i == 0})
			_measure(h, st, "f%d" % i)
		var tag := "%s at %.1f m/s%s" % [c[0], c[1], " sprinting" if c[2] else ""]
		if strict:
			rows.append("running jump %s with strict_graph_cuts (reported, not counted): %s%s" % [tag, _measure_row(st),
					(" | " + String(st.lines[0])) if not (st.lines as Array).is_empty() else ""])
		else:
			bad += int(st.over)
			rows.append("running jump %s: %s" % [tag, _measure_row(st)])
			if int(st.over) > 0 and worst_at == "":
				worst_at = "%s: %s" % [tag, st.lines[0]]
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)
	_scope = "core"
	for r in rows:
		ctx.info(r)
	ctx.check(bad == 0, "running jumps (take-off -> jump fade-0 join, landing), 5 cases, core bones and both prop bones: %d frames over the per-bone rule %s" % [bad, worst_at])


## Weapon draws on every switch and the bow's shots with the quiver nock and the hand nock, while
## running forward (the draw and nock clips turn the prop bones through half a turn from the bind
## pose; PropFlipGuard).
func _actions_moving(ctx: AnimTestContext) -> void:
	var rows := []
	var bad := 0
	var worst_at := ""
	for c: Array in [["bow", "musket"], ["musket", "pistol"], ["pistol", "bow"], ["pistol", "musket"], ["musket", "bow"], ["bow", "pistol"]]:
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": c[0]}):
			return
		_hook(ctx, h)
		_scope = "both"
		for i in 100:
			await _frame(ctx, h, Vector2(0, 1), 3.6)
		var st := _measure_state(h)
		h.switch(c[1])
		await _run_measured(ctx, h, st, 70, "draw")
		if c[1] == "bow":
			for nock in [0.75, 0.35]:
				h.aiming = true
				for i in 45:
					h.charge = minf(h.charge + h.dt / 0.6, 1.0)
					await _run_measured(ctx, h, st, 1, "charge")
				h.fire()
				h.charge = 0.0
				h.aiming = false
				h.action("nock", nock)
				await _run_measured(ctx, h, st, 60, "shot + nock %.2f" % nock)
		bad += int(st.over)
		var tag := "%s -> %s" % [c[0], c[1]]
		rows.append("%s: %s; long-way prop frames %d" % [tag, _measure_row(st), h.anim.upper.prop_guard.flipped_frames()])
		if int(st.over) > 0 and worst_at == "":
			worst_at = "%s: %s" % [tag, st.lines[0]]
		_scope = "core"
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)
	for r in rows:
		ctx.info("draw / shot " + r)
	ctx.check(bad == 0, "weapon draws on switches and bow shots with quiver / hand nocks while running, core bones and both prop bones: %d frames over the per-bone rule %s" % [bad, worst_at])


## A second weapon switch 1..20 frames after the first, every order of the three weapons, while
## running: the first draw's partial is cut (action_cancelled -> fade-out once its fade-in is
## over) while the second draw fades in. One rig per order; each case starts from the first weapon
## settled (switched back and run for SETTLE_FRAMES).
func _switch_interrupts(ctx: AnimTestContext) -> void:
	var orders: Array = SWITCH_ORDERS if not ctx.arg("quick", false) else [SWITCH_ORDERS[0]]
	var bad := 0
	var cases := 0
	var worst := 0.0
	var worst_at := ""
	var lines := []
	for o: Array in orders:
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": o[0]}):
			return
		_hook(ctx, h)
		_scope = "both"
		for i in SETTLE_FRAMES:
			await _frame(ctx, h, Vector2(0, 1), 3.6)
		var ow := 0.0
		var ow_at := ""
		var oover := 0
		var onamed := 0
		for k in range(1, INTERRUPT_MAX_K + 1):
			var st := _measure_state(h)
			h.switch(o[1])
			for i in INTERRUPT_FRAMES:
				if i == k:
					h.switch(o[2])
				await _frame(ctx, h, Vector2(0, 1), 3.6)
				_measure(h, st, "k%d f%d" % [k, i])
			cases += 1
			oover += int(st.over)
			onamed += int(st.kicks)
			for l in st.lines:
				if lines.size() < 12:
					lines.append("%s k=%d %s" % ["->".join(o), k, l])
			if float(st.m) > ow:
				ow = float(st.m)
				ow_at = "k=%d %s" % [k, st.mb]
			h.switch(o[0])
			for i in SETTLE_FRAMES:
				await _frame(ctx, h, Vector2(0, 1), 3.6)
		bad += oover
		ctx.info("second switch %s, k = 1..%d: worst %.1f rad/s (%s), %d frames over the rule, %d within the named terms; long-way prop frames %d" % [
				"->".join(o), INTERRUPT_MAX_K, ow, ow_at, oover, onamed, h.anim.upper.prop_guard.flipped_frames()])
		if ow > worst:
			worst = ow
			worst_at = "%s %s" % ["->".join(o), ow_at]
		_scope = "core"
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)
	for l in lines:
		ctx.info("  over " + l)
	ctx.metric("second_switch_worst_rad_s", worst)
	ctx.check(bad == 0, "second weapon switch 1..%d frames after the first, %d orders (%d cases), core bones and both prop bones: %d frames over the per-bone rule (worst %.1f rad/s, %s)" % [
			INTERRUPT_MAX_K, orders.size(), cases, bad, worst, worst_at])


## Death and action_cancelled 1..20 frames into each weapon's draw, while running.
func _draw_interrupts(ctx: AnimTestContext) -> void:
	var weapons: Array = FacadeRig.WEAPON_KEYS if not ctx.arg("quick", false) else ["musket"]
	var bad := 0
	var cases := 0
	var worst := 0.0
	var worst_at := ""
	var lines := []
	for w: String in weapons:
		var from := String(DRAW_FROM[w])
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": from}):
			return
		_hook(ctx, h)
		_scope = "both"
		for i in SETTLE_FRAMES:
			await _frame(ctx, h, Vector2(0, 1), 3.6)
		for mode in ["cancel", "death"]:
			var mw := 0.0
			var mw_at := ""
			var mover := 0
			var mnamed := 0
			for k in range(1, INTERRUPT_MAX_K + 1):
				var st := _measure_state(h)
				h.switch(w)
				for i in INTERRUPT_FRAMES:
					if i == k:
						if mode == "cancel":
							h.cancel()
						else:
							h.alive = false
							h.aiming = false
							h.anim.play_death(Vector2(0, 1))
					await _frame(ctx, h, Vector2(0, 1), 3.6)
					_measure(h, st, "k%d f%d" % [k, i])
				cases += 1
				mover += int(st.over)
				mnamed += int(st.kicks)
				for l in st.lines:
					if lines.size() < 30:
						lines.append("%s draw from %s, %s k=%d %s" % [w, from, mode, k, l])
				if float(st.m) > mw:
					mw = float(st.m)
					mw_at = "k=%d %s" % [k, st.mb]
				if mode == "death":
					h.alive = true
					h.anim.revive()
				h.switch(from)
				for i in SETTLE_FRAMES:
					await _frame(ctx, h, Vector2(0, 1), 3.6)
			bad += mover
			ctx.info("%s 1..%d frames into the %s draw (from %s): worst %.1f rad/s (%s), %d frames over the rule, %d within the named terms" % [
					mode, INTERRUPT_MAX_K, w, from, mw, mw_at, mover, mnamed])
			if mw > worst:
				worst = mw
				worst_at = "%s %s %s" % [w, mode, mw_at]
		_scope = "core"
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)
	for l in lines:
		ctx.info("  over " + l)
	ctx.check(bad == 0, "death and action_cancelled 1..%d frames into each draw, %d weapons (%d cases), core bones and both prop bones: %d frames over the per-bone rule (worst %.1f rad/s, %s)" % [
			INTERRUPT_MAX_K, weapons.size(), cases, bad, worst, worst_at])


## WP7: shot cancel. Firearm (RMB or R while LMB holds the weapon up): AIMING -> READY with
## shot_cancelled, no shot; Weapon.aim then eases down at aim_out_time. The bow's let-down (RMB):
## the draw unwinds. The raise is reversed 4..40 frames into it, standing still and running; the
## upper body must lower like an aim release without a shot: the per-bone rule on the core bones
## and both prop bones, and the upper aim weight falling monotonically.
func _shot_cancel(ctx: AnimTestContext) -> void:
	var bad := 0
	var cases := 0
	var nonmono := 0
	var worst := 0.0
	var worst_at := ""
	var lines := []
	for w in ["musket", "pistol", "bow"]:
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": w}):
			return
		_hook(ctx, h)
		_scope = "both"
		for c: Array in [["still", Vector2.ZERO, 0.0], ["running", Vector2(0, 1), 3.6]]:
			for i in SETTLE_FRAMES:
				await _frame(ctx, h, c[1], c[2])
			for k in [4, 9, 15, 24, 40]:
				var st := _measure_state(h)
				h.aiming = true
				for i in k:
					if w == "bow":
						h.charge = minf(h.charge + h.dt / 0.6, 1.0)
					await _frame(ctx, h, c[1], c[2])
					_measure(h, st, "raise f%d" % i)
				var aim0: float = h.aim
				# The cancel: no fired event; the weapon lowers (the bow's draw unwinds).
				h.aiming = false
				h.charge = 0.0
				var prev_w: float = h.anim.upper.upper_aim_w()
				for i in 50:
					await _frame(ctx, h, c[1], c[2])
					_measure(h, st, "cancel k%d f%d" % [k, i])
					var uw: float = h.anim.upper.upper_aim_w()
					if uw > prev_w + 1e-6:
						nonmono += 1
					prev_w = uw
				cases += 1
				bad += int(st.over)
				for l in st.lines:
					if lines.size() < 12:
						lines.append("%s %s cancel %d frames into the raise (aim %.2f) %s" % [w, c[0], k, aim0, l])
				if float(st.m) > worst:
					worst = float(st.m)
					worst_at = "%s %s k=%d %s" % [w, c[0], k, st.mb]
				for i in 20:
					await _frame(ctx, h, c[1], c[2])
		_scope = "core"
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)
	for l in lines:
		ctx.info("  over " + l)
	ctx.info("shot cancel: %d cases, worst %.1f rad/s (%s)" % [cases, worst, worst_at])
	ctx.check(nonmono == 0, "shot cancel: the upper aim weight falls monotonically after the cancel (%d rising frames)" % nonmono)
	ctx.check(bad == 0, "shot cancel (musket, pistol; bow let-down) 4..40 frames into the raise, still and running (%d cases), core bones and both prop bones: %d frames over the per-bone rule (worst %.1f rad/s, %s)" % [
			cases, bad, worst, worst_at])


## WP7: weapon switches as player.gd switch_weapon() plays them with the graph holster (options.holster,
## graph default): the old weapon's action_cancelled (Weapon.unequip()) and play_holster(old, h), the
## inputs report the new weapon (aim 0) at once; at the holster's end set_weapon and the old weapon's
## holster finish, then the new weapon's grab, then its draw over its equip_time (_holster_switch).
## Every pair of weapons, standing and running, lowered and raised at the switch; then a further
## switch 2..16 frames into the draw.
func _holster_switches(ctx: AnimTestContext) -> void:
	var pairs := [["musket", "bow"], ["bow", "musket"], ["musket", "pistol"], ["pistol", "musket"], ["bow", "pistol"],
			["pistol", "bow"]]
	var only := String(ctx.arg("pairs", "")).split(",", false)
	if not only.is_empty():
		pairs = pairs.filter(func(p: Array) -> bool: return "%s-%s" % p in only)
	var bad := 0
	var named := 0
	var cases := 0
	var worst := 0.0
	var worst_at := ""
	var lines := []
	for p: Array in pairs:
		var h = FacadeRig.new()
		if not h.setup(ctx, {"weapon": p[0]}):
			return
		_hook(ctx, h)
		_scope = "visible"
		_vis_prop = -2
		var third: String = ["bow", "musket", "pistol"].filter(func(x): return not x in p)[0]
		var runs := []
		for c: Array in [["still", Vector2.ZERO, 0.0], ["running", Vector2(0, 1), 3.6]]:
			for raised in [false, true]:
				runs.append([c, raised, 0])
		for k in [2, 6, 10, 16]:
			runs.append([["running", Vector2(0, 1), 3.6], false, k])
		for r: Array in runs:
			var c: Array = r[0]
			h.aiming = bool(r[1])
			for i in SETTLE_FRAMES:
				if h.aiming and h.weapon == "bow":
					h.charge = minf(h.charge + h.dt / 0.6, 1.0)
				await _frame(ctx, h, c[1], c[2])
			var st := _measure_state(h)
			var tag := "%s->%s %s%s" % [p[0], p[1], c[0], " raised" if r[1] else ""]
			var draw_s: float = await _holster_switch(ctx, h, p[1], c, st, tag)
			if int(r[2]) > 0:
				# player.gd: a switch while the weapon is still being drawn holsters it from where
				# its draw is (the draw's OneShot reversed in place).
				var frac := clampf(int(r[2]) * float(h.dt) / maxf(draw_s, 1e-3), 0.0, 1.0)
				tag += ", ->%s %d frames into the draw (%.0f %% drawn)" % [third, r[2], frac * 100.0]
				for i in int(r[2]):
					await _frame(ctx, h, c[1], c[2])
					_measure(h, st, "draw f%d" % i)
				await _holster_switch(ctx, h, third, c, st, tag, frac)
			for i in INTERRUPT_FRAMES:
				await _frame(ctx, h, c[1], c[2])
				_measure(h, st, "draw f%d" % i)
			cases += 1
			bad += int(st.over)
			named += int(st.kicks)
			for l in st.lines:
				if lines.size() < int(ctx.arg("max_lines", 16)):
					lines.append("%s %s" % [tag, l])
			if float(st.m) > worst:
				worst = float(st.m)
				worst_at = "%s %s" % [tag, st.mb]
			h.aiming = false
			h.charge = 0.0
			h.switch(p[0])
			for i in SETTLE_FRAMES:
				await _frame(ctx, h, c[1], c[2])
		ctx.info("holster switch %s->%s: long-way prop frames %d" % [p[0], p[1], h.anim.upper.prop_guard.flipped_frames()])
		_scope = "core"
		_unhook()
		h.rig.root.queue_free()
		await ctx.idle_frames(2)
	for l in lines:
		ctx.info("  over " + l)
	ctx.metric("holster_switch_worst_rad_s", worst)
	ctx.info("holster switches: %d frames needed a named term (carry-layer change or fire kick)" % named)
	ctx.check(bad == 0, "holster switches (%d pairs, still / running, lowered / raised, and a further switch 2..16 frames into the draw; %d cases), core bones and the prop bone with a model: %d frames over the per-bone rule (worst %.1f rad/s, %s)" % [
			pairs.size(), cases, bad, worst, worst_at])


## One switch as player.gd plays it (see _holster_switches; FrontierPlayer.switch_stages() and the
## stage times of _plan_switch(), stepped as _tick_switch() does), measured frame by frame into
## `st`: the old weapon's holster, its holster finish, the new weapon's grab, then its equip draw.
## `drawn_frac` < 1: the old weapon's draw has played only that much (its holster is that much of
## the full one, reversed from where the draw is). Returns the draw's duration.
func _holster_switch(ctx: AnimTestContext, h, key: String, c: Array, st: Dictionary, tag: String, drawn_frac := 1.0) -> float:
	var old: String = h.weapon
	var draw_s: float = h.weapons[key].equip_time
	var stance := "crouch" if h.crouched else "stand"
	var s := FrontierPlayer.switch_stages(h.anim.data, old, key, stance, h.weapons[old].equip_time, draw_s)
	s.holster = float(s.holster) * drawn_frac
	var plan := FrontierPlayer._plan_switch(s)
	h.weapons[old].action_cancelled.emit()
	h.aiming = false
	h.charge = 0.0
	if float(s.holster) > 0.0 and h.anim.play_holster(old, float(s.holster)):
		h.weapon = key
		h.aim = 0.0
		# The old model stays in the hand through the holster, then none until the draw.
		var ow: Weapon = h.weapons.get(old)
		_vis_prop = int(_prop.get(ow.hand if ow != null else Weapon.Hand.RIGHT, -1))
		var t := 0.0
		var holstered := false
		var grabbing := false
		while true:
			await _frame(ctx, h, c[1], c[2])
			var stage := "grab" if grabbing else ("finish" if holstered else "holster")
			_measure(h, st, "%s %s f%d" % [tag, stage, roundi(t / h.dt)])
			t += h.dt
			var tt := t + 1e-4
			if not holstered and tt >= float(plan.t_finish):
				holstered = true
				_vis_prop = -1
				h.anim.set_weapon(key)
				if float(plan.finish) > 0.0:
					h.anim.play_switch_stage(old, "holster_finish", float(plan.finish))
			if holstered and not grabbing and tt >= float(plan.t_grab) and float(plan.grab) > 0.0 and tt < float(plan.t_draw):
				grabbing = true
				h.anim.play_switch_stage(key, "grab", float(plan.grab))
			if holstered and tt >= float(plan.t_draw):
				break
	else:
		h.weapon = key
		h.aim = 0.0
		h.anim.set_weapon(key)
	_vis_prop = -2
	h.weapons[key].action_started.emit("equip", draw_s)
	return draw_s


## A measurement from the current frame on (the named terms' history primed on it).
func _measure_state(h) -> Dictionary:
	_track_frame(h)
	return {"prev": _post.duplicate(), "m": 0.0, "mb": "", "over": 0, "lines": [], "kicks": 0}


## One measured frame (after _frame) under the per-bone rule (bones in _scope), into `st`.
func _measure(h, st: Dictionary, tag: String) -> void:
	_track_frame(h)
	var prev: Array[Quaternion] = st.prev
	var j := _judge(h, prev, _post, h.dt, 0.0, 0.0)
	st.prev = _post.duplicate()
	if String(j.kick) != "":
		st.kicks = int(st.kicks) + 1
	if bool(j.over):
		st.over = int(st.over) + 1
		if (st.lines as Array).size() < 6:
			st.lines.append("%s %s %.1f rad/s, its allowance %.1f (%s) | %s/%s | %s" % [tag, j.ex_bone, float(j.ex_speed),
					float(j.ex_speed) - float(j.excess), j.by, h.anim.loco.state, h.anim.loco.graph_state, _shots(h)])
	if float(j.speed) > float(st.m):
		st.m = j.speed
		st.mb = "%s %s allowed %.1f%s" % [j.bone, tag, float(j.allow), (" by " + String(j.by)) if String(j.by) != "" else ""]


func _measure_row(st: Dictionary) -> String:
	return "worst %.1f rad/s (%s), %d frames over the rule%s" % [
			float(st.m), st.mb, int(st.over), (", %d frames within the named terms" % int(st.kicks)) if int(st.kicks) > 0 else ""]


func _shots(h) -> String:
	var sh := []
	for o: Dictionary in h.anim.upper.snapshot().active_oneshots:
		sh.append("%s@%.2f w%.2f" % [String(o.clip).trim_prefix("actor_b-"), float(o.position), _oneshot_weight(h.anim, String(o.node))])
	return ", ".join(sh)


func _run_measured(ctx: AnimTestContext, h, st: Dictionary, n: int, tag: String) -> void:
	for i in n:
		await _frame(ctx, h, Vector2(0, 1), 3.6)
		_measure(h, st, "%s f%d" % [tag, i])


# --- 2. storm ---------------------------------------------------------------------------------------

func _cls() -> Dictionary:
	return {"n": 0, "max": 0.0, "at": ""}


func _storm(ctx: AnimTestContext, h, g, cfg: Dictionary, minutes: float) -> void:
	var label := String(cfg.label)
	var strict := bool(cfg.strict)
	var idx: TreeIndex = h.anim.index
	var turn := []
	for id in idx.L_inputs:
		var grp := String(idx.lower_record(StringName(id)).get("group", ""))
		if grp.begins_with("turn") or grp.begins_with("quick_turn"):
			turn.append(StringName(id))
	var trans := []
	var on_trans := func(_f: StringName, _t: StringName, info: Dictionary) -> void: trans.append(info)
	h.anim.anim_transition.connect(on_trans)
	# `stages=1`: a probe after each modifier (StageProbe), so each counted frame names the modifier that
	# moved its bone
	var probes: Array = StageProbe.insert(_sk, _core) if bool(int(ctx.arg("stages", 0))) else []
	var prev_stage := []
	for i in 30:
		await _frame(ctx, h)
	for d: Dictionary in probes:
		prev_stage.append((d.probe.rots as Array).duplicate())
	var prev := _post.duplicate()
	var prev_pre := _pre()
	var frames := int(minutes * 3600.0)
	var cls := {"counted": _cls(), "authored": _cls(), "named": _cls(), "revive": _cls()}
	var stale := 0
	var worst := 0.0
	var turn_frames := 0
	var dt: float = h.dt
	var charge_pos_prev := 0.0
	var tr := String(ctx.arg("trace", "")).split("-")
	var trace_from := int(tr[0]) if tr.size() == 2 and not strict else -1
	var trace_to := int(tr[1]) if tr.size() == 2 and not strict else -2
	var counted_lines := []
	var named_kick := 0
	var named_layer := 0
	var prop := {"n": 0, "max": 0.0, "at": "", "lines": [], "worst": 0.0}
	for i in frames:
		trans.clear()
		var ex: Dictionary = g.tick()
		h.step(g.wish(), g.speed(), ex)
		_set_weapon_prop(h)
		var pre := _pre()
		var n := _updates
		await ctx.idle_frames(1)
		if _updates == n:
			await ctx.idle_frames(1)
			if _updates == n:
				stale += 1
		var charge_pos := _charge_pos(h)
		var charge_prev := charge_pos_prev
		charge_pos_prev = charge_pos
		_track_frame(h)
		var cache := {}
		_scope = "prop"
		var jp := _judge(h, prev, _post, dt, charge_prev, charge_pos, cache)
		prop.worst = maxf(float(prop.worst), float(jp.speed))
		if bool(jp.over) and not ex.has("revive"):
			prop.n += 1
			var pl := "f%d %.1f rad/s %s allowed %.1f%s | %s" % [i, float(jp.ex_speed), jp.ex_bone, float(jp.allow),
					(" by " + String(jp.by)) if String(jp.by) != "" else "", _context(h, trans)]
			if (prop.lines as Array).size() < 12:
				prop.lines.append(pl)
			if float(jp.ex_speed) > float(prop.max):
				prop.max = jp.ex_speed
				prop.at = pl
		_scope = "core"
		var j := _judge(h, prev, _post, dt, charge_prev, charge_pos, cache)
		var sp := _speed(prev_pre, pre, dt)
		prev = _post.duplicate()
		prev_pre = pre
		var stage_rows := []
		if not probes.is_empty():
			stage_rows = [prev_stage.duplicate(), []]
			prev_stage = []
			for d: Dictionary in probes:
				prev_stage.append((d.probe.rots as Array).duplicate())
			stage_rows[1] = prev_stage
		var rate: float = j.speed
		worst = maxf(worst, rate)
		var tw := 0.0
		for id in turn:
			tw = maxf(tw, h.anim.L.weight(id))
		if tw > 0.0:
			turn_frames += 1
		if i >= trace_from and i <= trace_to:
			ctx.info("  trace f%d %.1f %s (pre %.1f) | %s%s" % [i, rate, j.bone, sp[0], _context(h, trans),
					(" | stages " + _stage_speeds(probes, stage_rows[0], stage_rows[1], _core_names.find(String(j.bone)), dt))
					if not stage_rows.is_empty() else ""])
		if rate <= LIMIT:
			continue
		var what := "authored"
		if ex.has("revive"):
			what = "revive"
		elif bool(j.over):
			what = "counted"
		elif String(j.kick) != "":
			what = "named"
			if String(j.kick).contains("fire kick"):
				named_kick += 1
			if String(j.kick).contains("carry-layer"):
				named_layer += 1
		var c: Dictionary = cls[what]
		c.n += 1
		var b := String(j.ex_bone) if bool(j.over) else String(j.bone)
		var v: float = float(j.ex_speed) if bool(j.over) else rate
		var line := "f%d %.1f rad/s %s (pre-modifier %.1f %s) its allowance %.1f%s%s | %s" % [i, v, b, sp[0], sp[1],
				float(j.allow), (" by " + String(j.by)) if String(j.by) != "" else "",
				(" + " + String(j.kick)) if String(j.kick) != "" else "", _context(h, trans)]
		if not stage_rows.is_empty() and what == "counted":
			line += " | stages " + _stage_speeds(probes, stage_rows[0], stage_rows[1], _core_names.find(b), dt)
		if what == "counted" and counted_lines.size() < 40:
			counted_lines.append(line)
		if v > c.max:
			c.max = v
			c.at = line
	h.anim.anim_transition.disconnect(on_trans)
	StageProbe.remove(probes)
	ctx.check(_nonfinite == 0, "%s: %d frames (%.1f min) without NaN / INF in any bone pose (%d)" % [label, frames, minutes, _nonfinite])
	ctx.check(stale == 0, "%s: the skeleton updated (the modifiers ran) after every frame (%d stale)" % [label, stale])
	ctx.metric("worst_rad_s_" + ("strict" if strict else "default"), worst)
	for l in counted_lines:
		ctx.info("  counted " + l)
	var counted: Dictionary = cls.counted
	ctx.check(counted.n == 0, "%s: %d frames where a core bone turns faster than %.0f rad/s + its own authored allowance (visible pose), revive frame apart (worst %s)" % [
			label, counted.n, LIMIT, counted.at if counted.at != "" else "-"])
	for k in ["authored", "named", "revive"]:
		var cc: Dictionary = cls[k]
		ctx.info("%s: allowed %-8s %4d frames over %.0f, max %.1f%s" % [label, k, cc.n, LIMIT, cc.max, (" (" + cc.at + ")") if cc.at != "" else ""])
	ctx.info("%s: named terms used on %d frames: fire kick onset %d, carry-layer change %d (a frame can need both)" % [
			label, int(cls.named.n), named_kick, named_layer])
	if strict:
		ctx.check(turn_frames == 0, "%s: no idle-turn input is ever weighted with override_no_idle_turns (%d frames)" % [label, turn_frames])
	ctx.info("%s: worst frame overall %.1f rad/s; frames with an idle-turn input weighted: %d" % [label, worst, turn_frames])
	for l in prop.lines:
		ctx.info("  weapon prop " + l)
	ctx.metric("weapon_prop_frames_" + ("strict" if strict else "default"), prop.n)
	_prop_report(ctx, label, prop)


## `stages=1`: bone `bi`'s speed (rad/s) after each stage of the modifier stack this frame (StageProbe; "tree"
## is the AnimationTree's pose), e.g. "tree 24.9, AimStabilizer 24.9, LeftGripIK 125.7": the stage where it
## jumps is the modifier that moved it.
func _stage_speeds(probes: Array, a: Array, b: Array, bi: int, dt: float) -> String:
	if bi < 0 or a.size() != probes.size() or b.size() != probes.size():
		return "-"
	var parts := []
	var last := -1.0
	for k in probes.size():
		var ra: Array = a[k]
		var rb: Array = b[k]
		if bi >= ra.size() or bi >= rb.size():
			continue
		var v := PoseOracle.qdist(ra[bi], rb[bi]) / dt
		if absf(v - last) > 0.05 or k == 0:
			parts.append("%s %.1f" % [String(probes[k].name), v])
		last = v
	return ", ".join(parts)


## The prop bone that carries the weapon model (reported in the storm, not failed).
func _prop_report(ctx: AnimTestContext, label: String, prop: Dictionary) -> void:
	ctx.info("%s: weapon prop bone: %d frames over %.0f rad/s + its own authored allowance, worst %.1f%s" % [label,
			prop.n, LIMIT, float(prop.max), (" (" + String(prop.at) + ")") if String(prop.at) != "" else ""])


## One line of frame context for the report.
func _context(h, trans: Array) -> String:
	var anim: PlayerAnim = h.anim
	var tl := []
	for t: Dictionary in trans:
		tl.append("%s %s->%s fade %s" % [t.get("key", ""), t.get("from_graph", ""), t.get("to_graph", ""), t.get("fade_used", "")])
	var sh := []
	for o: Dictionary in anim.upper.snapshot().active_oneshots:
		sh.append("%s@%.2f r%.2f w%.2f" % [String(o.clip).trim_prefix("actor_b-"), float(o.position), float(o.rate), _oneshot_weight(anim, String(o.node))])
	var lw := []
	var ws: Dictionary = anim.L.weights()
	for id in ws:
		if float(ws[id]) > 0.0:
			lw.append("%s %.2f" % [id, float(ws[id])])
	var st: AimStabilizer = anim.stabilizer
	var si: StanceInertializer = anim.inertializer
	return "%s/%s w %s aim %.2f crouch %s | trans [%s] | shots [%s] | L [%s] | draw %.2f on %.2f | stab w %.2f c %.0f applied %.0f | inert %s" % [
			anim.loco.state, anim.loco.graph_state, h.weapon, h.aim, h.crouched, ", ".join(tl), ", ".join(sh), ", ".join(lw),
			float(anim.upper.snapshot().charge), float(anim.get(anim.index.charge.add)) if anim.index.charge.has("add") else 0.0,
			st.weight if st.active else 0.0, st.last_correction_deg(), st.last_applied_deg() if st.active else 0.0,
			("%.2f s left of %.2f, #%d, %d bones" % [si.remaining(), si.duration, si.started, si.active_bones]) if si != null and si.running() else "-"]


# --- authored speed of the clips playing ----------------------------------------------------------

## Per bone (index in _core): the largest (own skeleton-space speed of that bone over the clip time
## played this frame) x blend weight over the clips playing, the clip it comes from, and the named
## kick exemption (KICKS): {v, by, kick, kick_by}.
func _allowance(h, dt: float, charge_prev: float, charge_pos: float) -> Dictionary:
	var anim: PlayerAnim = h.anim
	var idx: TreeIndex = anim.index
	var nb := _core_chain.size()
	var best := PackedFloat32Array()
	best.resize(nb)
	var by := []
	by.resize(nb)
	by.fill("")
	var kick := PackedFloat32Array()
	kick.resize(nb)
	var kick_by := []
	kick_by.resize(nb)
	kick_by.fill("")
	# Lower body: the blend-weighted sum of its inputs' own speeds (a crossfade moves no faster than
	# that plus the crossfade itself; with the weights summing to 1 it never exceeds the fastest
	# input's own speed). A bank hemisphere counts its fastest direction clip per bone.
	var ws: Dictionary = anim.L.weights()
	var lower := PackedFloat32Array()
	lower.resize(nb)
	var lower_by := []
	for id in ws:
		var w := float(ws[id])
		if w <= 0.0:
			continue
		var rec := idx.lower_record(StringName(id))
		if rec.is_empty():
			continue
		if rec.has("hemis"):
			for hk in rec.hemis:
				var hr: Dictionary = rec.hemis[hk]
				var hw := _hemi_weight(anim, rec, String(hk))
				if hw <= 0.0:
					continue
				var u := float(anim.get(hr.position_node)) if hr.has("position_node") else 0.0
				var ts := float(anim.get(hr.ts)) if hr.has("ts") else 0.0
				var hv := PackedFloat32Array()
				hv.resize(nb)
				for k in 3:
					var clip := String(hr.clips[k])
					if clip == "":
						continue
					var length := float(hr.lengths[k])
					var v := _clip_vec(clip, u * length, ts * length * dt, bool(hr.loop), dt)
					for i in nb:
						hv[i] = maxf(hv[i], v[i])
				for i in nb:
					lower[i] += hv[i] * w * hw
				lower_by.append("%s %.2f" % [String(hr.clips[0]).trim_prefix("actor_b-"), w * hw])
		else:
			var clip := String(rec.get("clip", ""))
			if clip == "":
				continue
			var length := float(rec.get("length", 0.0))
			var u := float(anim.get(rec.position_node)) if rec.has("position_node") else 0.0
			var ts := float(anim.get(rec.ts)) if rec.has("ts") else 0.0
			var v := _clip_vec(clip, u * length, ts * length * dt, bool(rec.get("loop", false)), dt)
			for i in nb:
				lower[i] += v[i] * w
			lower_by.append("%s %.2f" % [clip.trim_prefix("actor_b-"), w])
	var lower_label := "lower body [%s]" % ", ".join(lower_by)
	for i in nb:
		best[i] = lower[i]
		by[i] = lower_label
	# Upper-body OneShots.
	for o: Dictionary in anim.upper.snapshot().active_oneshots:
		var rec: Dictionary = idx.oneshots.get(String(o.node), {})
		if rec.is_empty():
			continue
		var w := _oneshot_weight(anim, String(o.node))
		# The rate the tree plays it at (a held holster runs at TimeScale 0 whatever its act's rate).
		var o_rate := float(anim.get(rec.scale)) if rec.get("scale", &"") != &"" else float(o.rate)
		var v := _clip_vec(String(o.clip), float(o.position), absf(o_rate) * dt, bool(rec.get("loop", false)), dt, signf(o_rate))
		var label := "%s w %.2f" % [o.clip, w]
		for i in nb:
			if v[i] * w > best[i]:
				best[i] = v[i] * w
				by[i] = label
		# Named kick: a fire additive's fade-in onset (its first frame is the recoil).
		if KICKS.has(String(rec.chain)):
			var gained := float(_kick_gain.get(String(o.node), 0.0))
			if gained > 0.0:
				var bv := _bind_vec(String(o.clip), float(o.position))
				for i in nb:
					var kv := bv[i] * gained / dt
					if kv > kick[i]:
						kick[i] = kv
						kick_by[i] = "%s (%s)" % [KICKS[String(rec.chain)], o.clip]
	# Named: carry-layer change (see the header).
	var layer := PackedFloat32Array()
	layer.resize(nb)
	for p in _layer_delta:
		var th := _layer_theta(_layer_delta[p][1])
		var dd := float(_layer_delta[p][0])
		for i in nb:
			layer[i] += th[i] * dd / dt
	# The bow draw (charge additive, seeked by the gameplay's draw amount).
	if idx.charge.has("add"):
		var amt := float(anim.get(idx.charge.add))
		if amt > 0.0 and absf(charge_pos - charge_prev) > 0.0:
			for st in idx.charge.clips:
				var clip := String(idx.charge.clips[st])
				var length := float(idx.charge.lengths.get(st, 0.0))
				var v := _pair_vec(clip, charge_prev * length, charge_pos * length, dt)
				var label := "%s (draw) w %.2f" % [clip, amt]
				for i in nb:
					if v[i] * amt > best[i]:
						best[i] = v[i] * amt
						by[i] = label
	return {"v": best, "by": by, "kick": kick, "kick_by": kick_by, "layer": layer}


## The bow draw's shown position (UpperBody seeks the held-draw clip by it).
func _charge_pos(h) -> float:
	return clampf(float(h.anim.upper.snapshot().get("charge_on", 0.0)), 0.0, 1.0)


func _hemi_weight(anim: PlayerAnim, rec: Dictionary, hemi: String) -> float:
	if not rec.has("hemi_param"):
		return 1.0
	var b := float(anim.get(rec.hemi_param))
	var keys: PackedStringArray = rec.get("hemi_inputs", PackedStringArray())
	if keys.size() < 2:
		return 1.0
	return 1.0 - b if hemi == keys[0] else b


## Fade weight of a OneShot (linear fades).
func _oneshot_weight(anim: PlayerAnim, n: String) -> float:
	var rec: Dictionary = anim.index.oneshots.get(n, {})
	if rec.is_empty() or not bool(anim.get(rec.active)):
		return 0.0
	var fade: Array = rec.get("fade", [0.0, 0.0])
	var fi := float(anim.get("parameters/%s/fade_in_remaining" % n))
	var fo := float(anim.get("parameters/%s/fade_out_remaining" % n))
	var w := 1.0
	if fi > 0.0 and float(fade[0]) > 0.0:
		w = minf(w, 1.0 - fi / float(fade[0]))
	if fo > 0.0 and float(fade[1]) > 0.0:
		w = minf(w, fo / float(fade[1]))
	return clampf(w, 0.0, 1.0)


## Every measured frame, after the advance: the named terms' inputs (_track_kicks, _track_layers).
func _track_frame(h) -> void:
	_track_kicks(h)
	_track_layers(h)


## The effective amount of every carry layer of the weighted lower inputs, and its change since
## the last frame.
func _track_layers(h) -> void:
	var anim: PlayerAnim = h.anim
	var idx: TreeIndex = anim.index
	var now := {}
	var ws: Dictionary = anim.L.weights()
	for id in ws:
		var w := float(ws[id])
		if w <= 0.0:
			continue
		var rec := idx.lower_record(StringName(id))
		for l: Dictionary in rec.get("layers", []):
			if l.param == &"" or bool(l.shared):
				continue
			var hw := 1.0
			var base := String(rec.get("clip", ""))
			var blen := float(rec.get("length", 0.0))
			var u := float(anim.get(rec.position_node)) if rec.has("position_node") else 0.0
			if String(l.hemi) != "":
				hw = _hemi_weight(anim, rec, String(l.hemi))
				var hr: Dictionary = rec.get("hemis", {}).get(String(l.hemi), {})
				if not hr.is_empty():
					base = String(hr.clips[0])
					blen = float(hr.lengths[0])
					u = float(anim.get(hr.position_node)) if hr.has("position_node") else 0.0
			now[l.param] = [w * hw * float(anim.get(l.param)), [String(l.clip), String(l.kind), base, u, blen]]
	_layer_delta = {}
	var dt: float = h.dt
	for p in now:
		var e0 := float(_layer_prev[p][0]) if _layer_prev.has(p) else 0.0
		var e1 := float(now[p][0])
		var d := minf(absf(e1 - e0), maxf(e0, e1) * dt / LAYER_FADE_MIN_S)
		if d > 1e-6:
			_layer_delta[p] = [d, now[p][1]]
	for p in _layer_prev:
		var e0 := float(_layer_prev[p][0])
		if not now.has(p) and e0 > 1e-6:
			_layer_delta[p] = [e0 * minf(1.0, dt / LAYER_FADE_MIN_S), _layer_prev[p][1]]
	_layer_prev = now


## Per index: a carry layer's chain angle (partial: against the base clip on the bones it keys;
## additive: from the bind pose), at normalized phase u.
func _layer_theta(c: Array) -> PackedFloat32Array:
	var key := "%s|%s|%.4f" % [c[0], c[2], float(c[3])]
	if _theta_cache.has(key):
		return _theta_cache[key]
	var la := _oracle.animation(String(c[0]))
	var out := PackedFloat32Array()
	out.resize(_core_chain.size())
	if la == null:
		return out
	var lp := _oracle.clip(String(c[0]), float(c[3]) * la.length)
	var bp: PoseOracle.Pose = null
	if String(c[1]) != "additive" and String(c[2]) != "":
		bp = _oracle.clip(String(c[2]), float(c[3]) * float(c[4]))
	var d := PackedFloat32Array()
	d.resize(_chain_order.size())
	for i in _chain_order.size():
		var b := _chain_order[i]
		if lp.kr[b] == 0:
			continue
		d[i] = PoseOracle.qdist(bp.r[b] if bp != null else _rest_r[b], lp.r[b])
	for k in _core_chain.size():
		var sm := 0.0
		for i in _core_chain[k]:
			sm += d[i]
		out[k] = sm
	if _theta_cache.size() > 5000:
		_theta_cache.clear()
	_theta_cache[key] = out
	return out


## Every frame after the advance: the fade-in weight each KICKS OneShot gained in it (Godot's
## OneShot blends at (fade - fade_in_remaining) / fade with the remaining time before the advance,
## i.e. the value after the previous one; the FIRE frame plays the shot at weight 0).
func _track_kicks(h) -> void:
	var anim: PlayerAnim = h.anim
	var hist := {}
	_kick_gain = {}
	for n: String in _kick_nodes:
		var rec: Dictionary = anim.index.oneshots[n]
		if not bool(anim.get(rec.active)):
			continue
		var fade := float(rec.fade[0])
		var last: Variant = _fade_hist.get(n)
		var blend := 1.0
		if last == null:
			blend = 0.0
		elif float(last[0]) > 0.0 and fade > 0.0:
			blend = (fade - float(last[0])) / fade
		hist[n] = [float(anim.get(_kick_nodes[n])), blend]
		var before := float(last[1]) if last != null else 0.0
		if blend > before:
			_kick_gain[n] = blend - before
	_fade_hist = hist


## Own speed (rad/s) per bone of `clip` over the clip time `step` that ended at `t` (direction `sgn`).
func _clip_vec(clip: String, t: float, step: float, loop: bool, dt: float, sgn := 1.0) -> PackedFloat32Array:
	if step <= 0.0:
		var z := PackedFloat32Array()
		z.resize(_core_chain.size())
		return z
	var a := _oracle.animation(clip)
	if a == null:
		var z := PackedFloat32Array()
		z.resize(_core_chain.size())
		return z
	var t0 := t - step * sgn
	if loop and a.length > 0.0:
		t0 = fposmod(t0, a.length)
	else:
		t0 = clampf(t0, 0.0, a.length)
	return _pair_vec(clip, t0, clampf(t, 0.0, a.length), dt)


## Per bone: the most `clip`'s own motion between clip times t0 and t1 can turn that bone in
## skeleton space, per dt: the angles its channels turn, summed along the bone's parent chain (a
## bound whatever the pose under it; the clip evaluated over the bind pose can be slower when its
## channels turn against each other).
func _pair_vec(clip: String, t0: float, t1: float, dt: float) -> PackedFloat32Array:
	var a := _clip_locals(clip, t0)
	var b := _clip_locals(clip, t1)
	var d := PackedFloat32Array()
	d.resize(_chain_order.size())
	for i in _chain_order.size():
		d[i] = PoseOracle.qdist(a[i], b[i])
	var out := PackedFloat32Array()
	out.resize(_core_chain.size())
	for k in _core_chain.size():
		var s := 0.0
		for i in _core_chain[k]:
			s += d[i]
		out[k] = s / dt
	return out


## Per bone: the clip's chain angle from the bind pose at clip time t (an additive clip's delta).
func _bind_vec(clip: String, t: float) -> PackedFloat32Array:
	var key := "%s|%.5f" % [clip, t]
	if _bind_cache.has(key):
		return _bind_cache[key]
	var a := _clip_locals(clip, t)
	var d := PackedFloat32Array()
	d.resize(_chain_order.size())
	for i in _chain_order.size():
		d[i] = PoseOracle.qdist(_rest_r[_chain_order[i]], a[i])
	var out := PackedFloat32Array()
	out.resize(_core_chain.size())
	for k in _core_chain.size():
		var s := 0.0
		for i in _core_chain[k]:
			s += d[i]
		out[k] = s
	if _bind_cache.size() > 5000:
		_bind_cache.clear()
	_bind_cache[key] = out
	return out


## The clip's local rotations of the chain bones at time t (rest where it has no key).
func _clip_locals(clip: String, t: float) -> Array[Quaternion]:
	var key := "%s|%.5f" % [clip, t]
	if _clip_cache.has(key):
		return _clip_cache[key]
	var pose := _oracle.clip(clip, t)
	var out: Array[Quaternion] = []
	for b in _chain_order:
		out.append(pose.r[b])
	if _clip_cache.size() > 20000:
		_clip_cache.clear()
	_clip_cache[key] = out
	return out
