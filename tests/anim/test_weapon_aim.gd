extends AnimTestSuite
## WP7 (plan section 10 test_weapon_aim; user requirements: weapons raised only while aiming,
## zeroed shots from the muzzle / the bow's arrow tip, the crosshair a centre dot): in the real
## level, the angle between the weapon's barrel (model -Z: the muzzle's forward; the bow's arrow
## line) and the line from the muzzle to player.get_aim_point() (what the crosshair is on; shots
## fly muzzle -> that point).
##
## 1. AIM_IDLE, standing and crouched (the crouched bow canted sideways), camera pitch -40..+40
##    in 10 degree steps, every weapon: <= 3 deg. Firearms raised with RMB, the bow drawn with LMB
##    (let down with RMB between pitches, so it never reaches the fatigue tremble).
## 2. Aimed movement (masked aim tree over the locomotion + AimStabilizer; Weapon.aim = 1, speed
##    capped at aim_walk_speed): walk and run keys fw / lt / rt / bw and crouch fw / lt / rt / bw,
##    every frame of a 1 s window: max <= 4.5 deg, median <= 2.5 deg.
## 3. The bow's nocked arrow while drawn: placed in Skeleton3D.skeleton_updated after the
##    skeleton's modifiers (AimStabilizer, the skinned body's helpers), so Bow.launch_origin() is
##    the arrow tip on the final pose.
## 4. Shot cancel (Firearm: RMB or R while LMB holds the weapon up): shot_cancelled, still loaded,
##    and the upper body lowers smoothly like an aim release without a shot: Weapon.aim and the
##    upper aim weight fall monotonically at the weapon's aim_out_time, and the core bones and the
##    weapon's prop bone turn no faster than 25 rad/s per frame (test_continuity's raise / lower
##    limit), measured on the post-modifier pose.
## Faster with --fixed-fps 120.

const PITCHES := [-40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0]
const IDLE_MAX_DEG := 3.0
const MOVE_MAX_DEG := 4.5
const MOVE_MEDIAN_DEG := 2.5
const MOVES := [["walk", "W"], ["walk", "A"], ["walk", "D"], ["walk", "S"], ["run", "W"], ["run", "A"], ["run", "D"],
		["run", "S"], ["crouch", "W"], ["crouch", "A"], ["crouch", "D"], ["crouch", "S"]]
const LIMIT_RAD_S := 25.0

var _sk: Skeleton3D
var _bones := PackedInt32Array()
var _names := PackedStringArray()
var _prev: Array[Quaternion] = []
var _peak := 0.0
var _peak_at := ""
var _frames := 0
var _tag := ""
var _arrow_err := -1.0
var _arrow_n := 0
var _dir_errs := []
var _player: Node
var _bow: Bow


func describe() -> String:
	return "WP7 weapon aim in the level: AIM_IDLE pitch -40..40 (<= 3 deg), aimed walk / run / crouch (<= 4.5, median <= 2.5), the bow's arrow tip after the modifiers, shot cancel lowers smoothly"


func timeout_s() -> float:
	return 900.0


func run(ctx: AnimTestContext) -> void:
	var player = await ctx.level()
	if player == null:
		return
	var weapons: Array = String(ctx.arg("weapons", "bow,musket,pistol")).split(",")
	await _aim_idle(ctx, player, weapons)
	await _moving(ctx, player, weapons)
	await _bow_arrow(ctx, player)
	await _shot_cancel(ctx, player)


# --- helpers ----------------------------------------------------------------------------------

## [total, yaw, pitch] in degrees: barrel (model -Z) vs muzzle -> crosshair point.
static func aim_error(player: Node) -> Array:
	var w: Weapon = player.weapon
	var target: Vector3 = player.get_aim_point()
	var to := (target - w.muzzle.global_position).normalized()
	var fwd := -w.model.global_basis.z.normalized()
	var dyaw := rad_to_deg(Vector2(to.x, to.z).angle_to(Vector2(fwd.x, fwd.z)))
	var dpitch := rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0)) - asin(clampf(to.y, -1.0, 1.0)))
	return [rad_to_deg(fwd.angle_to(to)), dyaw, dpitch]


static func _raise_action(key: String) -> String:
	return "fire" if key == "bow" else "aim"


func _equip(ctx: AnimTestContext, player: Node, key: String, crouch: bool) -> void:
	player.switch_weapon(key)
	await ctx.frames(150)
	# The graph weapon switch (holster, finish, grab, then the draw) takes up to about 1.6 s.
	var w8 := 0
	while (player.is_switching() or player.weapon.is_equipping()) and w8 < 480:
		await ctx.frames(1)
		w8 += 1
	await FootSlip._set_crouch(ctx.tree, player, crouch, ctx)
	await ctx.frames(30)


static func _median(a: Array) -> float:
	if a.is_empty():
		return NAN
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2]) if s.size() % 2 == 1 else 0.5 * (float(s[s.size() / 2 - 1]) + float(s[s.size() / 2]))


# --- 1. AIM_IDLE ------------------------------------------------------------------------------

func _aim_idle(ctx: AnimTestContext, player: Node, weapons: Array) -> void:
	var hz := float(Engine.physics_ticks_per_second)
	for crouch in [false, true]:
		for key: String in weapons:
			await _equip(ctx, player, key, crouch)
			var start = FootSlip._clear_start(player, 4.0)
			if start != null:
				player.global_position = Vector3(start.x, 0.05, start.y)
			player.yaw = 0.0
			var worst := 0.0
			var worst_at := 0.0
			var row := []
			var states := {}
			for pitch_deg: float in PITCHES:
				player.pitch = deg_to_rad(pitch_deg)
				if key == "bow" or row.is_empty():
					Input.action_press(_raise_action(key))
				await ctx.frames(int(0.8 * hz))
				var e := [0.0, 0.0, 0.0]
				for i in 6:
					await ctx.idle_frames(1)
					var ei := aim_error(player)
					for k in 3:
						e[k] += ei[k] / 6.0
				states[String(player.anim.loco.state)] = true
				row.append("%+.0f: %.2f (yaw %+.2f pitch %+.2f)" % [pitch_deg, e[0], e[1], e[2]])
				if e[0] > worst:
					worst = e[0]
					worst_at = pitch_deg
				ctx.metric("idle_%s_%s_%+d" % [key, "crouch" if crouch else "stand", int(pitch_deg)], snappedf(e[0], 0.01))
				if key == "bow":
					# Let the string down (RMB), no shot; LMB must be released before the next draw.
					Input.action_press("aim")
					await ctx.frames(3)
					Input.action_release("fire")
					Input.action_release("aim")
					await ctx.frames(int(0.3 * hz))
			if key != "bow":
				Input.action_release("aim")
			await ctx.frames(int(0.5 * hz))
			player.pitch = 0.0
			var tag := "%s %s" % [key, "crouched" if crouch else "standing"]
			ctx.info("AIM_IDLE %s (lower states %s): %s" % [tag, states.keys(), ", ".join(row)])
			ctx.check(states.has("AIM_IDLE"), "%s: the lower body is in AIM_IDLE while raised (%s)" % [tag, states.keys()])
			ctx.at_most(worst, IDLE_MAX_DEG, "%s AIM_IDLE, camera pitch -40..+40: worst barrel vs crosshair line (deg) [at %+.0f]" % [tag, worst_at])
	await FootSlip._set_crouch(ctx.tree, player, false, ctx)


# --- 2. aimed movement ------------------------------------------------------------------------

func _moving(ctx: AnimTestContext, player: Node, weapons: Array) -> void:
	var hz := float(Engine.physics_ticks_per_second)
	var all := []
	for key: String in weapons:
		for mv: Array in MOVES:
			var mode: String = mv[0]
			var dir: String = mv[1]
			await _equip(ctx, player, key, mode == "crouch")
			var acts: Array = FootSlip.DIRS[dir]
			var iv := Vector2.ZERO
			for a: String in acts:
				iv += {"move_forward": Vector2(0, -1), "move_back": Vector2(0, 1), "move_left": Vector2(-1, 0), "move_right": Vector2(1, 0)}[a]
			iv = iv.normalized()
			var start = FootSlip._clear_start(player, 12.0)
			if start == null:
				ctx.fail("%s %s/%s: no clear corridor" % [key, mode, dir])
				continue
			player.global_position = Vector3(start.x, 0.05, start.y)
			player.velocity = Vector3.ZERO
			player.yaw = FootSlip._heading(FootSlip.TRAVEL) - FootSlip._heading(Vector3(iv.x, 0, iv.y))
			player.pitch = 0.0
			await ctx.frames(20)
			Input.action_press(_raise_action(key))
			await ctx.frames(int(0.6 * hz))
			if mode == "walk":
				Input.action_press("walk")
			for a: String in acts:
				Input.action_press(a)
			await ctx.frames(int(0.8 * hz))
			var errs := []
			var aim_min := 1.0
			var speed := 0.0
			var states := {}
			for i in int(1.0 * hz):
				await ctx.frames(1)
				var e := aim_error(player)
				errs.append(e[0])
				aim_min = minf(aim_min, float(player.weapon.aim))
				speed += float(player.horizontal_speed()) / hz
				states[String(player.anim.loco.state)] = true
			if key == "bow":
				Input.action_press("aim")    # let the string down (no shot)
				await ctx.frames(3)
			ctx.release_inputs()
			var tag := "%s %s/%s" % [key, mode, dir]
			var med := _median(errs)
			var mx: float = errs.max()
			all.append_array(errs)
			ctx.info("aimed %s: median %.2f max %.2f deg, aim >= %.2f, %.2f m/s, lower %s" % [tag, med, mx, aim_min, speed, states.keys()])
			ctx.metric("move_%s_%s_%s_max" % [key, mode, dir], snappedf(mx, 0.01))
			ctx.check(aim_min >= 0.999, "%s: Weapon.aim = 1 through the window (%.3f)" % [tag, aim_min])
			ctx.at_most(mx, MOVE_MAX_DEG, "%s aimed while moving: max barrel vs crosshair line (deg)" % tag)
			ctx.at_most(med, MOVE_MEDIAN_DEG, "%s aimed while moving: median (deg)" % tag)
			await ctx.frames(int(0.4 * hz))
	if not all.is_empty():
		ctx.info("aimed movement, all weapons and cases: median %.2f deg, max %.2f deg over %d frames" % [_median(all), all.max(), all.size()])
	await FootSlip._set_crouch(ctx.tree, player, false, ctx)


# --- 3. the bow's arrow -----------------------------------------------------------------------

func _bow_arrow(ctx: AnimTestContext, player: Node) -> void:
	await _equip(ctx, player, "bow", false)
	_bow = player.weapon as Bow
	_sk = player.skeleton
	player.pitch = deg_to_rad(10.0)
	Input.action_press("fire")
	await ctx.frames(90)
	_arrow_err = -1.0
	_arrow_n = 0
	_dir_errs.clear()
	_player = player
	_sk.skeleton_updated.connect(_on_arrow_check)
	for i in 30:
		await ctx.idle_frames(1)
	_sk.skeleton_updated.disconnect(_on_arrow_check)
	var nocked: Node3D = _bow.model.get_node_or_null("NockedArrow")
	ctx.check(_bow.is_drawn() and nocked != null and nocked.visible, "bow drawn: the nocked arrow is on the string")
	ctx.check(_arrow_n >= 20 and _arrow_err >= 0.0 and _arrow_err < 1e-4,
			"Bow.launch_origin() is the arrow tip on the final (post-modifier) pose, placed in skeleton_updated (%d updates, max %s m)" % [_arrow_n, AnimTestContext.fmt(_arrow_err)])
	if not _dir_errs.is_empty():
		ctx.info("bow drawn, pitch +10: arrow (nock -> tip) vs tip -> crosshair point: median %.2f deg, max %.2f deg (zeroed shots leave the tip toward the point)" % [_median(_dir_errs), _dir_errs.max()])
	Input.action_press("aim")
	await ctx.frames(3)
	ctx.release_inputs()
	player.pitch = 0.0
	await ctx.frames(60)


func _nock_pos() -> Vector3:
	var n := Vector3.ZERO
	var c := 0
	for b in ["r_indexb", "r_middleb"]:
		var i := _sk.find_bone(b)
		if i >= 0:
			n += (_sk.global_transform * _sk.get_bone_global_pose(i)).origin
			c += 1
	return n / maxi(c, 1)


func _on_arrow_check() -> void:
	# Runs after the bow's own handler (connected later): the same nock -> arrow rest line.
	var nock := _nock_pos()
	var rest := _bow.muzzle.global_position
	var d := rest - nock
	if d.length_squared() < 0.0025:
		return
	var tip := nock + d.normalized() * Bow.ARROW_LENGTH
	_arrow_err = maxf(_arrow_err, tip.distance_to(_bow.launch_origin()))
	_arrow_n += 1
	_dir_errs.append(rad_to_deg(d.angle_to(_player.get_aim_point() - tip)))


# --- 4. shot cancel ---------------------------------------------------------------------------

func _shot_cancel(ctx: AnimTestContext, player: Node) -> void:
	var hz := float(Engine.physics_ticks_per_second)
	_sk = player.skeleton
	_bones = PackedInt32Array()
	_names = PackedStringArray()
	var ap: AnimationPlayer = _sk.get_parent().find_children("*", "AnimationPlayer", true, false)[0]
	var run := ap.get_animation("actor_b/actor_b-p-run-fw")
	var seen := {}
	for t in run.get_track_count():
		var p := String(run.track_get_path(t))
		var bn := p.get_slice(":", 1)
		var b := _sk.find_bone(bn)
		if b >= 0 and not seen.has(b):
			seen[b] = true
			_bones.append(b)
			_names.append(bn)
	for key in ["musket", "pistol"]:
		for how in ["R", "RMB", "release"]:
			for raise_frames in [int(0.15 * hz), int(0.6 * hz)]:
				await _equip(ctx, player, key, false)
				var w: Firearm = player.weapon
				var prop := _sk.find_bone("r_hand_prop_attachment" if w.hand == Weapon.Hand.RIGHT else "l_hand_prop_attachment")
				if _bones.size() == seen.size():
					_bones.append(prop)
					_names.append("prop")
				else:
					_bones[_bones.size() - 1] = prop
				var cancelled := [0]
				var fired := [0]
				var on_c := func() -> void: cancelled[0] += 1
				var on_f := func() -> void: fired[0] += 1
				w.shot_cancelled.connect(on_c)
				w.fired.connect(on_f)
				# Raise: LMB (shoulder, fires on release) or, for the plain release, RMB (steady aim).
				Input.action_press("aim" if how == "release" else "fire")
				await ctx.frames(raise_frames)
				var aim0 := w.aim
				_peak = 0.0
				_peak_at = ""
				_frames = 0
				_prev.clear()
				_sk.skeleton_updated.connect(_on_updated)
				var aims := []
				var ups := []
				match how:
					"R":
						Input.action_press("reload")
					"RMB":
						Input.action_press("aim")
					"release":
						Input.action_release("aim")
				_tag = "%s %s" % [key, how]
				for i in int(0.6 * hz):
					await ctx.frames(1)
					if how == "RMB" and i == 3:
						Input.action_release("aim")   # RMB held keeps a steady aim; its release lowers
					if i == 3:
						Input.action_release("reload")
					aims.append(w.aim)
					ups.append(player.anim.upper.upper_aim_w())
				await ctx.idle_frames(2)
				_sk.skeleton_updated.disconnect(_on_updated)
				Input.action_release("fire")
				await ctx.frames(int(0.4 * hz))
				w.shot_cancelled.disconnect(on_c)
				w.fired.disconnect(on_f)
				var mono := true
				var max_step := 0.0
				# RMB held keeps the steady aim (gameplay: RMB raises without firing): judged from its
				# release on.
				for i in range(5 if how == "RMB" else 1, ups.size()):
					if float(ups[i]) > float(ups[i - 1]) + 1e-6 or float(aims[i]) > float(aims[i - 1]) + 1e-6:
						mono = false
					max_step = maxf(max_step, float(ups[i - 1]) - float(ups[i]))
				var tag := "%s: %s after %.2f s of raise (aim %.2f)" % [key, {"R": "R while LMB held", "RMB": "RMB while LMB held",
						"release": "RMB released (aim release without a shot, reference)"}[how], raise_frames / hz, aim0]
				if how != "release":
					ctx.check(cancelled[0] == 1 and fired[0] == 0 and w.loaded and w.state == Firearm.State.READY,
							"%s: shot_cancelled, no shot, still loaded, READY" % tag)
				ctx.check(mono and float(aims[aims.size() - 1]) == 0.0 and float(ups[ups.size() - 1]) <= 1e-4,
						"%s: Weapon.aim and the upper aim weight fall monotonically to 0" % tag)
				ctx.at_most(max_step, 1.0 / (w.aim_out_time * hz) + 1e-3, "%s: upper aim weight step per frame (at most 1 / aim_out_time)" % tag)
				ctx.at_most(_peak, LIMIT_RAD_S, "%s: core bones and the weapon's prop bone, post-modifier (rad/s) [%s]" % [tag, _peak_at])


func _on_updated() -> void:
	var cur: Array[Quaternion] = []
	for b in _bones:
		cur.append(_sk.get_bone_global_pose(b).basis.get_rotation_quaternion())
	var dt := _sk.get_process_delta_time()
	if _prev.size() == cur.size() and dt > 0.0:
		for i in cur.size():
			var q: Quaternion = _prev[i].inverse() * cur[i]
			var s := 2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w)) / dt
			if s > _peak:
				_peak = s
				_peak_at = "%s f%d" % [_names[i], _frames]
	_prev = cur
	_frames += 1
