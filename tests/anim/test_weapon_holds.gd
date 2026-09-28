extends AnimTestSuite
## Rifle holds while moving (push n01, user playtest 2026-09-25): "the gun bounces in the left hand when
## we move", "the one hand hold its where the rifle is held down with one hand during crouch" and "the 2
## hand holding of the crouch move the left elbow is inward and not out ward".
##
## Drives the player in the real level with the musket (walk, jog, sprint, starts, stops, turns, jumps,
## crouch-walks with two hands and with one) and measures the FINAL pose every frame (after every
## SkeletonModifier3D: Skeleton3D.skeleton_updated, as tests/anim/lib/hand_grip_meter.gd does):
##  - drift: the left palm point (HandGripMeter.palm_point) in the right prop frame, against the source's
##    own two-hand grip point (the carry idle's): how far the left hand slides on the gun. Also the
##    palm's gap to the Brown Bess forestock surface (palm_gap).
##  - gun bob: the right prop origin (the gun) in the chest's frame (spined): its range per gait and its
##    frame-to-frame velocity change (a pop or a jitter shows as a spike of |dv| / dt).
##  - left elbow: the elbow's side of the shoulder -> wrist line, in the chest's frame: `out` = its
##    component toward the character's left (away from the body; > 0 outward), `down` = toward the hips.
##  - one-hand crouch-move hold (push n01c: the LEFT hand holds the gun in the middle, the right hand free): the
##    gun's height and barrel pitch in the character's frame, the right hand's distance from the gun. The gun is
##    measured where its model is (Weapon.model: GunMiddleCarryIK puts it in the left fist), in the right prop's
##    convention (+Z the barrel, the origin at the wrist of the stock): the right prop itself while the right hand
##    holds it.
## Checks (the targets of push n01):
##  - two-hand holds, moving or not, grounded or in the air: drift <= DRIFT_MAX_M, |palm_gap| <= GAP_MAX_M
##    (after the first GRIP_SETTLE_S of a segment that starts from the one-hand hold or an aim);
##  - no gun pops: the gun's (and its muzzle's) velocity in the chest frame changes by at most POP_DV_MAX
##    (POP_MUZZLE_DV_MAX) m/s per frame in the gaits and gait changes, POP_DV_BIG (POP_MUZZLE_DV_BIG) in the
##    big changes of the carry (TWO_HAND_BIG); the one-hand hold (the left hand carries the gun in the character's
##    frame, push n01c) relative to the root bone against POP_DV_BIG (POP_MUZZLE_DV_BIG);
##  - two-hand crouch-move hold: the left elbow points down and outward (its side ELBOW_PHI_MIN..ELBOW_PHI_MAX);
##  - two-hand holds: the left elbow stays below the shoulder (ELBOW_RISE_MAX_M; review n01: at the walk start
##    and in the jog the grip held it up to 24 cm over the shoulder, the hand at the shoulder);
##  - the standing two-hand idle is unchanged (the user liked it): the left elbow's side and lateral place
##    as before n01 (IDLE_REF, within ELBOW_IDLE_TOL_DEG / ELBOW_IDLE_TOL_M);
##  - one-hand crouch-move hold: the gun is carried low (the wrist of the stock below the pelvis + LOW_MAX_M,
##    muzzle at or below level: barrel up component <= MUZZLE_UP_MAX) and the right hand is off the gun (push n01c;
##    tests/torch/test_hand_holds.gd checks the left fist on the gun's middle).
## Output: a table per segment and json_out=<path> (every frame).
##   Godot --headless --fixed-fps 120 --path . -s tests/anim/run_all.gd -- --no-capture --only=test_weapon_holds [json_out=/tmp/x.json]

const Meter := preload("res://tests/anim/lib/hand_grip_meter.gd")

const DRIFT_MAX_M := 0.012
const GAP_MAX_M := 0.02
const GRIP_SETTLE_S := 0.3
const POP_DV_MAX := 0.12
const POP_DV_BIG := 0.4
## The muzzle (MUZZLE_M along the barrel from the grip) in the chest frame: velocity change per frame (m/s).
const MUZZLE_M := 1.2
const POP_MUZZLE_DV_MAX := 0.3
const POP_MUZZLE_DV_BIG := 1.1
## The left elbow's side about the shoulder -> wrist line in the chest's frame (deg; 0 = toward the hips,
## +90 = out to the character's left, -90 = in across the chest).
const ELBOW_PHI_MIN := 10.0
const ELBOW_PHI_MAX := 100.0
## The left elbow's place in the chest frame moves at most this far in one frame (m; a flip moves it 10-40 cm).
const ELBOW_STEP_MAX_M := 0.03
const ELBOW_STEP_BIG_M := 0.04
const ELBOW_IDLE_TOL_DEG := 3.0
const ELBOW_IDLE_TOL_M := 0.01
## The left elbow's height over the left shoulder in the character's frame, most in a two-hand segment (m; the
## source's own two-hand holds: -0.19 standing, -0.15 crouched; a running jump's landing, the torso bent over the
## gun and the elbow tucked along it, reaches the shoulder's height).
const ELBOW_RISE_MAX_M := 0.03
const LOW_MAX_M := 0.05
const MUZZLE_UP_MAX := 0.05
const FREE_HAND_MIN_M := 0.2
## The standing two-hand carry idle before n01 (as authored; no IK there): the left elbow's side (deg) and
## how far it stands out from the shoulder toward the character's left (m).
const IDLE_REF := {"phi": 25.66, "lat": 0.1190}

## Segments: [label, seconds, held actions, tapped actions, yaw turn (deg over the segment)].
## "-" = not summarised. Each scenario starts from a teleport onto a clear corridor.
## `hands`: "two" (relax_after_s 0: never relaxed) or "one" (relaxed at once).
const SCENARIOS := [
	{"name": "stand", "crouch": false, "hands": "two", "steps": [
		["idle", 1.0, [], [], 0.0],
		["walk", 2.0, ["walk", "move_forward"], [], 0.0],
		["jog", 2.0, ["move_forward"], [], 0.0],
		["sprint", 2.0, ["sprint", "move_forward"], [], 0.0],
		["sprint_to_jog", 1.0, ["move_forward"], [], 0.0],
		["jog_to_walk", 1.0, ["walk", "move_forward"], [], 0.0],
		["stop_walk", 1.2, [], [], 0.0],
		["start_jog", 1.0, ["move_forward"], [], 0.0],
		["stop_jog", 1.4, [], [], 0.0]]},
	{"name": "turns", "crouch": false, "hands": "two", "steps": [
		["jog_in", 0.8, ["move_forward"], [], 0.0],
		["jog_turn", 1.2, ["move_forward"], [], 90.0],
		["jog_diag", 1.0, ["move_forward", "move_left"], [], 0.0],
		["walk_turn", 1.2, ["walk", "move_forward"], [], -90.0],
		["stop_turn", 1.2, [], [], 0.0]]},
	{"name": "jumps", "crouch": false, "hands": "two", "steps": [
		["idle", 0.6, [], [], 0.0],
		["jump_still", 1.6, [], ["jump"], 0.0],
		["jog_mid", 1.0, ["move_forward"], [], 0.0],
		["jump_jog", 1.6, ["move_forward"], ["jump"], 0.0],
		["-", 0.6, [], [], 0.0]]},
	{"name": "crouch_still", "crouch": false, "hands": "two", "steps": [
		["idle", 0.6, [], [], 0.0],
		["trans_down_still", 1.2, [], ["crouch"], 0.0],
		["crouch_idle_still", 1.0, [], [], 0.0],
		["trans_up_still", 1.2, [], ["crouch"], 0.0],
		["-", 0.5, [], [], 0.0]]},
	{"name": "crouch_two", "crouch": true, "hands": "two", "steps": [
		["crouch_idle", 1.0, [], [], 0.0],
		["crouch_walk", 2.0, ["move_forward"], [], 0.0],
		["crouch_strafe", 1.2, ["move_left"], [], 0.0],
		["crouch_back", 1.2, ["move_back"], [], 0.0],
		["crouch_stop", 1.0, [], [], 0.0]]},
	{"name": "crouch_moving", "crouch": false, "hands": "two", "steps": [
		["jog_up", 1.0, ["move_forward"], [], 0.0],
		["jog_to_crouch", 1.2, ["move_forward"], ["crouch"], 0.0],
		["crouch_walk", 1.0, ["move_forward"], [], 0.0],
		["crouch_to_jog", 1.2, ["move_forward"], ["crouch"], 0.0],
		["-", 0.4, [], [], 0.0]]},
	{"name": "crouch_one", "crouch": true, "hands": "one", "steps": [
		["one_crouch_idle", 1.0, [], [], 0.0],
		["one_crouch_walk", 2.5, ["move_forward"], [], 0.0],
		["one_crouch_stop", 1.2, [], [], 0.0],
		["one_crouch_walk2", 1.2, ["move_forward"], [], 0.0],
		["-", 0.5, [], [], 0.0]]},
]
## Two-hand segments whose drift / gap / pop are checked: the steady gaits and the gait changes (starts,
## stops, turns, walk / jog / sprint) against POP_DV_MAX, and the big changes of the carry itself (the
## graph's crouch <-> stand changes, the crouch-walk start from the crouch idle, a jog started right after
## standing up, jumps) against POP_DV_BIG: there the source's own cross-fades swing the gun 15-45 cm in
## 0.1-0.2 s, which the damper rounds off but does not slow down.
const TWO_HAND_STEADY := ["idle", "walk", "jog", "sprint", "sprint_to_jog", "jog_to_walk", "stop_walk", "start_jog",
		"stop_jog", "jog_in", "jog_turn", "jog_diag", "walk_turn", "stop_turn", "jog_mid", "crouch_strafe", "crouch_back",
		"crouch_stop"]
const TWO_HAND_BIG := ["jump_still", "jump_jog", "crouch_idle", "crouch_walk", "jog_up", "jog_to_crouch", "crouch_to_jog",
		"trans_down_still", "crouch_idle_still", "trans_up_still"]
## One-hand segments whose pops are checked (against POP_DV_BIG: the hold changes between two hands and one).
const ONE_HAND_POP := ["one_crouch_walk", "one_crouch_stop", "one_crouch_walk2"]
## Segments of the two-hand crouch-move hold (the left elbow checks).
const CROUCH_TWO_MOVE := ["crouch_walk", "crouch_strafe", "crouch_back"]

var _meter
var _player: Node
var _sk: Skeleton3D
var _label := "-"
var _seg_t := 0.0
var _frames := []
var _pre := {}
var _ids := {}
var _chest_left := Vector3.RIGHT
var _grip_ref := Vector3.ZERO
var _prev := {}


func describe() -> String:
	return "rifle holds while moving: left hand planted on the fore-end (drift), no gun pops, crouch two-hand left elbow outward, one-hand crouch hold low"


func timeout_s() -> float:
	return 900.0


func run(ctx: AnimTestContext) -> void:
	_player = await ctx.level()
	if _player == null:
		return
	ctx.allow_error("loops in the graph")
	_sk = _player.skeleton
	_meter = Meter.new(_player)
	ctx.check(_meter.calibrate(ctx.tree), "reference grips calibrated")
	ctx.check(_meter.build_stock(_player.weapons["musket"].model), "Brown Bess forestock: " + _meter.stock_info)
	for r: Dictionary in _meter.refs:
		if String(r.name) == "carry_idle":
			_grip_ref = r.palm
	for n in ["l_shoulder", "l_elbow", "l_wrist", "r_shoulder", "r_elbow", "r_wrist", "spined", "pelvis",
			"r_hand_prop_attachment", "l_hand_prop_attachment", "l_palm"]:
		_ids[n] = _sk.find_bone(n)
	# The chest's own left axis (the rest pose: the character faces skeleton +Z, its left is +X).
	var rest_chest := _sk.get_bone_global_rest(_ids.spined).basis.orthonormalized()
	_chest_left = (rest_chest.inverse() * Vector3.RIGHT).normalized()
	var anim = _player.anim
	var relax0: float = anim.relax_after_s
	if String(ctx.arg("carry", "")) != "":
		anim.long_gun_move_carry = String(ctx.arg("carry", ""))
	await _equip(ctx, "musket")
	_player.anim.mixer_applied.connect(_on_applied)
	_sk.skeleton_updated.connect(_on_updated)
	for sc: Dictionary in SCENARIOS:
		var only := String(ctx.arg("scenarios", ""))
		if only != "" and not only.split(",").has(sc.name):
			continue
		await _scenario(ctx, sc)
	_player.anim.mixer_applied.disconnect(_on_applied)
	_sk.skeleton_updated.disconnect(_on_updated)
	anim.relax_after_s = relax0
	FootSlip._release_all()
	_summarise(ctx)
	var out := String(ctx.arg("json_out", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"frames": _frames}))
			ctx.info("wrote " + out)


# --- driving -----------------------------------------------------------------------------------

func _equip(ctx: AnimTestContext, key: String) -> void:
	_player.switch_weapon(key)
	await ctx.frames(20)
	var n := 0
	while (_player.is_switching() or _player.weapon.is_equipping()) and n < 600:
		await ctx.frames(1)
		n += 1
	await ctx.frames(20)


func _scenario(ctx: AnimTestContext, sc: Dictionary) -> void:
	FootSlip._release_all()
	_label = "-"
	var anim = _player.anim
	# Two hands: never relaxed. One hand: relaxed right away (the user's pick shows it while crouch-moving).
	anim.relax_after_s = 0.0 if String(sc.hands) == "two" else 0.05
	# a short aim resets the relaxed carry
	Input.action_press("aim")
	await ctx.frames(6)
	Input.action_release("aim")
	await ctx.seconds(0.6)
	await FootSlip._set_crouch(ctx.tree, _player, bool(sc.crouch), ctx)
	var start = FootSlip._clear_start(_player, 24.0)
	if start == null:
		start = FootSlip._clear_start(_player, 12.0)
	if start != null:
		_player.global_position = Vector3(start.x, 0.05, start.y)
	_player.velocity = Vector3.ZERO
	_player.yaw = FootSlip._heading(FootSlip.TRAVEL)
	_player.pitch = 0.0
	await ctx.seconds(0.8)
	var held := {}
	_prev = {}
	for st: Array in sc.steps:
		var want := {}
		for a: String in st[2]:
			want[a] = true
		for a in held.keys():
			if not want.has(a):
				Input.action_release(a)
		for a in want:
			if not held.has(a):
				Input.action_press(a)
		held = want
		_label = String(st[0])
		_seg_t = 0.0
		for a: String in st[3]:
			Input.action_press(a)
		var n := int(round(float(st[1]) * Engine.physics_ticks_per_second))
		var turn := deg_to_rad(float(st[4])) / maxf(n, 1)
		for i in n:
			if i == 2:
				for a: String in st[3]:
					if not want.has(a):
						Input.action_release(a)
			if turn != 0.0:
				_player.yaw += turn
			await ctx.frames(1)
	_label = "-"
	FootSlip._release_all()
	await ctx.frames(4)


# --- measuring ---------------------------------------------------------------------------------

func _on_applied() -> void:
	_pre = _meter._globals(_sk)


func _on_updated() -> void:
	if _label == "-" or _pre.is_empty() or not _sk.is_inside_tree():
		return
	var post: Dictionary = _meter._globals(_sk)
	var rec: Dictionary = _meter.measure(post, _pre)
	var g := {}
	for n in _ids:
		g[n] = _sk.get_bone_global_pose(_ids[n])
	var dt := _player.get_process_delta_time()
	_seg_t += dt
	var chest: Transform3D = (g.spined as Transform3D).orthonormalized()
	var left := chest.basis * _chest_left
	# left elbow side in the chest frame
	var s: Vector3 = (g.l_shoulder as Transform3D).origin
	var e: Vector3 = (g.l_elbow as Transform3D).origin
	var w: Vector3 = (g.l_wrist as Transform3D).origin
	var ax := (w - s).normalized()
	var v := (e - s) - ax * (e - s).dot(ax)
	# the elbow's side about the shoulder -> wrist line in the chest's frame (deg): 0 = toward the hips,
	# +90 = out to the character's left (away from the body), -90 = in across the chest (as LeftGripIK.side_axes())
	var phi := 0.0
	var sa := _side_axes(left, ax)
	if not sa.is_empty() and v.length() > 1e-4:
		phi = rad_to_deg(atan2(v.dot(sa[0]), v.dot(sa[1])))
	var fr := {"label": _label, "t": _seg_t, "dt": dt, "frame": Engine.get_process_frames(),
			"crouch": bool(_player.is_crouching), "loco": String(_player.anim.loco.state),
			"one_hand": bool(_player.anim.one_hand), "grip_w": float(_player.anim.left_grip.grip_weight),
			"mid": float(_player.anim.mid_ik.progress) if _player.anim.get("mid_ik") != null else 0.0,
			"larm_w": float(_player.anim.left_arm.weight), "rarm_w": float(_player.anim.right_arm.weight),
			"elbow_phi": phi, "elbow_lat": (e - s).dot(left), "elbow_off": v.length(),
			"ik_side": float(_player.anim.left_grip.get("elbow_side_deg")) if _player.anim.left_grip.get("elbow_side_deg") != null else NAN,
			"ik_clip_side": float(_player.anim.left_grip.get("elbow_clip_deg")) if _player.anim.left_grip.get("elbow_clip_deg") != null else NAN}
	fr.elbow_chest = chest.affine_inverse() * e
	if not _prev.is_empty():
		fr.elbow_step = (fr.elbow_chest as Vector3).distance_to(_prev.elbow_chest as Vector3)
	fr.palm_prop = rec.palm_prop
	fr.drift = (rec.palm_prop as Vector3).distance_to(_grip_ref)
	fr.palm_gap = float(rec.get("palm_gap", NAN))
	var rp: Transform3D = (g.r_hand_prop_attachment as Transform3D).orthonormalized()
	fr.lprop_gap = (g.l_hand_prop_attachment as Transform3D).origin.distance_to(rp.origin)
	# the gun where its model is (the left fist's in the middle carry), in the right prop's convention
	var gm: Weapon = _player.weapons.get("musket")
	if gm != null and gm.model != null and gm.model.is_visible_in_tree():
		rp = (_sk.global_transform.affine_inverse() * gm.model.global_transform * _player.musket_offset.affine_inverse()).orthonormalized()
	var gun_c := chest.affine_inverse() * rp.origin
	var muz_c := chest.affine_inverse() * (rp.origin + rp.basis * Vector3.BACK * MUZZLE_M)
	fr.gun_chest = gun_c
	fr.muzzle_chest = muz_c
	# (the one-hand hold since push n01c: the left hand carries the gun in the character's frame, springs on, not with
	# the chest: its pops relative to the root bone; the chest's and the hips' own keyed sway, 10-15 Hz, is not the
	# hold's)
	var root_o: Vector3 = _sk.get_bone_global_pose(_sk.find_bone("root")).origin
	var gun_h := rp.origin - root_o
	var muz_h := rp.origin + rp.basis * Vector3.BACK * MUZZLE_M - root_o
	fr.gun_hips = gun_h
	fr.muzzle_hips = muz_h
	if not _prev.is_empty() and _prev.has("gun_hips"):
		var hv := (gun_h - (_prev.gun_hips as Vector3)) / maxf(dt, 1e-4)
		var hmv := (muz_h - (_prev.muzzle_hips as Vector3)) / maxf(dt, 1e-4)
		fr.gun_hv = hv
		fr.muzzle_hv = hmv
		if _prev.has("gun_hv"):
			fr.gun_hdv = hv.distance_to(_prev.gun_hv as Vector3)
			fr.muzzle_hdv = hmv.distance_to(_prev.muzzle_hv as Vector3)
	if not _prev.is_empty():
		var vel := (gun_c - (_prev.gun_chest as Vector3)) / maxf(dt, 1e-4)
		var mvel := (muz_c - (_prev.muzzle_chest as Vector3)) / maxf(dt, 1e-4)
		fr.gun_vel = vel
		fr.muzzle_vel = mvel
		if _prev.has("gun_vel"):
			fr.gun_dv = vel.distance_to(_prev.gun_vel as Vector3)
			fr.muzzle_dv = mvel.distance_to(_prev.muzzle_vel as Vector3)
	fr.damp_w = float(_player.anim.gun_damper.damp_weight) if _player.anim.get("gun_damper") != null else 0.0
	fr.raw_gun = _player.anim.gun_damper.last_target if _player.anim.get("gun_damper") != null else gun_c
	fr.reach_pull = float(_player.anim.left_grip.get("reach_pull")) if _player.anim.left_grip.get("reach_pull") != null else 0.0
	# one-hand hold: the gun in the character's frame (skeleton space: left +X, up +Y, forward +Z)
	var pel: Vector3 = (g.pelvis as Transform3D).origin
	var barrel := rp.basis * Vector3.BACK
	fr.gun_rel_pelvis = rp.origin - pel
	fr.barrel = barrel
	fr.lwrist_gun = w.distance_to(rp.origin)
	fr.rwrist_gun = (g.r_wrist as Transform3D).origin.distance_to(rp.origin + rp.basis * Vector3.BACK * 0.4)
	fr.rwrist_rsh = (g.r_wrist as Transform3D).origin - (g.r_shoulder as Transform3D).origin
	# the left elbow and wrist from the left shoulder in the character's frame (skeleton space)
	fr.l_elbow_sh = e - s
	fr.l_wrist_sh = w - s
	_prev = fr
	_frames.append(fr)


# --- summary -----------------------------------------------------------------------------------

func _summarise(ctx: AnimTestContext) -> void:
	var by := {}
	var order := []
	for f: Dictionary in _frames:
		if not by.has(f.label):
			by[f.label] = []
			order.append(f.label)
		by[f.label].append(f)
	ctx.info("%-16s %4s  %-11s %-11s %-9s %-11s %-15s %-13s %-7s %-7s %-9s" % ["segment", "n", "drift max", "gap max", "lprop", "gun/muz dv",
			"gun range (ch)", "elbow side/lat", "el step", "el up", "grip/arm"])
	var rows := {}
	for lab: String in order:
		var fs: Array = by[lab]
		var r := {"n": fs.size(), "drift": 0.0, "gap": 0.0, "lprop": 0.0, "dv": 0.0, "mdv": 0.0, "estep": 0.0, "phi_min": 180.0, "phi_max": -180.0,
				"phi_mean": 0.0, "lat_mean": 0.0, "grip": 0.0, "larm": 0.0, "el_up": -9.0}
		var lo := Vector3.ONE * 9.0
		var hi := -Vector3.ONE * 9.0
		var settled := 0
		for f: Dictionary in fs:
			var gated := float(f.t) >= GRIP_SETTLE_S
			if gated:
				settled += 1
				r.drift = maxf(r.drift, float(f.drift))
				if not is_nan(float(f.palm_gap)):
					r.gap = maxf(r.gap, absf(float(f.palm_gap)))
				r.lprop = maxf(r.lprop, float(f.lprop_gap))
			r.dv = maxf(r.dv, float(f.get("gun_dv", 0.0)))
			r.mdv = maxf(r.mdv, float(f.get("muzzle_dv", 0.0)))
			r.hdv = maxf(float(r.get("hdv", 0.0)), float(f.get("gun_hdv", 0.0)))
			r.hmdv = maxf(float(r.get("hmdv", 0.0)), float(f.get("muzzle_hdv", 0.0)))
			r.estep = maxf(r.estep, float(f.get("elbow_step", 0.0)))
			r.el_up = maxf(r.el_up, (f.l_elbow_sh as Vector3).y)
			var gc: Vector3 = f.gun_chest
			lo = Vector3(minf(lo.x, gc.x), minf(lo.y, gc.y), minf(lo.z, gc.z))
			hi = Vector3(maxf(hi.x, gc.x), maxf(hi.y, gc.y), maxf(hi.z, gc.z))
			r.phi_min = minf(r.phi_min, float(f.elbow_phi))
			r.phi_max = maxf(r.phi_max, float(f.elbow_phi))
			r.phi_mean += float(f.elbow_phi) / fs.size()
			r.lat_mean += float(f.elbow_lat) / fs.size()
			r.grip += float(f.grip_w) / fs.size()
			r.larm += float(f.larm_w) / fs.size()
		r.range = hi - lo
		r.settled = settled
		rows[lab] = r
		ctx.info("%-16s %4d  %-11s %-11s %-9s %-11s %-15s %-13s %-7s %-7s %-9s" % [lab, r.n, "%.3f" % r.drift, "%.3f" % r.gap, "%.3f" % r.lprop,
				"%.2f/%.2f" % [r.dv, r.mdv], "%s" % (r.range as Vector3).snapped(Vector3.ONE * 0.001), "%.0f..%.0f %.3f" % [r.phi_min, r.phi_max, r.lat_mean],
				"%.3f" % r.estep, "%.3f" % r.el_up, "%.2f/%.2f" % [r.grip, r.larm]])
	ctx.metric("rifle_hold_rows", rows.size())
	# Checks.
	for lab: String in TWO_HAND_STEADY + TWO_HAND_BIG:
		if not rows.has(lab):
			continue
		var r: Dictionary = rows[lab]
		var big := lab in TWO_HAND_BIG
		ctx.at_most(r.drift, DRIFT_MAX_M, "two-hand %s: the left palm stays on its grip point on the gun (drift, m)" % lab)
		ctx.at_most(r.gap, GAP_MAX_M, "two-hand %s: the left palm on the forestock (|gap|, m)" % lab)
		ctx.at_most(r.dv, POP_DV_BIG if big else POP_DV_MAX, "two-hand %s: no gun pop / jitter in the chest frame (max velocity change per frame, m/s)" % lab)
		ctx.at_most(r.mdv, POP_MUZZLE_DV_BIG if big else POP_MUZZLE_DV_MAX, "two-hand %s: no muzzle pop / jitter in the chest frame (max velocity change per frame, m/s)" % lab)
		ctx.at_most(r.estep, ELBOW_STEP_BIG_M if big else ELBOW_STEP_MAX_M, "two-hand %s: the left elbow does not flip (most it moves in the chest frame in one frame, m)" % lab)
		ctx.at_most(r.el_up, ELBOW_RISE_MAX_M, "two-hand %s: the left elbow stays below the shoulder (most it rises over the shoulder, m)" % lab)
	for lab: String in ONE_HAND_POP:
		if rows.has(lab):
			ctx.at_most(float(rows[lab].get("hdv", 0.0)), POP_DV_BIG, "one-hand %s: no gun pop in the character's frame (max velocity change per frame, m/s, relative to the root bone)" % lab)
			ctx.at_most(float(rows[lab].get("hmdv", 0.0)), POP_MUZZLE_DV_BIG, "one-hand %s: no muzzle pop in the character's frame (max velocity change per frame, m/s, relative to the root bone)" % lab)
	for lab: String in CROUCH_TWO_MOVE:
		if not rows.has(lab):
			continue
		var r: Dictionary = rows[lab]
		ctx.at_least(r.phi_min, ELBOW_PHI_MIN, "two-hand %s: the left elbow points out, away from the body (least side, deg)" % lab)
		ctx.at_most(r.phi_max, ELBOW_PHI_MAX, "two-hand %s: the left elbow points down, not up (most side, deg)" % lab)
	if rows.has("idle"):
		var r: Dictionary = rows.idle
		ctx.info("standing two-hand idle: left elbow side %.2f deg, %.4f m out from the shoulder" % [r.phi_mean, r.lat_mean])
		if float(IDLE_REF.phi) != INF:
			ctx.near(r.phi_mean, float(IDLE_REF.phi), ELBOW_IDLE_TOL_DEG, "standing two-hand idle unchanged: left elbow side (deg)")
			ctx.near(r.lat_mean, float(IDLE_REF.lat), ELBOW_IDLE_TOL_M, "standing two-hand idle unchanged: left elbow out from the shoulder (m)")
	for lab: String in ["one_crouch_walk", "one_crouch_walk2"]:
		if not by.has(lab):
			continue
		var low := -INF
		var up := -INF
		var free := INF
		var one := 0
		for f: Dictionary in by[lab]:
			if float(f.t) < 0.5:
				continue
			low = maxf(low, (f.gun_rel_pelvis as Vector3).y)
			up = maxf(up, (f.barrel as Vector3).y)
			free = minf(free, float(f.rwrist_gun))
			one += 1 if bool(f.one_hand) else 0
		ctx.check(one > 0, "%s: the one-hand hold is on while crouch-moving (%d frames)" % [lab, one])
		ctx.at_most(low, LOW_MAX_M, "%s: the gun is carried low (the wrist of the stock over the pelvis, m)" % lab)
		ctx.at_most(up, MUZZLE_UP_MAX, "%s: the muzzle is held down (barrel up component)" % lab)
		ctx.at_least(free, FREE_HAND_MIN_M, "%s: the right hand is off the gun (right wrist to the gun's middle, m)" % lab)


## LeftGripIK.side_axes() (kept here too, so the suite measures a build without it the same way).
static func _side_axes(left: Vector3, dir: Vector3) -> Array:
	var out_p := left - dir * left.dot(dir)
	if out_p.length() < 0.05:
		return []
	out_p = out_p.normalized()
	return [out_p, out_p.cross(dir).normalized()]
