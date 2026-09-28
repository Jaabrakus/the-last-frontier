extends AnimTestSuite
## THROW work package: the thrown weapons (spear, tomahawk, atlatl) in the player's roster and the
## character performing the graph's throw (throwables_design.md 3.2-3.5; ThrowChain), in the real
## level with the real input path (hold LMB to wind up, release to throw).
##
## 1. Roster and data: keys 4-6 (weapon_4..weapon_6) select spear / tomahawk / atlatl, the wheel
##    cycles all six; the weapons are balanced (WeaponBalance, hooks H1 / H2), PlayerAnim knows their
##    graph profiles (pick-up weapon base, clip set "throw") and drives their release
##    (wait_for_anim_release); the throw rows play the graph's clips; one arc (the player's
##    TrajectoryPreview draws the thrown weapons' arc, no ThrowableArc); the charge-seeked wind-up
##    raise is an opt-in gameplay override, off by default on the player and on PlayerAnim.
## 2. Every weapon standing, crouched and walking, with the graph-faithful defaults:
##    - the wind-up is the graph's aim-in: the throw chain stays NONE (weight 0) while the aim tree
##      (the weapon's clip-set throw aim input for the stance) comes in at Weapon.aim, and at full
##      charge it holds the cocked pose;
##    - the throw enters release-start from the aim over the graph's request "throw" record
##      (throw_from_aimidle 0x00037fb0 standing / crouched, throw_from_aimrun 0x00030930 walking)
##      and plays release-start -> release-end at Throwable.throw_anim_rate(), full body when
##      standing / crouched (TL weight > 0.99) and masked over the walk (TL 0); crouched throws play
##      the crouch clips;
##    - the release event comes once, at release-end phase in [release, release + one frame], and
##      the object leaves within one frame of it (Throwable `thrown`), from the object's centre of
##      mass in the hand (Throwable.launch_origin(), placed at the hand prop bone); the release lands
##      on release_time after LMB up within two frames;
##    - standing: release-end -> recover at phase 0.8 (+1 frame) -> out at recover phase 0.6
##      (graph records 0x000220b0 / 0x00032fa0); walking: the same chain on the upper body;
##    - the held object stays in the right hand (within HAND_TOL of the palm, final pose; the spear:
##      its shaft) on every frame it is shown from LMB up through the recover and the next one's
##      draw; in that draw it may instead be no further from the palm than the draw clip puts the
##      prop bone, plus SWITCH_MARGIN, as in 6 (Throwable.switch_path SOURCE: the spear on the
##      long-gun draw's own object path; THROW2 fix 2: the throw cycle's draw never takes that path to
##      the sling, so the next spear and tomahawk show in the hand from mid-draw, the clearance of
##      that draw is test_throw_switch_grip's); the atlatl's board is always shown;
##    - no NaN; the peak per-frame turn of the core bones is reported.
## 3. Let-down: RMB during the wind-up and sprinting during it lower the aim tree with Weapon.aim
##    (monotonic, over aim_out_time); the throw chain stays NONE and nothing is thrown.
## 4. The running quick throw: released while running with the aim still coming in, it enters
##    release-start from aim-run (throw_from_aimrun, request "throw"; no raise), and the animation's
##    release event (not the weapon's timer fallback) lets go.
## 5. A crouch toggle during release-start of a standing throw (release-start has no crouch exit):
##    held, it is taken on release-end's first frame (throw_end_crouch_change 0x000221a0, 0.5 s);
##    the throw's legs fade out over that 0.5 s from the toggle, so the lower body's crouch change
##    shows (the pelvis is down at least 0.15 m 0.6 s after the toggle; it used to stay standing for
##    about 1.3 s); the object is still thrown once, on the release event.
## 6. Weapon switch, bow -> each thrown weapon -> bow, standing: on every frame the thrown weapon is
##    shown it is within HAND_TOL of the right palm or no further from it than the playing graph
##    switch clips of the two weapons (holster, holster finish, grab, draw) put the prop bone, plus
##    SWITCH_MARGIN (their holster / sling positions: the long-gun draw starts with the spear
##    slung; the spear is measured by its shaft, which that path holds near the butt,
##    Throwable.source_hold); drawn and ready, and when the holster starts, it is in the hand.
## 7. PlayerAnim.override_throw_windup_raise (opt-in, Frontier-only), on at the next frame: the
##    wind-up plays the graph's raise seeked by the charge (phase = charge within 0.05) and hands over
##    to the aim tree at full charge; a let-down lowers the raise over the graph's aim-idle -> idle
##    0.6 s; the running quick throw plays the rest of the raise (RAISE_OUT) and enters the release
##    with fade 0 (throw_raise_to_start 0x00038830), released by the animation. Off again afterwards.
## Faster with --fixed-fps 120.

const WEAPONS := ["spear", "tomahawk", "atlatl"]
const MODES := ["stand", "crouch", "walk"]
const CORE := ["spinea", "spined", "neck", "heada", "r_clavicle", "r_shoulder", "r_elbow", "r_wrist", "l_shoulder",
		"l_elbow", "pelvis", "l_knee", "r_knee"]
## Largest distance (m) of the held object's origin from the right palm while the hand holds it (the
## objects sit 0.05-0.08 m out, at the prop bone plus their carry / aim offset).
const HAND_TOL := 0.15
## Margin (m) over where the playing graph switch clips put the prop bone (holster / sling positions).
const SWITCH_MARGIN := 0.05

var _player: FrontierPlayer
var _release_frames: Array = []
var _thrown_frames: Array = []
var _thrown: Array = []
## Final (post-modifier) pose of the last skeleton update, world space: r_palm, l_palm, pelvis.
var _final := {}


func describe() -> String:
	return "THROW: thrown weapons on keys 4-6, the graph throw chain (aim-in wind-up, release-start/-end, recover) standing / crouched / walking, release frame and launch point, object in the hand, let-down, running throw, crouch during the release, weapon switch, the opt-in wind-up raise"


func timeout_s() -> float:
	return 900.0


func run(ctx: AnimTestContext) -> void:
	# Another workflow's level script (scripts/world/env/environment_rig.gd) logs this in headless
	# runs; it is unrelated to the player animation.
	ctx.allow_error("on a base object of type 'Nil'")
	_player = await ctx.level()
	if _player == null:
		return
	var anim: PlayerAnim = _player.anim
	if anim == null or not anim.is_ready() or anim.upper.throw == null:
		ctx.fail("PlayerAnim has no throw chain (graph throw rows missing?)")
		return
	var sk := _player.skeleton
	var ids := {"r_palm": sk.find_bone("r_palm"), "l_palm": sk.find_bone("l_palm"), "pelvis": sk.find_bone("pelvis")}
	sk.skeleton_updated.connect(func() -> void:
		var d := {}
		for b in ids:
			d[b] = sk.global_transform * sk.get_bone_global_pose(ids[b]).origin
		_final = d)
	anim.throw_released.connect(func(k: StringName) -> void: _release_frames.append([Engine.get_physics_frames(), k,
			anim.upper.throw.part_phase("end")]))
	_roster(ctx, anim)
	for key in WEAPONS:
		var w: Throwable = _player.weapons[key]
		w.thrown.connect(func(p: ThrownProjectile) -> void:
			_thrown_frames.append(Engine.get_physics_frames())
			_thrown.append({"p": p, "origin": p.global_position, "com": w.launch_origin(), "hand": w._hand_pos(),
					"model": w.model.global_position if w.model else Vector3.INF, "key": key}))
	for key in WEAPONS:
		for mode in MODES:
			await _throw_case(ctx, key, mode)
	await _let_down(ctx, false)
	await _running_quick_throw(ctx, false)
	await _crouch_during_start(ctx)
	await _switch_hands(ctx)
	await _windup_override(ctx)


# --- helpers -------------------------------------------------------------------------------------

## Distance (m) of `w`'s shown model from the right palm on the final pose; -1 when not shown. A model
## with a shaft (Tip and Butt nodes: the spear) is measured by the shaft, which the hand, or in a switch
## the draw clip's object, may hold anywhere along its length (THROW2 review: Throwable.source_hold).
func _hand_dist(w: Weapon) -> float:
	if w == null or w.model == null or not w.model.visible or _final.is_empty():
		return -1.0
	var tip := w.model.get_node_or_null("Tip") as Node3D
	var butt := w.model.get_node_or_null("Butt") as Node3D
	if tip != null and butt != null:
		return _seg_point(_final.r_palm, tip.global_position, butt.global_position)
	return w.model.global_position.distance_to(_final.r_palm)


static func _seg_point(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## The latest ThrowChain trace entry of a state change into `to` ({} when none).
func _last_state(th: ThrowChain, to: String) -> Dictionary:
	var tr: Array = th.snapshot().get("trace", [])
	for k in range(tr.size() - 1, -1, -1):
		var e: Dictionary = tr[k]
		if String(e.get("kind", "")) == "state" and String(e.get("to", "")) == to:
			return e
	return {}


func _place(z := -24.0, yaw := 0.0) -> void:
	_player.global_position = Vector3(0.0, 0.3, z)
	_player.velocity = Vector3.ZERO
	_player.yaw = yaw
	_player.pitch = deg_to_rad(-3.0)


# --- 1. roster -----------------------------------------------------------------------------------

func _roster(ctx: AnimTestContext, anim: PlayerAnim) -> void:
	ctx.check(Array(_player.weapon_order.slice(0, 6)) == ["bow", "musket", "pistol", "spear", "tomahawk", "atlatl"],
			"roster order %s: keys 4-6 are spear, tomahawk, atlatl" % [_player.weapon_order])
	for i in range(3, 6):
		var slot := "weapon_%d" % (i + 1)
		var keyed := false
		var events: Array = InputMap.action_get_events(slot) if InputMap.has_action(slot) else []
		for e in events:
			if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_4 + (i - 3):
				keyed = true
		ctx.check(keyed, "%s is bound to key %d" % [slot, i + 1])
	for key in WEAPONS:
		var w: Throwable = _player.weapons.get(key)
		ctx.check(w != null and w.get_meta(&"balance_key", "") == key, "%s is in player.weapons and balanced (%s)" % [key, w.get_meta(&"balance_key", "") if w else "-"])
		if w == null:
			continue
		ctx.check(anim.graph_key(key) == key and anim.upper.throw.handles(StringName(key)), "%s: graph profile and throw chain" % key)
		ctx.check(w.wait_for_anim_release and is_equal_approx(w.anim_release_timeout, float(anim.data.tuning("throw_release_timeout_s", 0.35))),
				"%s: the animation drives the release (timeout %.2f s)" % [key, w.anim_release_timeout])
		var prof: Dictionary = anim.data.graph.profiles.get(key, {})
		ctx.check(String(prof.get("weapon-base", "")).ends_with("weapon-base-pick-up") and String(prof.get("clip_set", "")) == "throw",
				"%s: pick-up weapon base, clip set throw" % key)
		for st in ["stand", "crouch"]:
			var row: Dictionary = anim.data.graph.throw.rows.get("%s/%s" % [key, st], {}).get("parts", {})
			var c := "" if st == "stand" else "crouch-"
			ctx.check(String(row.get("start", {}).get("clip", "")) == "actor_b-p-1h-aim-%sthrow-release-start" % c
					and String(row.get("end", {}).get("clip", "")) == "actor_b-p-1h-aim-%sthrow-release-end" % c,
					"%s/%s throw rows play the graph's release-start / release-end" % [key, st])
			var d: Dictionary = anim.data.graph.actions.get("%s/%s/draw" % [key, st], {})
			ctx.check(String(d.get("pinned_from", "")) == "%s/%s/equip" % [key, st],
					"%s/%s: the next one's draw is the profile's own draw (%s)" % [key, st, d.get("pinned_from", "-")])
	ctx.check(_player.get_node_or_null("ThrowableArc") == null and _player.get_node_or_null("TrajectoryPreview") != null,
			"one arc: the player's TrajectoryPreview (no ThrowableArc on the roster path)")
	ctx.check(not bool(anim.data.option("throw_windup_raise", true)) and not anim.data.override_enabled("override_throw_windup_raise")
			and not anim.override_throw_windup_raise and not bool(_player.get("override_throw_windup_raise")),
			"graph-faithful wind-up by default: options.throw_windup_raise off; override_throw_windup_raise off on PlayerAnim and the player")


# --- 2. throws -------------------------------------------------------------------------------------

func _equip(ctx: AnimTestContext, key: String, crouch: bool) -> Throwable:
	if _player.is_crouching != crouch:
		Input.action_press("crouch")
		await ctx.frames(3)
		Input.action_release("crouch")
		await ctx.frames(30)
	var slot := "weapon_%d" % (_player.weapon_order.find(key) + 1)
	if _player.weapon_key != key:
		var ev := InputEventAction.new()
		ev.action = slot
		ev.pressed = true
		Input.parse_input_event(ev)
		await ctx.frames(2)
		var up := InputEventAction.new()
		up.action = slot
		up.pressed = false
		Input.parse_input_event(up)
	for i in 600:
		await ctx.frames(1)
		if _player.weapon_key == key and not _player.is_switching() and not _player.weapon.is_equipping():
			break
	var w := _player.weapon as Throwable
	if w == null:
		return null
	if w.count < w.max_count:
		w.add_items(w.max_count - w.count)
	for i in 600:
		if w.state == Throwable.State.READY:
			break
		await ctx.frames(1)
	await ctx.frames(20)
	return w


func _throw_case(ctx: AnimTestContext, key: String, mode: String) -> void:
	var tag := "%s/%s" % [key, mode]
	_place()
	var w := await _equip(ctx, key, mode == "crouch")
	if not ctx.check(w != null and _player.weapon_key == key, "%s: key %d selects %s" % [tag, _player.weapon_order.find(key) + 1, key]):
		return
	var anim: PlayerAnim = _player.anim
	var th: ThrowChain = anim.upper.throw
	var st := "crouch" if mode == "crouch" else "stand"
	if mode == "walk":
		Input.action_press("move_forward")
		await ctx.frames(40)
	# Wind-up: the graph's aim-in (the aim tree at Weapon.aim); the throw chain stays out of it.
	Input.action_press("fire")
	var chain_on := false
	for i in 400:
		await ctx.frames(1)
		if th.state != ThrowChain.NONE or th.weight() > 0.0:
			chain_on = true
		if w.state == Throwable.State.HOLDING:
			break
	await ctx.frames(30)
	var want_a := String(anim.index.aim.get("%s/%s" % [key, st], {}).get("input", ""))
	var us: Dictionary = anim.upper.snapshot()
	ctx.check(not chain_on and th.state == ThrowChain.NONE and th.weight() == 0.0,
			"%s: the wind-up is the graph's aim-in, no raise clip (throw chain %s, weight %.2f)" % [tag, th.state, th.weight()])
	ctx.check(float(us.upper_aim_w) >= 0.99 and want_a != "" and String(us.A.get("target", "")) == want_a,
			"%s: at full charge the aim tree holds the cocked pose (upper aim %.2f, aim input %s, want %s)" % [tag,
			float(us.upper_aim_w), us.A.get("target", ""), want_a])
	# Throw.
	_release_frames.clear()
	_thrown_frames.clear()
	_thrown.clear()
	var before := w.count
	var f0 := Engine.get_physics_frames()
	Input.action_release("fire")
	var saw := {}
	var lower_w := -1.0
	var start_node := ""
	var start_tr := {}
	var rec_phase := -1.0
	var exit_phase := -1.0
	var prev_state := th.state
	var peak := 0.0
	var peak_bone := ""
	var sk := _player.skeleton
	var prev := _globals(sk)
	var nan := false
	var drew := false
	var clips := _switch_clips(anim)
	var hand := {"shown": 0, "off": 0, "worst": 0.0, "allow": HAND_TOL, "at": ""}
	for i in 360:
		await ctx.frames(1)
		saw[String(th.state)] = true
		if w.state == Throwable.State.DRAWING:
			drew = true
		if th.state == ThrowChain.START and start_node == "":
			start_node = String(th.U.target())
			start_tr = _last_state(th, "START")
			lower_w = th.lower_w
			ctx.near(th.rate, w.throw_anim_rate(), 0.002, "%s: chain rate = Throwable.throw_anim_rate() (%.3f)" % [tag, w.throw_anim_rate()])
		if prev_state == ThrowChain.END and th.state == ThrowChain.RECOVER:
			rec_phase = th.part_phase("end")
		if prev_state == ThrowChain.RECOVER and th.state == ThrowChain.EXIT:
			exit_phase = th.part_phase("recover")
		prev_state = th.state
		var cur := _globals(sk)
		for b in cur:
			var q: Quaternion = cur[b]
			if not q.is_finite():
				nan = true
				continue
			var a := (prev[b] as Quaternion).angle_to(q) * float(Engine.physics_ticks_per_second)
			if a > peak:
				peak = a
				peak_bone = b
		prev = cur
		_sample_hand(w, th, clips, hand)
		if th.state == ThrowChain.NONE and i > 60:
			break
	# The next one's draw (Throwable DRAWING; the tomahawk's may be over already), then ready again.
	for i in int((w.follow_time + w.draw_time) * Engine.physics_ticks_per_second) + 120:
		await ctx.frames(1)
		if w.state == Throwable.State.DRAWING:
			drew = true
		_sample_hand(w, th, clips, hand)
		if drew and w.state == Throwable.State.READY:
			break
	Input.action_release("move_forward")
	await ctx.frames(10)
	ctx.check(not nan, "%s: no NaN in the pose" % tag)
	ctx.info("%s: peak core-bone turn %.1f rad/s (%s; the release whip's own speed)" % [tag, peak, peak_bone])
	ctx.metric("%s_peak_rad_s" % tag, peak)
	ctx.check(saw.has("START") and saw.has("END"), "%s: release-start -> release-end played (%s)" % [tag, saw.keys()])
	ctx.check(start_node.contains("crouch") == (mode == "crouch"), "%s: %s clips (%s)" % [tag, "crouch" if mode == "crouch" else "standing", start_node])
	var want_key := "throw_from_aimrun" if mode == "walk" else "throw_from_aimidle"
	var want_rec := String(anim.data.transition(want_key).get("graph", {}).get("record", "?"))
	ctx.check(String(start_tr.get("key", "")) == want_key and String(start_tr.get("record", "")) == want_rec and String(start_tr.get("from", "")) == "NONE",
			"%s: release-start entered from the aim over %s %s (request throw; from %s)" % [tag, start_tr.get("key", "-"),
			start_tr.get("record", "-"), start_tr.get("from", "-")])
	if mode == "walk":
		ctx.check(lower_w == 0.0, "%s: masked upper-body throw over the walk (full-body weight %.1f)" % [tag, lower_w])
	else:
		ctx.check(lower_w == 1.0, "%s: full-body throw while standing (the graph's throw states; weight %.1f)" % [tag, lower_w])
		ctx.check(rec_phase >= 0.8 - 1e-3 and rec_phase <= 0.8 + 1.5 * th.rate / 0.6 / Engine.physics_ticks_per_second + 1e-3,
				"%s: release-end -> recover at phase 0.8 (+1 frame; 0x000220b0): %.3f" % [tag, rec_phase])
		ctx.check(exit_phase >= 0.6 - 1e-3 and exit_phase <= 0.6 + 1.5 / 1.0 / Engine.physics_ticks_per_second + 1e-3,
				"%s: recover -> out at phase 0.6 (+1 frame; 0x00032fa0): %.3f" % [tag, exit_phase])
	ctx.check(w.count == before - 1 and _thrown.size() == 1, "%s: one object thrown (count %d -> %d)" % [tag, before, w.count])
	ctx.check(_release_frames.size() == 1, "%s: one release event (%d)" % [tag, _release_frames.size()])
	if _release_frames.size() == 1 and _thrown_frames.size() == 1:
		var rel_phase := float(_release_frames[0][2])
		var at := float(anim.data.graph.throw.release.clip_s) / 0.6
		var step := th.rate / 0.6 / float(Engine.physics_ticks_per_second)
		ctx.check(rel_phase >= at - 1e-4 and rel_phase <= at + step + 1e-4,
				"%s: release event at release-end phase %.4f (release %.4f, one frame %.4f)" % [tag, rel_phase, at, step])
		var df := int(_thrown_frames[0]) - int(_release_frames[0][0])
		ctx.check(df >= 0 and df <= 1, "%s: the object leaves within one frame of the release event (%d)" % [tag, df])
		var t_rel := float(int(_thrown_frames[0]) - f0) / float(Engine.physics_ticks_per_second)
		ctx.check(absf(t_rel - w.release_time) <= 2.5 / float(Engine.physics_ticks_per_second),
				"%s: released %.3f s after LMB up (release_time %.3f)" % [tag, t_rel, w.release_time])
		var r: Dictionary = _thrown[0]
		ctx.check((r.origin as Vector3).distance_to(r.com) < 1e-3, "%s: launched from the held object's centre of mass (%.4f m)" % [tag, (r.origin as Vector3).distance_to(r.com)])
		ctx.check((r.model as Vector3).distance_to(r.hand) < 0.03, "%s: the held object sits at the hand prop bone (%.3f m)" % [tag, (r.model as Vector3).distance_to(r.hand)])
	ctx.check(drew and int(hand.shown) > 0 and int(hand.off) == 0,
			"%s: the held object stays in the right hand through the throw, the recover and the next one's draw, or where that draw's clip puts it (%d of %d shown frames off; worst %.3f m from the palm vs %.3f m allowed%s)" % [
			tag, hand.off, hand.shown, hand.worst, hand.allow, (", " + String(hand.at)) if String(hand.at) != "" else ""])
	ctx.metric("%s_hand_worst_m" % tag, float(hand.worst))


## One frame of the throw case's hand check into `acc` (shown, off, worst, allow, at): the shown object's
## distance from the palm against HAND_TOL, or in the next one's draw against where the draw clip puts the
## prop bone plus SWITCH_MARGIN.
func _sample_hand(w: Throwable, th: ThrowChain, clips: Dictionary, acc: Dictionary) -> void:
	var dh := _hand_dist(w)
	if dh < 0.0:
		return
	acc.shown = int(acc.shown) + 1
	var allow := HAND_TOL
	if w.state == Throwable.State.DRAWING:
		allow = maxf(HAND_TOL, _switch_prop_reach(_player.anim.upper, clips) + SWITCH_MARGIN)
	if dh > allow:
		acc.off = int(acc.off) + 1
	if dh - allow > float(acc.worst) - float(acc.allow):
		acc.worst = dh
		acc.allow = allow
		acc.at = "throw chain %s, weapon state %s" % [th.state, Throwable.State.keys()[w.state]]


func _globals(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for b in CORE:
		var i := sk.find_bone(b)
		if i >= 0:
			out[b] = sk.get_bone_global_pose(i).basis.get_rotation_quaternion()
	return out


# --- 3. let-down --------------------------------------------------------------------------------

## raise: the opt-in wind-up raise is on (override_throw_windup_raise): the raise lowers over the
## graph's aim-idle -> idle fade; else the aim tree lowers with Weapon.aim.
func _let_down(ctx: AnimTestContext, raise: bool) -> void:
	var pre := "override " if raise else ""
	for how in ["rmb", "sprint"]:
		_place()
		var w := await _equip(ctx, "spear", false)
		var up: UpperBody = _player.anim.upper
		var th: ThrowChain = up.throw
		var before := w.count
		Input.action_press("fire")
		for i in 60:
			await ctx.frames(1)
			if w.charge >= 0.5:
				break
		var w0 := th.weight() if raise else up.upper_aim_w()
		var chain_on := th.state != ThrowChain.NONE
		if how == "rmb":
			Input.action_press("aim")
			await ctx.frames(2)
			Input.action_release("aim")
		else:
			Input.action_press("move_forward")
			Input.action_press("sprint")
		var mono := true
		var last := w0
		var t := 0
		for i in 240:
			await ctx.frames(1)
			var ww := th.weight() if raise else up.upper_aim_w()
			if ww > last + 1e-4:
				mono = false
			if not raise and th.state != ThrowChain.NONE:
				chain_on = true
			last = ww
			t = i
			if ww <= 0.0:
				break
		Input.action_release("fire")
		Input.action_release("sprint")
		Input.action_release("move_forward")
		var secs := float(t + (2 if how == "rmb" else 0) + 1) / float(Engine.physics_ticks_per_second)
		if raise:
			var fade := float(_player.anim.data.transition_use("aimidle_to_idle").get("fade_s", 0.6))
			ctx.check(w0 > 0.9 and mono and last <= 0.0 and secs <= fade * w0 + 0.05 and secs >= fade * w0 - 0.05,
					"%slet-down (%s): the raise lowers monotonically over the graph's %.1f s (%.2f s from %.2f)" % [pre, how, fade, secs, w0])
		else:
			ctx.check(w0 > 0.9 and mono and last <= 0.0 and not chain_on and secs <= w.aim_out_time * w0 + 0.05 and secs >= w.aim_out_time * w0 - 0.05,
					"let-down (%s): the aim tree lowers with Weapon.aim, monotonically, in %.2f s (aim_out_time %.2f from %.2f); the throw chain stays NONE" % [
					how, secs, w.aim_out_time, w0])
		ctx.check(w.count == before and th.state in [ThrowChain.EXIT, ThrowChain.NONE], "%slet-down (%s): nothing thrown" % [pre, how])
		await ctx.frames(60)


# --- 4. running quick throw ---------------------------------------------------------------------

## raise: with the opt-in wind-up raise the rest of the raise plays first (RAISE_OUT, fade 0 into
## the release); else the throw enters release-start from aim-run (request "throw").
func _running_quick_throw(ctx: AnimTestContext, raise: bool) -> void:
	var pre := "override " if raise else ""
	_place(-10.0, PI)    # run back up the lane, away from the dummies
	var w := await _equip(ctx, "spear", false)
	var th: ThrowChain = _player.anim.upper.throw
	Input.action_press("move_forward")
	await ctx.frames(90)
	_release_frames.clear()
	_thrown.clear()
	var before := w.count
	Input.action_press("fire")
	for i in 120:
		await ctx.frames(1)
		if w.charge * w.windup_time >= w.min_windup + 0.02:
			break
	var charge := w.charge
	var aim0 := _player.anim.upper.upper_aim_w()
	var f0 := Engine.get_physics_frames()
	Input.action_release("fire")
	var saw_raise := false
	var start_fade := -1.0
	var start_tr := {}
	for i in 240:
		await ctx.frames(1)
		if th.state == ThrowChain.RAISE_OUT:
			saw_raise = true
		if th.state == ThrowChain.START and start_fade < 0.0:
			start_fade = float(th.U.snapshot().get("fade", -1.0))
			start_tr = _last_state(th, "START")
		if w.count < before:
			break
	var t := float(Engine.get_physics_frames() - f0) / float(Engine.physics_ticks_per_second)
	Input.action_release("move_forward")
	if raise:
		ctx.check(saw_raise and start_fade == 0.0 and String(start_tr.get("key", "")) == "throw_raise_to_start",
				"%srunning quick throw (charge %.2f): the raise plays out, then the release enters with fade 0 (%s %s; fade %.2f)" % [
				pre, charge, start_tr.get("key", "-"), start_tr.get("record", "-"), start_fade])
	else:
		var rec := String(_player.anim.data.transition("throw_from_aimrun").get("graph", {}).get("record", "?"))
		ctx.check(not saw_raise and String(start_tr.get("key", "")) == "throw_from_aimrun" and String(start_tr.get("record", "")) == rec
				and is_equal_approx(start_fade, float(_player.anim.data.transition_use("throw_from_aimrun").get("fade_s", 0.2))),
				"running quick throw (charge %.2f, aim %.2f): release-start from aim-run over %s %s, fade %.2f, no raise" % [
				charge, aim0, start_tr.get("key", "-"), start_tr.get("record", "-"), start_fade])
	ctx.check(w.count == before - 1 and _release_frames.size() == 1 and t < w.release_time + w.anim_release_timeout - 0.02,
			"%srunning quick throw: the animation's release event lets go (%.3f s after LMB up; timer fallback at %.3f s)" % [
			pre, t, w.release_time + w.anim_release_timeout])
	await ctx.frames(int((w.follow_time + w.draw_time) * Engine.physics_ticks_per_second) + 30)


# --- 5. crouch toggle during release-start -------------------------------------------------------

func _crouch_during_start(ctx: AnimTestContext) -> void:
	var tag := "crouch during release-start"
	_place()
	var w := await _equip(ctx, "spear", false)
	var anim: PlayerAnim = _player.anim
	var th: ThrowChain = anim.upper.throw
	Input.action_press("fire")
	for i in 400:
		await ctx.frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	# A standing throw: the lower body stands in aim idle (any landing from the placement is over).
	for i in 240:
		if anim.loco.state in [&"AIM_IDLE", &"IDLE"]:
			break
		await ctx.frames(1)
	await ctx.frames(10)
	_release_frames.clear()
	_thrown.clear()
	_thrown_frames.clear()
	var before := w.count
	var hz := float(Engine.physics_ticks_per_second)
	Input.action_release("fire")
	var press := -1
	var standing := false
	var pel0 := 0.0
	var pel_late := INF
	var end_f := -1
	var exit_f := -1
	var exit_tr := {}
	var lw_mono := true
	var lw_last := 1.0
	var lw_zero := -1
	for i in 480:
		await ctx.frames(1)
		if th.state == ThrowChain.START and press < 0:
			press = i
			standing = th.lower_w >= 0.999
			pel0 = (_final.pelvis as Vector3).y - _player.global_position.y
			Input.action_press("crouch")
		elif press >= 0 and i == press + 3:
			Input.action_release("crouch")
		if press >= 0:
			if th.lower_w > lw_last + 1e-6:
				lw_mono = false
			lw_last = th.lower_w
			if lw_zero < 0 and th.lower_w <= 0.0:
				lw_zero = i
			if i == press + int(0.6 * hz):
				pel_late = (_final.pelvis as Vector3).y - _player.global_position.y
		if th.state == ThrowChain.END and end_f < 0:
			end_f = i
		if th.state == ThrowChain.EXIT and exit_f < 0:
			exit_f = i
			exit_tr = _last_state(th, "EXIT")
		if press >= 0 and i > press + int(0.8 * hz) and th.state == ThrowChain.NONE:
			break
	ctx.check(press >= 0 and standing, "%s: a standing (full-body) throw (legs weight %s at the toggle)" % [tag, "1" if standing else "<1"])
	var rec := String(anim.data.transition("throw_end_crouch_change").get("graph", {}).get("record", "?"))
	ctx.check(end_f >= 0 and exit_f >= end_f and exit_f - end_f <= 1 and String(exit_tr.get("key", "")) == "throw_end_crouch_change"
			and String(exit_tr.get("record", "")) == rec and is_equal_approx(float(exit_tr.get("fade", -1.0)),
			float(anim.data.transition_use("throw_end_crouch_change").get("fade_s", 0.5))),
			"%s: held, taken on release-end's first frame (%d frame(s) after it) over %s %s, fade %.2f" % [tag, exit_f - end_f,
			exit_tr.get("key", "-"), exit_tr.get("record", "-"), float(exit_tr.get("fade", -1.0))])
	var legs_s := float(lw_zero - press) / hz if lw_zero >= 0 else INF
	ctx.check(lw_mono and legs_s <= 0.5 + 3.5 / hz and legs_s >= 0.5 - 1.5 / hz,
			"%s: the throw's legs fade out over the crouch-change 0.5 s from the toggle (%.3f s, monotonic %s)" % [tag, legs_s, lw_mono])
	ctx.check(pel0 - pel_late >= 0.15,
			"%s: the lower body's crouch change shows: pelvis %.3f m at the toggle, %.3f m 0.6 s later" % [tag, pel0, pel_late])
	ctx.check(_release_frames.size() == 1 and _thrown.size() == 1 and w.count == before - 1,
			"%s: one release event, one object thrown (%d / %d)" % [tag, _release_frames.size(), _thrown.size()])
	await ctx.frames(int(w.draw_time * hz) + 60)
	if _player.is_crouching:
		Input.action_press("crouch")
		await ctx.frames(3)
		Input.action_release("crouch")
		await ctx.frames(60)


# --- 6. weapon switch: the object in the hand -----------------------------------------------------

## Graph switch clips (holster, holster finish, grab, draw) of the bow and the thrown weapons: the
## only clips that may take a thrown weapon's prop bone off the hand (to its holster / sling).
func _switch_clips(anim: PlayerAnim) -> Dictionary:
	var out := {}
	for wk in ["bow"] + WEAPONS:
		for st in ["stand", "crouch"]:
			for k in ["equip", "holster", "grab", "holster_finish"]:
				var a: Dictionary = anim.data.graph.actions.get("%s/%s/%s" % [wk, st, k], {})
				if a.get("partial") is String:
					out[String(a.partial)] = true
				for m in a.get("by_mode", {}):
					if a.by_mode[m].get("partial") is String:
						out[String(a.by_mode[m].partial)] = true
	return out


## Largest distance from the palm (m) the weighted switch clips put the right prop bone at this frame
## (PropFlipGuard entries of the last advance; 0 when none).
func _switch_prop_reach(up: UpperBody, clips: Dictionary) -> float:
	var rb := _player.skeleton.find_bone("r_hand_prop_attachment")
	var by_key := {}
	for n in up._guard_tracks:
		by_key[int(up._guard_tracks[n].key)] = String(up.index.oneshots[n].clip)
	var reach := 0.0
	for e: Array in up.prop_guard.entries.get(rb, []):
		if float(e[4]) > 0.0 and clips.has(by_key.get(int(e[0]), "")):
			reach = maxf(reach, (e[2] as Vector3).length())
	return reach


func _switch_hands(ctx: AnimTestContext) -> void:
	var anim: PlayerAnim = _player.anim
	var up: UpperBody = anim.upper
	var clips := _switch_clips(anim)
	for key in WEAPONS:
		_place()
		if _player.is_crouching:
			Input.action_press("crouch")
			await ctx.frames(3)
			Input.action_release("crouch")
			await ctx.frames(30)
		if _player.weapon_key != "bow":
			_player.switch_weapon("bow")
			for i in 600:
				await ctx.frames(1)
				if _player.weapon_key == "bow" and not _player.is_switching() and not _player.weapon.is_equipping():
					break
			await ctx.frames(30)
		var w: Throwable = _player.weapons[key]
		for phase in ["equip", "holster"]:
			_player.switch_weapon(key if phase == "equip" else "bow")
			var shown := 0
			var bad := 0
			var worst := 0.0
			var worst_allow := 0.0
			var first := -1.0
			var last := -1.0
			for i in 600:
				await ctx.frames(1)
				var d := _hand_dist(w)
				if d >= 0.0:
					shown += 1
					if first < 0.0:
						first = d
					last = d
					var allow := maxf(HAND_TOL, _switch_prop_reach(up, clips) + SWITCH_MARGIN)
					if d > allow:
						bad += 1
					if d - allow > worst - worst_allow or worst == 0.0:
						worst = d
						worst_allow = allow
				var done := not _player.is_switching() and not _player.weapon.is_equipping()
				if phase == "equip" and done and _player.weapon_key == key and i > 30:
					break
				if phase == "holster" and done and _player.weapon_key == "bow" and not w.model.visible:
					break
			await ctx.frames(10)
			if phase == "equip":
				last = _hand_dist(w)
			ctx.check(shown > 0 and bad == 0 and (last <= HAND_TOL if phase == "equip" else first <= HAND_TOL),
					"%s %s: shown %d frames, always in the right hand or where the graph switch clips put it (%d frame(s) off; worst %.3f m vs %.3f m allowed); %s %.3f m from the palm" % [
					key, phase, shown, bad, worst, worst_allow, "drawn and ready" if phase == "equip" else "at the holster's start",
					last if phase == "equip" else first])


# --- 7. opt-in wind-up raise (override) -----------------------------------------------------------

func _windup_override(ctx: AnimTestContext) -> void:
	var anim: PlayerAnim = _player.anim
	anim.override_throw_windup_raise = true
	await ctx.frames(2)
	ctx.check(anim.data.override_enabled("override_throw_windup_raise") and bool(anim.data.option("throw_windup_raise", false)),
			"override_throw_windup_raise: on at the next frame (options.throw_windup_raise)")
	_place()
	var w := await _equip(ctx, "spear", false)
	var th: ThrowChain = anim.upper.throw
	Input.action_press("fire")
	var saw_windup := false
	var worst_seek := 0.0
	for i in 400:
		await ctx.frames(1)
		if th.state == ThrowChain.WINDUP and w.charge > 0.05 and w.charge < 0.95:
			saw_windup = true
			worst_seek = maxf(worst_seek, absf(th.part_phase("raise") - w.charge))
		if w.state == Throwable.State.HOLDING:
			break
	ctx.check(saw_windup and worst_seek < 0.05, "override: the wind-up plays the raise seeked by the charge (worst |phase - charge| %.3f)" % worst_seek)
	await ctx.frames(30)
	ctx.check(th.state == ThrowChain.HOLD and th.weight() < 0.05, "override: at full charge the aim tree holds the cocked pose (chain %s, weight %.2f)" % [th.state, th.weight()])
	Input.action_release("fire")
	for i in 400:
		await ctx.frames(1)
		if th.state == ThrowChain.NONE and w.state == Throwable.State.READY and i > 60:
			break
	await _let_down(ctx, true)
	await _running_quick_throw(ctx, true)
	anim.override_throw_windup_raise = false
	await ctx.frames(2)
	ctx.check(not anim.data.override_enabled("override_throw_windup_raise") and not bool(anim.data.option("throw_windup_raise", true)),
			"override_throw_windup_raise: off again at the next frame")
