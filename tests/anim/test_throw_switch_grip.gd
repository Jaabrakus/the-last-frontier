extends AnimTestSuite
## THROW2 (user playtest 2026-09-25: "switching while moving with the spear, the spear lags behind"), its
## review and fix 2: the thrown weapons are held on every rendered frame of a weapon switch and of the throw
## cycle's draw of the next one, clear of the body, never popping, and come from / go to where the loadout
## carries them.
##
## Cause of the lag (measured before THROW2): the held model sat on the weapon prop bone with a fixed
## character-space orientation, but the switch clips key that bone along their own object's path, away
## from the hand. THROW2 put every object in the fist (the palm's final pose times the grip); its review
## put the spear on the long-gun draw's own object path and stood the tomahawk up at the belt
## (Throwable.switch_path):
##   spear (SOURCE)  on the long-gun draw's own object path (the prop bone: slung on the back, swung over
##                   the left shoulder) until the right hand has it, then in the fist, turned like that gun
##                   and handing over to the carry over the second half of the draw; a draw that never takes
##                   the gun to the sling (the throw cycle's next spear, crouched draws after the pistol or
##                   the atlatl) shows it in the hand from mid-draw (crouched once the fist is up near the
##                   shoulder);
##   tomahawk (STOW) in the fist, the haft stood up at the back of the belt; a draw whose fist never gets
##                   there (the throw cycle's next tomahawk) shows it in the fist from mid-draw;
##   atlatl (FIST)   in the fist.
##
## Checked on every rendered frame after the frame's skeleton update and its placements (a node that runs
## last in _process queues a deferred call; the skeleton's update notification was queued before it), for
## every shown thrown-weapon model, with the hand computed here independently (the right palm's final pose,
## read in skeleton_updated, times the prop key of the weapon's carry grip clip read from the Actor_B
## library, and the palm bone itself):
##   held    tomahawk / atlatl: the model origin within GRIP_TOL of the hand and within PALM_TOL of the palm
##           bone; carried (not switching) the tomahawk also turns with the fist (within ROT_TOL_DEG).
##           spear: its shaft passes within GRIP_TOL of the hand or of the draw's object (the prop bone),
##           the tolerance growing to half their distance while one hands over to the other (source_near);
##           in the hand, within PALM_TOL of the palm bone.
##   no pop  the held object never turns more than TURN_POP_DEG beyond the larger of its own turn on the
##           neighbouring rendered frames and the turn of the hand or of the draw's object it follows (fix 2:
##           the hand-overs' shortest-path slerps flipped the object in one frame, 18-46 deg); nor more than
##           TURN_CAP_DEG in one frame. The largest turn and the largest turn beyond the hand's / the drawn
##           object's are reported.
##   clear   the parts of the object outside the fist (the spear's shaft beyond GRIP_HALF either side of the
##           grip when the hand is on it; the tomahawk's haft above TOMA_EXPOSED_Y and its head) from the femurs
##           (thighs), the pelvis-spined segment (torso), the head bones and (the spear) the face bones.
##           Standing: at most THIGH_FRAMES frames inside 0.08 m of a femur and never inside THIGH_MIN; the torso
##           never inside TORSO_MIN and at most TORSO_FRAMES frames inside 0.12 (the shaft passes the flank
##           where the long gun does); the head never inside 0.10 (the spear: HEAD_FRAMES frames of the fast
##           over-the-shoulder swing, never inside HEAD_MIN); the spear never inside SPEAR_FACE_MIN of the face.
##           Crouched (the crouched draws' hand passes through the lap, and the long gun's own path with it):
##           in the hand, no part deeper in a body part than the fist is, by more than CROUCH_FIST_TOL;
##           the spear no deeper than the long gun whose draw it plays (1.24 m ahead of its grip, 0.35 m behind),
##           by more than CROUCH_SOURCE_TOL (standing SOURCE_TOL); its shaft never inside SPEAR_FACE_MIN of the face.
##   where   the spear's first shown frame of a draw is on the back (behind the upper spine, at least 0.25 m up
##           the torso) when the draw took its object to the sling before, else in the hand from mid-draw; its
##           last of a holster on the back; the tomahawk's first / last behind the hip plane, or in the fist
##           from mid-draw when the draw's fist never got behind it.
## Switch chains, each throwable drawn from and put away to every other weapon: musket -> spear -> bow -> spear
## -> pistol -> spear -> atlatl -> spear -> tomahawk -> spear -> musket, and musket -> tomahawk -> bow ->
## tomahawk -> pistol -> tomahawk -> atlatl -> tomahawk -> musket; running and sprinting at one and at two
## physics ticks per rendered frame, running at half the frame rate (Engine.time_scale 2: 60 fps under
## --fixed-fps 120), standing still, walking, crouched and crouch walking at one. Throw cycle: the next
## spear's and the next tomahawk's draw after a throw, standing still, running, crouched and crouch walking,
## and standing still at half the frame rate. Also: switching away from a throwable with none left shows no
## model through the holster.

const THROWABLES := ["spear", "tomahawk", "atlatl"]
const SPEAR_CHAIN := ["musket", "spear", "bow", "spear", "pistol", "spear", "atlatl", "spear", "tomahawk", "spear", "musket"]
const TOMA_CHAIN := ["musket", "tomahawk", "bow", "tomahawk", "pistol", "tomahawk", "atlatl", "tomahawk", "musket"]
## Move configurations: name, keys, crouched, physics ticks per rendered frame, time scale, chains.
const CONFIGS := [["run", ["move_forward"], false, 1, 1.0, ["spear", "tomahawk"]], ["sprint", ["move_forward", "sprint"], false, 1, 1.0, ["spear", "tomahawk"]],
		["run", ["move_forward"], false, 2, 1.0, ["spear", "tomahawk"]], ["sprint", ["move_forward", "sprint"], false, 2, 1.0, ["spear"]],
		["run", ["move_forward"], false, 1, 2.0, ["spear", "tomahawk"]], ["idle", [], false, 1, 1.0, ["spear", "tomahawk"]],
		["walk", ["move_forward", "walk"], false, 1, 1.0, ["spear"]], ["crouch", [], true, 1, 1.0, ["spear", "tomahawk"]],
		["crouch_walk", ["move_forward"], true, 1, 1.0, ["spear", "tomahawk"]]]
## Throw-cycle draws: name, keys, crouched, time scale.
const THROW_CASES := [["idle", [], false, 1.0], ["run", ["move_forward"], false, 1.0], ["crouch", [], true, 1.0],
		["crouch_walk", ["move_forward"], true, 1.0], ["idle", [], false, 2.0]]
## Largest distance (m) of a shown model's grip point from the hand.
const GRIP_TOL := 0.01
## Largest distance (m) of the held object from the right palm bone while it is in the hand.
const PALM_TOL := 0.12
const ROT_TOL_DEG := 1.0
## Largest turn (deg) in one rendered frame beyond the neighbouring frames' and the hand's / drawn object's.
const TURN_POP_DEG := 8.0
## Largest turn (deg) in one rendered frame, whatever the motion.
const TURN_CAP_DEG := 45.0
const CLEAR := {"r_thigh": 0.08, "l_thigh": 0.08, "torso": 0.12, "head": 0.10}
const PARTS := {"r_thigh": ["r_upper_leg", "r_knee"], "l_thigh": ["l_upper_leg", "l_knee"], "torso": ["pelvis", "spined"],
		"head": ["heada", "headb"]}
const FACE := ["nose_tip", "lip_upper_center", "lip_lower_center", "lower_mid_chin", "r_chin", "l_chin", "r_lip_corner",
		"r_cheek", "l_cheek", "brow_mid"]
const THIGH_FRAMES := 12
const THIGH_MIN := 0.03
const TORSO_MIN := 0.09
const TORSO_FRAMES := 8
## The spear's shaft may pass inside 0.10 m of the head axis on HEAD_FRAMES frames of the fast over-the-shoulder
## swing (where the long gun passes as close), never inside HEAD_MIN.
const HEAD_FRAMES := 2
const HEAD_MIN := 0.09
const SPEAR_FACE_MIN := 0.05
const SOURCE_TOL := 0.02
const CROUCH_SOURCE_TOL := 0.06
const CROUCH_FIST_TOL := 0.08
## The long gun whose draw the spear plays, about its grip (the prop bone): muzzle 1.24 m along +Z, butt
## 0.35 m behind (the musket model).
const GUN_FWD := 1.24
const GUN_BACK := 0.35
## The fist covers this much (m) of the spear's shaft either side of the grip (when the hand is within HAND_ON
## of the shaft), and the tomahawk's haft up to this height above the grip.
const GRIP_HALF := 0.06
const HAND_ON := 0.05
const TOMA_EXPOSED_Y := 0.06

var _player: FrontierPlayer
var _palm := Transform3D()
var _prop := Transform3D()
var _bone_pos := {}
var _bone_ids := {}
var _have_final := false
var _samples: Array = []
var _sampling := false
var _grips := {}
var _fast := false


class Sampler extends Node:
	var cb: Callable
	func _init() -> void:
		process_priority = 1 << 20
	func _process(_delta: float) -> void:
		cb.call_deferred()


func describe() -> String:
	return "THROW2: thrown weapons held on every rendered frame of weapon switches (to and from every weapon) and of the throw cycle's next draw (in the hand, or the spear on the long-gun draw's own object path), clear of the body and the face, no pop, taken from and put back where the loadout carries them, running / sprinting at 1 and 2 physics ticks per frame and at 60 fps, standing, walking, crouched and crouch walking; no model shown when switching away from an empty throwable"


func timeout_s() -> float:
	return 2400.0


func run(ctx: AnimTestContext) -> void:
	ctx.allow_error("on a base object of type 'Nil'")    # environment_rig.gd (another workflow) in headless runs
	Engine.time_scale = 1.0
	_player = await ctx.level()
	if _player == null:
		return
	var sk := _player.skeleton
	var palm := sk.find_bone("r_palm")
	var prop := sk.find_bone("r_hand_prop_attachment")
	for part in PARTS:
		for b in PARTS[part]:
			_bone_ids[b] = sk.find_bone(b)
	for b in FACE:
		if sk.find_bone(b) >= 0:
			_bone_ids[b] = sk.find_bone(b)
	_bone_ids["pelvis"] = sk.find_bone("pelvis")
	_bone_ids["spined"] = sk.find_bone("spined")
	_bone_ids["r_shoulder"] = sk.find_bone("r_shoulder")
	sk.skeleton_updated.connect(func() -> void:
		_palm = sk.global_transform * sk.get_bone_global_pose(palm)
		_prop = sk.global_transform * sk.get_bone_global_pose(prop)
		for b in _bone_ids:
			_bone_pos[b] = sk.global_transform * sk.get_bone_global_pose(_bone_ids[b]).origin
		_have_final = true)
	var ap := sk.get_parent().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for key in THROWABLES:
		var w: Throwable = _player.weapons[key]
		var g: Variant = _grip(ap, w.grip_clip_carry, w.grip_sample_carry)
		ctx.check(g != null, "%s: carry grip clip %s keys r_hand_prop_attachment" % [key, w.grip_clip_carry])
		_grips[key] = g
	ctx.check((_player.weapons["spear"] as Throwable).switch_path == Throwable.SwitchPath.SOURCE
			and (_player.weapons["tomahawk"] as Throwable).switch_path == Throwable.SwitchPath.STOW
			and (_player.weapons["atlatl"] as Throwable).switch_path == Throwable.SwitchPath.FIST,
			"switch paths: spear on the long-gun draw's object path, tomahawk stood up at the belt, atlatl in the fist")
	var sampler := Sampler.new()
	sampler.cb = _sample
	ctx.add_node(sampler)
	var base_hz := Engine.physics_ticks_per_second
	_fast = await AnimTestContext.faster_than_realtime(ctx.tree)
	for cfg: Array in CONFIGS:
		if (int(cfg[3]) > 1 or float(cfg[4]) > 1.0) and not _fast:
			continue
		for chain_key in cfg[5]:
			await _chain(ctx, cfg, SPEAR_CHAIN if chain_key == "spear" else TOMA_CHAIN, base_hz)
	Engine.physics_ticks_per_second = base_hz
	Engine.time_scale = 1.0
	for key in ["spear", "tomahawk"]:
		for c: Array in THROW_CASES:
			if float(c[3]) > 1.0 and not _fast:
				continue
			await _throw_cycle(ctx, key, c)
	await _empty_holster(ctx)


func _chain(ctx: AnimTestContext, cfg: Array, chain: Array, base_hz: int) -> void:
	var move: String = cfg[0]
	var tpf: int = cfg[3]
	var ts: float = cfg[4]
	Engine.physics_ticks_per_second = base_hz
	Engine.time_scale = 1.0
	ctx.release_inputs()
	_player.global_position = Vector3(0.0, 0.3, 30.0)
	_player.velocity = Vector3.ZERO
	_player.yaw = 0.0
	await _settle(ctx, chain[0])
	await _crouch(ctx, cfg[2])
	# Ticks per rendered frame: with --fixed-fps 120 one frame is 1/120 s, so 240 Hz gives two; time scale 2
	# renders a frame every 1/60 s of game time.
	var hz := base_hz * tpf if _fast else base_hz
	if not _fast and tpf == 2:
		Engine.max_fps = base_hz / 2
	Engine.physics_ticks_per_second = hz
	Engine.time_scale = ts
	for k in cfg[1]:
		Input.action_press(k)
	await ctx.idle_frames(60)
	var tag := "%s%s @%d tick(s)/frame%s" % [move, "", tpf, " at 60 fps" if ts > 1.0 else ""]
	for i in range(1, chain.size()):
		var from: String = chain[i - 1]
		var to: String = chain[i]
		_samples.clear()
		_sampling = true
		_player.switch_weapon(to)
		var seen_move := false
		for f in 900:
			await ctx.idle_frames(1)
			seen_move = seen_move or _player.horizontal_speed() > 0.8
			if _player.weapon_key == to and not _player.is_switching() and not _player.weapon.is_equipping() and f > 20:
				break
		await ctx.idle_frames(20)
		_sampling = false
		_evaluate(ctx, "%s %s->%s" % [tag, from, to], from, to, cfg[2], seen_move or move in ["idle", "crouch"], true)
		# Keep inside the field: turn round now and then (a switch takes 1-2 s at up to 5.6 m/s).
		_player.yaw += PI
	ctx.release_inputs()
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = base_hz
	await _crouch(ctx, false)
	await ctx.idle_frames(30)


func _settle(ctx: AnimTestContext, key: String) -> void:
	if _player.weapon_key != key:
		_player.switch_weapon(key)
	for i in 900:
		await ctx.idle_frames(1)
		if _player.weapon_key == key and not _player.is_switching() and not _player.weapon.is_equipping():
			break
	for k in THROWABLES:
		var tw: Throwable = _player.weapons[k]
		tw.count = tw.max_count
	await ctx.idle_frames(30)


func _crouch(ctx: AnimTestContext, on: bool) -> void:
	if _player.is_crouching != on:
		Input.action_press("crouch")
		await ctx.frames(3)
		Input.action_release("crouch")
		await ctx.frames(3)


## The throw cycle's draw of the next one: a full wind-up, the throw, the recover and the next one's draw.
func _throw_cycle(ctx: AnimTestContext, key: String, c: Array) -> void:
	ctx.release_inputs()
	Engine.time_scale = 1.0
	_player.global_position = Vector3(0.0, 0.3, 30.0)
	_player.velocity = Vector3.ZERO
	_player.yaw = 0.0
	_player.pitch = 0.0
	await _settle(ctx, key)
	await _crouch(ctx, c[2])
	for k in c[1]:
		Input.action_press(k)
	await ctx.idle_frames(90)
	Engine.time_scale = float(c[3])
	var w: Throwable = _player.weapon
	Input.action_press("fire")
	for i in 400:
		await ctx.idle_frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	await ctx.idle_frames(6)
	_samples.clear()
	_sampling = true
	Input.action_release("fire")
	for i in 900:
		await ctx.idle_frames(1)
		if w.state == Throwable.State.READY and i > 20:
			break
	await ctx.idle_frames(20)
	_sampling = false
	Engine.time_scale = 1.0
	ctx.release_inputs()
	# From the recover on: the held object is hidden from the release until the draw of the next one shows it.
	var from_recover: Array = []
	for s: Dictionary in _samples:
		if not from_recover.is_empty() or String(s.get("wstate", "")) == "RECOVER":
			from_recover.append(s)
	_samples = from_recover
	var tag := "throw cycle %s %s%s" % [key, c[0], " at 60 fps" if float(c[3]) > 1.0 else ""]
	_evaluate(ctx, tag, "", key, c[2], true, false)
	await _crouch(ctx, false)


## Deferred after each rendered frame's skeleton update (see the header).
func _sample() -> void:
	if not _sampling or not _have_final:
		return
	var stage := _player.switch_stage()
	if stage == "":
		stage = "draw" if _player.weapon.is_equipping() else "carry"
	var cb := _player.global_basis.orthonormalized()
	var pel: Vector3 = _bone_pos.get("pelvis", _player.global_position)
	var spd: Vector3 = _bone_pos.get("spined", pel + cb.y)
	var up_s := (spd - pel).normalized()
	var fwd_s := up_s.cross(cb.x).normalized()
	var prop_back := Vector2((_prop.origin - spd).dot(fwd_s), (_prop.origin - pel).dot(up_s))
	for key in THROWABLES:
		var w: Throwable = _player.weapons[key]
		if w.model == null or _grips.get(key) == null:
			continue
		var fist: Transform3D = _palm * (_grips[key] as Transform3D)
		var dpf := _prop.origin.distance_to(fist.origin)
		var rec := {"key": key, "stage": stage, "shown": w.model.visible, "dpf": dpf, "prop_back": prop_back,
				"wstate": Throwable.State.keys()[w.state] if w.active else "", "active": w.active,
				"cycle": w.active and w.state == Throwable.State.DRAWING}
		if key == _player.weapon_key and w.active:
			rec["phase"] = w._switch_phase()
		if not w.model.visible:
			_samples.append(rec)
			continue
		var m := w.model
		rec["rot"] = 0.0
		rec["q"] = (cb.inverse() * m.global_basis.orthonormalized()).get_rotation_quaternion()
		rec["q_prop"] = (cb.inverse() * _prop.basis.orthonormalized()).get_rotation_quaternion()
		rec["q_fist"] = (cb.inverse() * fist.basis.orthonormalized()).get_rotation_quaternion()
		var rel := m.global_position - pel
		rec["body"] = Vector3(rel.dot(cb.x), rel.dot(cb.y), rel.dot(-cb.z))
		# The back: the torso's frame (up along the pelvis -> spined line, which leans forward when running
		# and crouching; forward perpendicular to it and to the body's right).
		rec["back"] = Vector2((m.global_position - spd).dot(fwd_s), rel.dot(up_s))
		var segs: Array = []
		var fist_on := false
		if key == "spear":
			var tip := (m.get_node("Tip") as Node3D).global_position
			var butt := (m.get_node("Butt") as Node3D).global_position
			var d_hand := _seg_point(fist.origin, tip, butt)
			var d_src := _seg_point(_prop.origin, tip, butt)
			rec["d"] = minf(d_hand, d_src)
			rec["tol"] = GRIP_TOL + (0.5 * dpf if dpf > w.source_near.x and dpf < w.source_near.y else 0.0)
			rec["palm"] = _seg_point(_palm.origin, tip, butt) if dpf <= w.source_near.x else 0.0
			fist_on = d_hand <= HAND_ON
			if fist_on:
				# The shaft outside the fist: GRIP_HALF either side of the fist's point on it.
				var ax := (butt - tip).normalized()
				var g := tip + ax * clampf((fist.origin - tip).dot(ax), 0.0, tip.distance_to(butt))
				if (g - tip).length() > GRIP_HALF:
					segs.append([tip, g - ax * GRIP_HALF])
				if (butt - g).length() > GRIP_HALF:
					segs.append([g + ax * GRIP_HALF, butt])
			else:
				segs = [[tip, butt]]
			var gun := [_prop.origin + _prop.basis.z.normalized() * GUN_FWD, _prop.origin - _prop.basis.z.normalized() * GUN_BACK]
			rec["gun"] = {}
			for part in PARTS:
				rec.gun[part] = _seg_seg(gun[0], gun[1], _bone_pos[PARTS[part][0]], _bone_pos[PARTS[part][1]])
			var face := INF
			for fb in FACE:
				if _bone_pos.has(fb):
					for s: Array in segs:
						face = minf(face, _seg_point(_bone_pos[fb], s[0], s[1]))
			rec["face"] = face
		else:
			rec["d"] = m.global_position.distance_to(fist.origin)
			rec["tol"] = GRIP_TOL
			rec["palm"] = m.global_position.distance_to(_palm.origin)
			fist_on = true
			if key == "tomahawk":
				var head := (m.get_node("Head") as Node3D).global_position
				var edge := (m.get_node("Edge") as Node3D).global_position
				segs = [[m.global_transform * Vector3(0.0, TOMA_EXPOSED_Y, 0.0), head], [head, edge]]
		rec["fist_on"] = fist_on
		if w.carry_in_fist and w.aim <= 0.0 and stage == "carry":
			var want := fist.basis.orthonormalized() * w.fist_basis.orthonormalized()
			rec.rot = rad_to_deg(want.get_rotation_quaternion().angle_to(m.global_basis.orthonormalized().get_rotation_quaternion()))
		if not segs.is_empty():
			rec["clear"] = {}
			rec["fist_clear"] = {}
			for part in PARTS:
				var d := INF
				for s: Array in segs:
					d = minf(d, _seg_seg(s[0], s[1], _bone_pos[PARTS[part][0]], _bone_pos[PARTS[part][1]]))
				rec.clear[part] = d
				rec.fist_clear[part] = _seg_point(fist.origin, _bone_pos[PARTS[part][0]], _bone_pos[PARTS[part][1]])
		_samples.append(rec)


## Evaluates the samples of one switch (from -> to) or one throw cycle (from ""). crouch: crouched limits.
func _evaluate(ctx: AnimTestContext, label: String, from: String, to: String, crouch: bool, seen_move: bool, switch := true) -> void:
	var stages := {}
	var bad_hold := 0
	var worst_hold := 0.0
	var worst_palm := 0.0
	var worst_rot := 0.0
	var n := 0
	var clear := {}          # key -> part -> [min, frames inside]
	var face := {}           # key -> min
	var src_excess := 0.0
	var src_at := ""
	var fist_excess := 0.0
	var fist_at := ""
	var first := {}
	var last := {}
	var turns := {}          # key -> [[turn, ref turn], ...] over consecutive shown frames
	var prev := {}
	var sling_before := {}   # key -> the draw's object was at the sling before the key first showed
	for s: Dictionary in _samples:
		var k: String = s.key
		if not bool(s.shown):
			prev.erase(k)
			# The spear's draw: its object at the sling (behind the upper spine, 0.25 m up the torso, 0.5 m out).
			if k == "spear" and not first.has(k) and float(s.dpf) >= 0.5 and (s.prop_back as Vector2).x <= 0.0 and (s.prop_back as Vector2).y >= 0.25:
				sling_before[k] = true
			continue
		n += 1
		stages["%s/%s" % [k, s.stage]] = true
		if not first.has(k):
			first[k] = s
		last[k] = s
		worst_hold = maxf(worst_hold, float(s.d))
		if float(s.d) > float(s.tol):
			bad_hold += 1
		worst_palm = maxf(worst_palm, float(s.palm))
		worst_rot = maxf(worst_rot, float(s.rot))
		if prev.has(k):
			var p: Dictionary = prev[k]
			var t := rad_to_deg((s.q as Quaternion).angle_to(p.q))
			var r := maxf(rad_to_deg((s.q_prop as Quaternion).angle_to(p.q_prop)), rad_to_deg((s.q_fist as Quaternion).angle_to(p.q_fist)))
			if not turns.has(k):
				turns[k] = []
			turns[k].append([t, r])
		else:
			if turns.has(k):
				turns[k].append([-1.0, 0.0])      # a gap
		prev[k] = s
		if s.has("clear"):
			if not clear.has(k):
				clear[k] = {}
			for part in s.clear:
				var d := float(s.clear[part])
				var cur: Array = clear[k].get(part, [INF, 0])
				cur[0] = minf(cur[0], d)
				if d < float(CLEAR[part]):
					cur[1] += 1
				clear[k][part] = cur
				var fe := minf(float(s.fist_clear[part]), float(CLEAR[part])) - minf(d, float(CLEAR[part])) if bool(s.fist_on) else 0.0
				if fe > fist_excess:
					fist_excess = fe
					fist_at = "%s %s %s (%.3f m, the fist %.3f m)" % [k, s.stage, part, d, float(s.fist_clear[part])]
				if s.has("gun") and s.stage != "carry":
					var ex := minf(float(s.gun[part]), float(CLEAR[part])) - d
					if ex > src_excess:
						src_excess = ex
						src_at = "%s %s %s (%.3f m, the gun %.3f m)" % [k, s.stage, part, d, float(s.gun[part])]
		if s.has("face"):
			face[k] = minf(float(face.get(k, INF)), float(s.face))
	# Pops: a frame's turn beyond its neighbours' and the hand's / drawn object's.
	var worst_turn := 0.0
	var worst_pop := 0.0
	var worst_beyond := 0.0
	for k in turns:
		var tl: Array = turns[k]
		for i in tl.size():
			var t := float(tl[i][0])
			if t < 0.0:
				continue
			worst_turn = maxf(worst_turn, t)
			worst_beyond = maxf(worst_beyond, t - float(tl[i][1]))
			var nb := float(tl[i][1])
			if i > 0:
				nb = maxf(nb, float(tl[i - 1][0]))
			if i + 1 < tl.size():
				nb = maxf(nb, float(tl[i + 1][0]))
			worst_pop = maxf(worst_pop, t - nb)
	var parts := []
	for k in clear:
		for part in clear[k]:
			parts.append("%s %s %.3f (%d)" % [k, part, clear[k][part][0], clear[k][part][1]])
	for k in face:
		parts.append("%s face %.3f" % [k, face[k]])
	ctx.info("%s: %d samples, stages %s; held within %.4f m (%d over), palm %.3f m, fist turn %.2f deg; turn %.1f deg/frame, %.1f beyond the hand / drawn object, pop %.1f; closest %s; deeper than the fist by %.3f m (%s); spear deeper than the long gun by %.3f m (%s)" % [
			label, n, ", ".join(stages.keys()), worst_hold, bad_hold, worst_palm, worst_rot, worst_turn, worst_beyond, worst_pop, ", ".join(parts), fist_excess, fist_at, src_excess, src_at])
	ctx.check(seen_move, "%s: the body was moving through the switch" % label)
	ctx.check(n > 0 and bad_hold == 0, "%s: every shown thrown weapon held (in the hand within %.2f m, or the spear on the draw's own object; worst %.4f m)" % [label, GRIP_TOL, worst_hold])
	ctx.check(worst_palm <= PALM_TOL, "%s: in the hand within %.2f m of the palm bone (worst %.3f m)" % [label, PALM_TOL, worst_palm])
	ctx.check(worst_rot <= ROT_TOL_DEG, "%s: carried, the tomahawk turns with the fist (within %.1f deg; worst %.2f)" % [label, ROT_TOL_DEG, worst_rot])
	ctx.check(worst_pop <= TURN_POP_DEG and worst_turn <= TURN_CAP_DEG, "%s: no pop (a frame's turn at most %.1f deg beyond its neighbours' and the hand's / drawn object's, <= %.0f; largest %.1f deg, <= %.0f)" % [
			label, worst_pop, TURN_POP_DEG, worst_turn, TURN_CAP_DEG])
	if crouch:
		ctx.check(fist_excess <= CROUCH_FIST_TOL, "%s: crouched, in the hand no part outside the fist deeper in the body than the fist (by %.3f m <= %.2f)" % [label, fist_excess, CROUCH_FIST_TOL])
		var fmin := INF
		for k in face:
			fmin = minf(fmin, float(face[k]))
		ctx.check(fmin >= SPEAR_FACE_MIN, "%s: crouched, the spear's shaft never inside %.2f of the face (closest %.3f m)" % [label, SPEAR_FACE_MIN, fmin])
	ctx.check(src_excess <= (CROUCH_SOURCE_TOL if crouch else SOURCE_TOL),
			"%s: the spear no deeper in the body than the long gun whose draw it plays (by %.3f m <= %.2f)" % [label, src_excess, CROUCH_SOURCE_TOL if crouch else SOURCE_TOL])
	if not crouch:
		var bad := []
		for k in clear:
			var c: Dictionary = clear[k]
			for th in ["r_thigh", "l_thigh"]:
				if c.has(th) and (int(c[th][1]) > THIGH_FRAMES or float(c[th][0]) < THIGH_MIN):
					bad.append("%s %s %d frames, %.3f m" % [k, th, c[th][1], c[th][0]])
			if c.has("torso") and (float(c.torso[0]) < TORSO_MIN or int(c.torso[1]) > TORSO_FRAMES):
				bad.append("%s torso %d frames, %.3f m" % [k, c.torso[1], c.torso[0]])
			if c.has("head") and (int(c.head[1]) > (HEAD_FRAMES if k == "spear" else 0) or float(c.head[0]) < HEAD_MIN):
				bad.append("%s head %d frames, %.3f m" % [k, c.head[1], c.head[0]])
		for k in face:
			if float(face[k]) < SPEAR_FACE_MIN:
				bad.append("%s face %.3f m" % [k, face[k]])
		ctx.check(bad.is_empty(), "%s: clear of the body (thighs at most %d frames inside 0.08 m and never inside %.2f; torso never inside %.3f, at most %d frames inside 0.12; head never inside %.2f, the spear at most %d frames inside 0.10; the spear's shaft never inside %.2f of the face)%s" % [
				label, THIGH_FRAMES, THIGH_MIN, TORSO_MIN, TORSO_FRAMES, HEAD_MIN, HEAD_FRAMES, SPEAR_FACE_MIN, (": " + "; ".join(bad)) if not bad.is_empty() else ""])
	# Each throwable is shown through its draw (switched to, or taken after a throw) and its holster (from), and
	# comes from / goes to where the loadout carries it.
	if to in THROWABLES:
		ctx.check(stages.has("%s/draw" % to) or stages.has("%s/carry" % to), "%s: %s shown during its draw" % [label, to])
		if first.has(to):
			_check_where(ctx, label, to, "appears", first[to], bool(sling_before.get(to, false)), switch)
	if from in THROWABLES:
		ctx.check(stages.has("%s/holster" % from), "%s: %s shown during its holster" % [label, from])
		if last.has(from):
			_check_where(ctx, label, from, "vanishes", last[from], true, true)


## Where a draw shows the object first and a holster last: the spear behind the back (in the torso's frame:
## behind the upper spine, at least 0.25 m up it from the pelvis) when the draw took its object to the sling
## before (sling), else in the hand from mid-draw; the tomahawk behind the hip plane (pelvis frame, x right, y
## up, z forward), or in the fist from mid-draw.
func _check_where(ctx: AnimTestContext, label: String, key: String, what: String, s: Dictionary, sling: bool, switch: bool) -> void:
	var p: Vector3 = s.body
	var bk: Vector2 = s.back
	var mid := float(s.get("phase", -1.0)) >= 0.45 or float(s.get("phase", -1.0)) < 0.0     # from mid-draw, or after it
	match key:
		"spear":
			var on_back := bk.x <= 0.0 and bk.y >= 0.25
			if what == "vanishes":
				ctx.check(on_back, "%s: the spear %s on the back (%.2f m behind the upper spine, %.2f m up the torso; %.2f, %.2f, %.2f m from the pelvis)" % [
						label, what, -bk.x, bk.y, p.x, p.y, p.z])
			else:
				var in_hand := bool(s.fist_on) and mid and not sling
				ctx.check(on_back or in_hand, "%s: the spear %s on the back (%.2f m behind the upper spine, %.2f m up the torso), or, when the draw never took its object to the sling (%s), in the hand from mid-draw (%s, phase %.2f)" % [
						label, what, -bk.x, bk.y, "it did" if sling else "it did not", "on the shaft" if bool(s.fist_on) else "not in the hand", float(s.get("phase", -1.0))])
		"tomahawk":
			var behind := p.z <= 0.05
			ctx.check(behind or (mid and bool(s.fist_on)), "%s: the tomahawk %s at the back of the belt (%.2f, %.2f, %.2f m from the pelvis: not in front of the hip)%s" % [
					label, what, p.x, p.y, p.z, "" if behind else ", or in the fist from mid-draw (phase %.2f)" % float(s.get("phase", -1.0))])


## Switching away from a throwable with none left: the holster shows no model (THROW2 review).
func _empty_holster(ctx: AnimTestContext) -> void:
	ctx.release_inputs()
	for key in ["spear", "tomahawk"]:
		await _settle(ctx, key)
		var w: Throwable = _player.weapons[key]
		var keep := w.count
		w.count = 0
		await ctx.frames(10)
		var shown := 0
		var frames := 0
		# (drawn from the musket, the musket waits in the left hand: QuickOffhand, push n01c; the empty hand then
		# takes the stock with no holster at all)
		var quick := String(_player.get("offhand_key")) == "musket"
		_player.switch_weapon("musket")
		for i in 600:
			await ctx.idle_frames(1)
			if _player.is_switching():
				frames += 1
				if w.model.visible:
					shown += 1
			if _player.weapon_key == "musket" and not _player.is_switching() and not _player.weapon.is_equipping():
				break
		w.count = keep
		if quick:
			ctx.check(shown == 0 and String(_player.get("offhand_key")) == "" and _player.weapon_key == "musket",
					"%s with none left -> musket (the musket in the left hand): the empty hand takes the stock, no model shown (%d of %d switch frames)" % [key, shown, frames])
		else:
			ctx.check(frames > 0 and shown == 0, "%s with none left -> musket: no model through the holster (%d of %d switch frames)" % [key, shown, frames])


static func _seg_point(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Closest distance between segments p1-q1 and p2-q2.
static func _seg_seg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return p1.distance_to(p2)
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var bb := d1.dot(d2)
			var den := a * e - bb * bb
			s = clampf((bb * f - c * e) / den, 0.0, 1.0) if den != 0.0 else 0.0
			t = (bb * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((bb - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


## Prop key of `clip` at `t` relative to the palm (the grip), read from the library; null when absent.
func _grip(ap: AnimationPlayer, clip: String, t: float) -> Variant:
	var path := StringName("actor_b/" + clip)
	if not ap.has_animation(path):
		return null
	var a := ap.get_animation(path)
	var rot: Variant = null
	var pos := Vector3.ZERO
	for i in a.get_track_count():
		if String(a.track_get_path(i).get_concatenated_subnames()) != "r_hand_prop_attachment":
			continue
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rot = a.rotation_track_interpolate(i, t)
		elif a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			pos = a.position_track_interpolate(i, t)
	if rot == null:
		return null
	return Transform3D(Basis(rot as Quaternion), pos)
