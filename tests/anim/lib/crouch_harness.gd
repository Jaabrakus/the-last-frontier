class_name CrouchHarness
extends RefCounted
## Shared crouch <-> stand measurement harness (CROUCH_HANDS; tests/anim/test_crouch_transitions.gd and
## tools/anim/crouch_strips.gd). It drives the REAL player (FrontierPlayer, built in code as in the game, with its
## PlayerAnim graph tree, UpperBody, AimStabilizer, PropFlipGuard and the skinned body's modifier) through a crouch
## toggle case with Input.action_press, on a flat, empty arena (a 400 m floor at y = 0; no level geometry, so
## nothing but the animation decides the result), and records every pose update (Skeleton3D.skeleton_updated:
## the final pose after every SkeletonModifier3D, what the player sees).
##
## A case runs:  spawn (a fresh player every case) -> the weapon drawn -> the start stance -> the input held (walk /
## sprint modifier, aim, direction keys) -> settle until the lower body is steady -> PRE window (PRE_S) -> the
## toggle -> TRANS window (until the target stance is steady and every blend is over, at most TRANS_MAX_S) -> POST
## window (POST_S). The PRE and POST windows are the case's own locomotion baseline (the same run without a toggle,
## in the start and in the target stance); the TRANS window is compared with them (analyze()).
##
## Per frame: pelvis height (pelvis bone world y - the player's origin y), the skeleton-space angular speed of every
## CORE bone, the four foot points' world height and horizontal world speed, body velocity, the lower body's state /
## graph state / mode / stance, every weighted lower input (clip, weight, gait phase: left plant 0, right plant 0.5,
## LocoBrain.gait_phase), the upper stance selector's crouch weight, the crouch-change additive OneShots, and every
## lower-body transition (PlayerAnim.anim_transition: key, graph record, fade).
##
## Needs --fixed-fps 120 (one pose update per 120 Hz physics tick: deterministic and the foot speed is a plain
## world-space finite difference; real time still runs, with frame-timing jitter in the foot speeds).
## This harness only reads the animation data.

## Bones whose per-frame rotation is checked for pops (skeleton space, after all modifiers).
const CORE := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck", "heada",
		"l_upper_leg", "l_knee", "l_ankle", "l_ball", "r_upper_leg", "r_knee", "r_ankle", "r_ball",
		"l_clavicle", "l_shoulder", "l_elbow", "l_wrist", "r_clavicle", "r_shoulder", "r_elbow", "r_wrist",
		"l_hand_prop_attachment", "r_hand_prop_attachment"]
const FEET := ["l_heel", "l_ball", "r_heel", "r_ball"]
## A foot point is planted while its world height is within this of its lowest height in the run (FootSlip's rule).
const PLANTED_TOL := 0.02
## Planted-state debounce for step detection (frames).
const STEP_DEBOUNCE := 3
## Lower body steady: this long in its state with the lower selector, the upper stance selector and the crouch-change
## additive all settled.
const STEADY_S := 0.5
const SETTLE_MAX_S := 7.0
const PRE_S := 1.0
const POST_S := 1.0
const TRANS_MAX_S := 7.0
## Frames after the settle frame that still belong to TRANS.
const TRANS_TAIL_S := 0.1
## Spike neighbourhood (frames each side).
const SPIKE_NB := 3
## Sliding window for the peak slip (s).
const PEAK_WIN_S := 0.25

## Gates (see analyze() and tests/anim/test_crouch_transitions.gd for the justification).
const SPIKE_K := 2.0
const SPIKE_FLOOR := 4.0          ## rad/s: a one-frame excess of 4 rad/s at 120 Hz = 1.9 deg in a frame
const PELVIS_JERK_K := 2.0
const PELVIS_JERK_FLOOR := 0.03   ## m/s per frame (3.6 m/s^2 at 120 Hz)
const SLIP_MARGIN := 0.05         ## m/s over the baseline mean
const PEAK_SLIP_MARGIN := 0.10    ## m/s over the baseline's peak 0.25 s mean
const MISMATCH_MAX := 0.15        ## gait-phase mismatch of two weighted locomotion banks (0.5 = feet opposite)
const INPLACE_MAX_S := 0.15       ## s of an in-place (non-stepping) clip at >= 0.5 weight while the body moves >= 0.5 m/s
const ENVELOPE_M := 0.05          ## m the pelvis may leave the two stances' own height range during TRANS
const SWING_MARGIN := 0.5         ## m/s: a low foot moving along the travel faster than the body + this is swinging

## Special kinds measured against a companion run (the same case without the crouch press).
const COMPANION_KINDS := ["spawn", "air", "land", "cjump"]
const DIR_KEYS := {
	"none": [], "W": ["move_forward"], "A": ["move_left"], "S": ["move_back"], "D": ["move_right"],
	"WA": ["move_forward", "move_left"], "WD": ["move_forward", "move_right"],
	"SA": ["move_back", "move_left"], "SD": ["move_back", "move_right"],
}

var tree: SceneTree
var ctx: Object = null
var arena: Node3D
var player: FrontierPlayer
var sk: Skeleton3D
var anim: PlayerAnim
## Per-frame records (see _on_updated()).
var frames: Array = []
var recording := false
var phase := "setup"
## Lower-body transitions seen while recording: {i, from, to, from_graph, to_graph, key, record, fade}.
var transitions: Array = []
## Called after every recorded frame with (harness, record); the strips tool captures images from it.
var on_frame := Callable()
## FrontierPlayer properties set before it enters the tree (e.g. {"override_crouch_crossfade": true}: its
## "Gameplay overrides" are copied onto PlayerAnim in _ready).
var player_props := {}
var _core_idx := PackedInt32Array()
var _foot_idx := PackedInt32Array()
var _pelvis := -1
var _prev_q: Array = []
var _prev_foot: Array = []
var _frame_no := 0


func _init(p_tree: SceneTree, p_ctx: Object = null) -> void:
	tree = p_tree
	ctx = p_ctx


# --- arena and player ------------------------------------------------------------------------

## A flat 400 x 400 m floor (top at y = 0) under the root, created once.
func ensure_arena() -> Node3D:
	if arena != null and is_instance_valid(arena):
		return arena
	arena = Node3D.new()
	arena.name = "CrouchArena"
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	body.add_child(cs)
	body.position.y = -0.5
	arena.add_child(body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	arena.add_child(sun)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.45, 0.40)
	pm.material = mat
	mesh.mesh = pm
	arena.add_child(mesh)
	# grid lines every metre along the travel axis, so foot slide is visible in the strips
	for k in range(-60, 61):
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(400, 0.002, 0.02) if k % 5 != 0 else Vector3(400, 0.003, 0.04)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.25, 0.27, 0.24)
		bm.material = lm
		line.mesh = bm
		line.position = Vector3(0, 0.001, float(k))
		arena.add_child(line)
	for k in range(-10, 11):
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02, 0.002, 400)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.25, 0.27, 0.24)
		bm.material = lm
		line.mesh = bm
		line.position = Vector3(float(k), 0.001, 0)
		arena.add_child(line)
	if ctx != null:
		ctx.add_node(arena)
	else:
		tree.root.add_child(arena)
	return arena


## A fresh player at the arena origin facing -Z. Returns it after `frames_after` physics frames.
func spawn(frames_after := 30) -> FrontierPlayer:
	free_player()
	ensure_arena()
	release_all()
	var p := FrontierPlayer.new()
	p.name = "Player"
	p.ignore_mouse_capture = true
	p.position = Vector3(0, 0.02, 0)
	for k in player_props:
		p.set(k, player_props[k])
	arena.add_child(p)
	player = p
	sk = p.skeleton
	anim = p.anim
	_core_idx = PackedInt32Array()
	for n in CORE:
		_core_idx.append(sk.find_bone(n))
	_foot_idx = PackedInt32Array()
	for n in FEET:
		_foot_idx.append(sk.find_bone(n))
	_pelvis = sk.find_bone("pelvis")
	_prev_q = []
	_prev_foot = []
	frames = []
	transitions = []
	recording = false
	phase = "setup"
	_frame_no = 0
	sk.skeleton_updated.connect(_on_updated)
	if anim != null and not anim.anim_transition.is_connected(_on_transition):
		anim.anim_transition.connect(_on_transition)
	await wait(frames_after)
	return p


func free_player() -> void:
	if player != null and is_instance_valid(player):
		if sk != null and is_instance_valid(sk) and sk.skeleton_updated.is_connected(_on_updated):
			sk.skeleton_updated.disconnect(_on_updated)
		player.queue_free()
		release_all()
		await wait(2)
	player = null


## Switch to `key` and wait for the graph switch and the draw to end.
func draw_weapon(key: String) -> bool:
	if not player.weapons.has(key):
		return false
	player.switch_weapon(key)
	await wait(10)
	var n := 0
	while (player.is_switching() or player.weapon.is_equipping()) and n < 600:
		await wait(1)
		n += 1
	await wait(20)
	return player.weapon_key == key


func wait(n := 1) -> void:
	if ctx != null:
		await ctx.frames(n)
	else:
		for i in n:
			await tree.physics_frame


static func release_all() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)


## A key tap as player.gd sees it (is_action_just_pressed in the next physics frame).
func tap(action: String, hold := 2) -> void:
	Input.action_press(action)
	await wait(hold)
	Input.action_release(action)


## The aim input of a weapon: RMB raises the musket and pistol without firing; the bow draws and a throwable winds
## up on held LMB.
static func aim_action(weapon_key: String) -> String:
	return "aim" if weapon_key in ["musket", "pistol"] else "fire"


# --- steady-state detection --------------------------------------------------------------------

## True when the lower body is steady in `want_stance` (moving: MOVE; else IDLE / AIM_IDLE) for STEADY_S, with the
## lower selector, the upper stance selector and the crouch-change additive settled.
func steady(want_stance: String, moving: bool) -> bool:
	if anim == null or not anim.is_ready():
		return false
	var lb := anim.loco
	if lb.stance != want_stance or String(anim.upper.stance) != want_stance:
		return false
	if moving:
		if lb.state != LocoBrain.MOVE:
			return false
	elif not (lb.state == LocoBrain.IDLE or lb.state == LocoBrain.AIM_IDLE):
		return false
	if lb.time_in_state < STEADY_S - 1e-6:
		return false
	if anim.L.weight(lb.input_id) < 0.999:
		return false
	if anim.upper.G.weight(StringName(want_stance)) < 0.999:
		return false
	return cc_active().is_empty()


## The crouch-change additive OneShots playing: [[node, clip, position s, fading]].
func cc_active() -> Array:
	var out: Array = []
	var up: UpperBody = anim.upper
	for n in up._shots:
		var info: Dictionary = up._shots[n]
		if String(info.get("chain", "")) != "CC":
			continue
		var rec: Dictionary = up.index.oneshots.get(n, {})
		if rec.is_empty() or not up._is_playing(rec):
			continue
		out.append([String(n), String(rec.get("clip", "")), float(anim.get(rec.position_node)), bool(info.get("fading", false))])
	for n in up._pending:
		if String(up._pending[n].get("chain", "")) == "CC":
			out.append([String(n), "(pending)", 0.0, false])
	return out


# --- recording -----------------------------------------------------------------------------------

func _on_transition(from: StringName, to: StringName, info: Dictionary) -> void:
	if not recording:
		return
	transitions.append({"i": frames.size(), "from": String(from), "to": String(to), "from_graph": String(info.get("from_graph", "")),
			"to_graph": String(info.get("to_graph", "")), "key": String(info.get("key", "")), "record": String(info.get("record", "")),
			"fade": float(info.get("fade_used", 0.0)), "input": String(info.get("input_id", "")), "mode": String(info.get("mode", ""))})


func _on_updated() -> void:
	_frame_no += 1
	var dt := sk.get_process_delta_time()
	if dt <= 0.0:
		dt = 1.0 / Engine.physics_ticks_per_second
	var q: Array = []
	var w := PackedFloat32Array()
	for k in _core_idx.size():
		var i := _core_idx[k]
		var qq := sk.get_bone_global_pose(i).basis.get_rotation_quaternion() if i >= 0 else Quaternion.IDENTITY
		q.append(qq)
		if _prev_q.size() == _core_idx.size():
			w.append((_prev_q[k] as Quaternion).angle_to(qq) / dt)
		else:
			w.append(0.0)
	_prev_q = q
	var xf := sk.global_transform
	var fpos: Array = []
	var fy := PackedFloat32Array()
	var fv := PackedFloat32Array()
	var fvv := PackedVector2Array()
	for k in _foot_idx.size():
		var p := xf * sk.get_bone_global_pose(_foot_idx[k]).origin
		fpos.append(p)
		fy.append(p.y)
		if _prev_foot.size() == _foot_idx.size():
			var d: Vector3 = (p - (_prev_foot[k] as Vector3)) / dt
			fv.append(Vector2(d.x, d.z).length())
			fvv.append(Vector2(d.x, d.z))
		else:
			fv.append(0.0)
			fvv.append(Vector2.ZERO)
	_prev_foot = fpos
	if not recording:
		return
	var pel := xf * sk.get_bone_global_pose(_pelvis).origin
	var lb := anim.loco
	var slots: Array = []
	for s: Dictionary in anim._slots():
		var wt := float(s.weight)
		if wt <= 1e-4:
			continue
		var clip := String(s.clip)
		var length := maxf(float(s.length), 1e-4)
		var g := -1.0
		var tb: Array = lb._gait_table(clip)
		if not tb.is_empty():
			g = lb.gait_phase(clip, float(s.position) / length)
		slots.append([clip, snappedf(wt, 0.0001), snappedf(g, 0.0001), snappedf(float(s.position), 0.0001)])
	var v: Vector3 = player.velocity
	var rec := {"i": frames.size(), "n": _frame_no, "dt": dt, "ph": phase, "crouched": bool(player.is_crouching),
			"floor": player.is_on_floor(), "v": Vector2(v.x, v.z).length(), "vy": v.y,
			"py": pel.y - player.global_position.y, "pos": [player.global_position.x, player.global_position.y, player.global_position.z],
			"w": w, "fy": fy, "fv": fv, "fvv": fvv, "bv": Vector2(v.x, v.z),
			"state": String(lb.state), "gs": lb.graph_state, "mode": String(lb.mode), "stance": lb.stance,
			"tis": lb.time_in_state, "pending": lb.crouch_change_pending, "slots": slots,
			"ug": anim.upper.G.weight(&"crouch"), "ustance": String(anim.upper.stance), "cc": cc_active(),
			"aim": player.weapon.aim if player.weapon else 0.0, "elev": anim.upper._elev,
			"stab": anim.stabilizer.last_correction_deg() if anim.stabilizer else 0.0}
	frames.append(rec)
	if on_frame.is_valid():
		on_frame.call(self, rec)


# --- cases -----------------------------------------------------------------------------------------

## Case list. Each case: {key, weapon, motion (still / walk / run / sprint), dir (DIR_KEYS), aim, toggle (down: stand
## -> crouch, up: crouch -> stand), kind ("" plain; rapid, spawn, air, land, cjump, sprint_attempt)}.
static func all_cases() -> Array:
	var out: Array = []
	# musket: the full matrix
	for aim in [false, true]:
		for tg in ["down", "up"]:
			out.append(_case("musket", "still", "none", aim, tg))
		for motion in ["walk", "run"]:
			for d in ["W", "A", "D", "S", "WA", "SD"]:
				for tg in ["down", "up"]:
					out.append(_case("musket", motion, d, aim, tg))
	for d in ["W", "WA"]:
		for tg in ["down", "up"]:
			out.append(_case("musket", "sprint", d, false, tg))
	out.append(_case("musket", "sprint", "W", false, "down", "sprint_attempt"))
	# pistol, bow and a throwable: still, run W and walk A, with and without aim (run W, still)
	for w in ["pistol", "bow", "spear"]:
		for aim in [false, true]:
			for tg in ["down", "up"]:
				out.append(_case(w, "still", "none", aim, tg))
				out.append(_case(w, "run", "W", aim, tg))
		for tg in ["down", "up"]:
			out.append(_case(w, "walk", "A", false, tg))
	# specials (musket)
	out.append(_case("musket", "still", "none", false, "down", "rapid"))
	out.append(_case("musket", "run", "W", false, "down", "rapid"))
	out.append(_case("musket", "run", "W", false, "up", "rapid"))
	out.append(_case("musket", "still", "none", false, "down", "spawn", {"at": 1}))
	out.append(_case("musket", "still", "none", false, "down", "spawn", {"at": 20}))
	out.append(_case("musket", "still", "none", false, "down", "air"))
	out.append(_case("musket", "run", "W", false, "down", "air"))
	out.append(_case("musket", "run", "W", false, "down", "land", {"at": 0}))
	out.append(_case("musket", "run", "W", false, "down", "land", {"at": 6}))
	out.append(_case("musket", "still", "none", false, "down", "land", {"at": 0}))
	out.append(_case("musket", "still", "none", false, "up", "cjump"))
	out.append(_case("musket", "run", "W", false, "up", "cjump"))
	return out


static func _case(w: String, motion: String, d: String, aim: bool, tg: String, kind := "", extra := {}) -> Dictionary:
	var key := "%s/%s%s%s/%s%s" % [w, motion, "" if d == "none" else "_" + d, "_aim" if aim else "", tg,
			"" if kind == "" else "/" + kind + (str(extra.get("at")) if extra.has("at") else "")]
	var c := {"key": key, "weapon": w, "motion": motion, "dir": d, "aim": aim, "toggle": tg, "kind": kind}
	c.merge(extra)
	return c


## True when case c moves (a direction key held through the toggle).
static func moves(c: Dictionary) -> bool:
	return String(c.dir) != "none"


## Runs one case and returns {case, error?, frames, transitions, marks: {pre, toggle, settle, post, end}, expected}.
func run_case(c: Dictionary) -> Dictionary:
	var out := {"case": c.duplicate(), "marks": {}}
	var kind := String(c.kind)
	var comp := bool(c.get("companion", false))
	var start_crouch := String(c.toggle) == "up" and not (comp and kind == "cjump")
	var want := "stand" if start_crouch else "crouch"
	if kind == "sprint_attempt" or (comp and kind == "cjump"):
		want = "stand"
	elif comp:
		want = "crouch" if start_crouch else "stand"
	out.companion = comp
	var mv := moves(c)
	# spawn: the toggle a few frames after the player enters the tree
	if kind == "spawn":
		await spawn(0)
		recording = true
		phase = "trans"
		out.marks.pre = 0
		await wait(int(c.get("at", 1)))
		out.marks.toggle = frames.size()
		if not comp:
			await tap("crouch")
		return await _finish(c, out, want, mv)
	await spawn(30)
	if not await draw_weapon(String(c.weapon)):
		out.error = "switch to %s did not take" % c.weapon
		return out
	if start_crouch:
		await tap("crouch")
		await wait(30)
		if not player.is_crouching:
			out.error = "could not crouch before the case"
			return out
	# held input
	var aim_act := aim_action(String(c.weapon))
	if bool(c.aim):
		Input.action_press(aim_act)
		await wait(20)
	if String(c.motion) == "walk":
		Input.action_press("walk")
	elif String(c.motion) == "sprint" and not start_crouch:
		Input.action_press("sprint")
	for a: String in DIR_KEYS[String(c.dir)]:
		Input.action_press(a)
	var start_stance := "crouch" if start_crouch else "stand"
	var n := 0
	while not steady(start_stance, mv) and n < int(SETTLE_MAX_S * Engine.physics_ticks_per_second):
		await wait(1)
		n += 1
	out.settle_start_s = n / float(Engine.physics_ticks_per_second)
	if not steady(start_stance, mv):
		out.warn_start = "start stance not steady after %.1f s (%s %s)" % [SETTLE_MAX_S, anim.loco.state, anim.loco.graph_state]
	# PRE
	recording = true
	phase = "pre"
	out.marks.pre = frames.size()
	await wait(int(PRE_S * Engine.physics_ticks_per_second))
	phase = "trans"
	out.marks.toggle = frames.size()
	match kind:
		"", "sprint_attempt":
			if String(c.motion) == "sprint" and start_crouch:
				Input.action_press("sprint")       # Shift + W stands a crouched player up (player.gd)
			elif String(c.motion) == "sprint" and kind == "":
				Input.action_release("sprint")     # a crouch press while sprinting is ignored: release Shift with it
				await tap("crouch")
			else:
				await tap("crouch")
		"rapid":
			for k in 3:
				await tap("crouch")
				await wait(int(0.2 * Engine.physics_ticks_per_second) - 2)
		"air":
			out.marks.jump = frames.size()
			await tap("jump")
			var m := 0
			while (player.is_on_floor() or player.velocity.y > 0.2) and m < 120:
				await wait(1)
				m += 1
			out.marks.toggle = frames.size()
			if not comp:
				await tap("crouch")
		"land":
			out.marks.jump = frames.size()
			await tap("jump")
			var m := 0
			while player.is_on_floor() and m < 60:
				await wait(1)
				m += 1
			while not player.is_on_floor() and m < 240:
				await wait(1)
				m += 1
			await wait(int(c.get("at", 0)))
			out.marks.toggle = frames.size()
			if not comp:
				await tap("crouch")
		"cjump":
			out.marks.jump = frames.size()
			await tap("jump")
	return await _finish(c, out, want, mv)


func _finish(c: Dictionary, out: Dictionary, want: String, mv: bool) -> Dictionary:
	var hz := Engine.physics_ticks_per_second
	var n := 0
	var ok := false
	while n < int(TRANS_MAX_S * hz):
		await wait(1)
		n += 1
		if frames.size() - int(out.marks.toggle) > 6 and steady(want, mv) and player.is_on_floor():
			ok = true
			break
	out.marks.settle = frames.size()
	out.settled = ok
	await wait(int(TRANS_TAIL_S * hz))
	phase = "post"
	out.marks.post = frames.size()
	await wait(int(POST_S * hz))
	out.marks.end = frames.size()
	recording = false
	out.expected = want
	out.authored = authored_for(int(out.marks.toggle), int(out.marks.post))
	out.final_crouched = bool(player.is_crouching)
	out.final_stance = anim.loco.stance
	out.final_upper_stance = String(anim.upper.stance)
	out.frames = frames
	out.transitions = transitions
	release_all()
	await free_player()
	return out


# --- authored references ---------------------------------------------------------------------------

## Per clip (cached): the clip ALONE, in place, sampled at 120 Hz with PoseOracle (graph semantics, rest = null-add):
## {pelvis_jerk (max |per-frame change of the pelvis vertical speed|, m/s), slip_mean / slip_peak (its own planted-
## foot speed with the body still: an authored in-place foot shuffle), length}. The graph-faithful floor for the
## clips a transition plays at full weight (a 10 Hz clip's linear keys already break C1 at every key).
static var _auth_cache := {}


func authored(clip: String) -> Dictionary:
	if _auth_cache.has(clip):
		return _auth_cache[clip]
	var aps := sk.get_parent().find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return {}
	var o := PoseOracle.new(sk, aps[0])
	var a := o.animation(clip)
	if a == null:
		_auth_cache[clip] = {}
		return {}
	var sc := sk.global_transform.basis.get_scale().y
	var hz := float(Engine.physics_ticks_per_second)
	var n := maxi(2, int(a.length * hz) + 1)
	var pel := sk.find_bone("pelvis")
	var py := PackedFloat32Array()
	var feet: Array = []
	for k in n:
		var mt := o.model_transforms(o.clip(clip, minf(k / hz, a.length)))
		py.append(mt[pel].origin.y * sc)
		var f: Array = []
		for i in _foot_idx:
			f.append(mt[i].origin * sc)
		feet.append(f)
	var jerk := 0.0
	for k in range(2, n):
		jerk = maxf(jerk, absf((py[k] - py[k - 1]) - (py[k - 1] - py[k - 2])) * hz)
	var ymin := PackedFloat32Array([INF, INF, INF, INF])
	for f: Array in feet:
		for j in 4:
			ymin[j] = minf(ymin[j], (f[j] as Vector3).y)
	var sp := PackedFloat32Array()
	var per: Array = []
	for k in range(1, n):
		var sm := 0.0
		var cnt := 0
		for j in 4:
			var p1: Vector3 = feet[k][j]
			var p0: Vector3 = feet[k - 1][j]
			if p1.y < ymin[j] + PLANTED_TOL and p0.y < ymin[j] + PLANTED_TOL:
				var v := Vector2(p1.x - p0.x, p1.z - p0.z).length() * hz
				sp.append(v)
				sm += v
				cnt += 1
		per.append([sm, cnt])
	var mean := 0.0
	for x in sp:
		mean += x
	mean = mean / sp.size() if sp.size() > 0 else 0.0
	var out := {"pelvis_jerk": snappedf(jerk, 0.0001), "slip_mean": snappedf(mean, 0.001), "slip_peak": snappedf(_peak(per, hz), 0.001),
			"length": a.length}
	_auth_cache[clip] = out
	return out


## Authored references of the non-stepping clips (no gait table: idle, the crouch-change clip, turns) that reach
## >= 0.5 weight in frames [a, b), and of every clip for the pelvis: {clip: authored()}.
func authored_for(a: int, b: int) -> Dictionary:
	var seen := {}
	for i in range(a, b):
		for sl: Array in frames[i].slots:
			if float(sl[1]) >= 0.5:
				seen[String(sl[0])] = float(sl[2]) < 0.0
	var out := {}
	for clip: String in seen:
		var ref := authored(clip)
		if not ref.is_empty():
			var r2 := ref.duplicate()
			r2["in_place"] = seen[clip]
			out[clip] = r2
	return out


# --- analysis ------------------------------------------------------------------------------------

## Summary of a run_case() result. Windows: PRE [pre, toggle), TRANS [toggle, post), POST [post, end); the baseline
## is PRE and POST together (the case's own locomotion in the start and the target stance; spawn cases: POST only).
## "authored" = the clips that reach >= 0.5 weight in TRANS played alone in place (authored(): the graph-faithful
## floor of what the transition's own data does).
## Gates (all must hold for PASS):
##   pose      max one-frame rotation spike (a bone's angular speed minus the median of its SPIKE_NB frames either
##             side) in TRANS <= max(SPIKE_K x the baseline's max spike, SPIKE_FLOOR)
##   pelvis    C1: max |per-frame change of the pelvis vertical speed| in TRANS <= max(PELVIS_JERK_K x the larger
##             of the baseline's and the authored clips' own, PELVIS_JERK_FLOOR); and the height stays inside the
##             two stances' own range (PRE / POST min and max, bob included) +- ENVELOPE_M: no dip below the target
##             height and back (the crouch-change squat under a crouch walk)
##   slip      planted-foot mean horizontal speed in TRANS <= max(baseline mean, authored in-place clips' own)
##             + SLIP_MARGIN, and the peak PEAK_WIN_S mean <= max(baseline peak, authored) + PEAK_SLIP_MARGIN.
##             Planted: within PLANTED_TOL of the window's lowest height of that point, and not swinging (its
##             velocity along the body's travel <= body speed + SWING_MARGIN: a low forward swing, e.g. the crouch
##             walk's, is not a plant)
##   steps     no double step (two plant onsets of the same foot in a row) in TRANS while moving, unless the
##             baseline has them too
##   banks     gait-phase mismatch of two weighted locomotion banks (both >= 0.2) <= MISMATCH_MAX, and an in-place
##             clip (no stepping: idle, the crouch-change clip) at >= 0.5 weight while the body moves >= 0.5 m/s for
##             at most INPLACE_MAX_S
##   stance    the toggle took the expected direction, the lower and upper body end in it, and it settled within
##             TRANS_MAX_S
static func analyze(r: Dictionary, comp: Dictionary = {}) -> Dictionary:
	var c: Dictionary = r.case
	var s := {"key": c.key, "gates": {}, "fail": []}
	if r.has("error"):
		s.fail.append("error: " + String(r.error))
		s.pass = false
		return s
	var fr: Array = r.frames
	var m: Dictionary = r.marks
	var spawn_case := String(c.kind) == "spawn"
	var i_pre := int(m.get("pre", 0))
	var i_tg := int(m.toggle)
	var i_post := int(m.post)
	var i_end := int(m.end)
	var hz := Engine.physics_ticks_per_second
	var trans := range(i_tg, i_post)
	var pre := range(i_pre, int(m.get("jump", i_tg))) if not spawn_case else []
	var post := range(i_post, i_end)
	# baseline sets [frames, indices]: own PRE and POST, and the companion run's TRANS-aligned window (the same run
	# without the toggle; spawn / air / land / crouch-jump cases)
	var sets: Array = [[fr, pre], [fr, post]]
	s.baseline = "pre+post"
	if not comp.is_empty() and not comp.has("error"):
		var cf: Array = comp.frames
		var ca := int(comp.marks.get("jump", comp.marks.toggle)) if comp.marks.has("jump") else int(comp.marks.toggle)
		var cb := mini(int(comp.marks.toggle) + (i_post - i_tg), cf.size())
		sets.append([cf, range(ca, cb)])
		s.baseline = "pre+post+companion"
	var auth: Dictionary = r.get("authored", {})
	var i_flip := -1
	for i in range(maxi(i_tg, 1), i_end):
		if bool(fr[i].crouched) != bool(fr[i - 1].crouched):
			i_flip = i
			break
	s.toggle_frame = i_flip - i_tg if i_flip >= 0 else -1
	s.settle_s = snappedf((int(m.settle) - i_tg) / float(hz), 0.001)
	s.settled = bool(r.settled)
	# pose spikes
	var nb := CORE.size()
	var spike_tr := _max_spike(fr, trans, nb)
	var spike_base := 0.0
	for st: Array in sets:
		spike_base = maxf(spike_base, float(_max_spike(st[0], st[1], nb).v))
	var lim_spike := maxf(SPIKE_K * spike_base, SPIKE_FLOOR)
	s.spike = {"trans": snappedf(spike_tr.v, 0.01), "bone": CORE[spike_tr.b] if spike_tr.b >= 0 else "",
			"t": snappedf((int(spike_tr.i) - i_tg) / float(hz), 0.001), "base": snappedf(spike_base, 0.01), "limit": snappedf(lim_spike, 0.01)}
	s.gates.pose = float(spike_tr.v) <= lim_spike
	# max angular speed ratio (info)
	var wr := {"ratio": 0.0, "bone": ""}
	for b in nb:
		var mt := 0.0
		var at := -1
		for i in trans:
			if fr[i].w[b] > mt:
				mt = fr[i].w[b]
				at = i
		var mb := 0.0
		for st: Array in sets:
			for i in st[1]:
				mb = maxf(mb, st[0][i].w[b])
		var rt := mt / maxf(mb, 2.0)
		if rt > float(wr.ratio):
			wr = {"ratio": snappedf(rt, 0.01), "bone": CORE[b], "trans": snappedf(mt, 0.01), "base": snappedf(mb, 0.01),
					"t": snappedf((at - i_tg) / float(hz), 0.001)}
	s.speed_ratio = wr
	# pelvis
	var pj_tr := _pelvis_jerk(fr, trans)
	var pj_b := 0.0
	for st: Array in sets:
		pj_b = maxf(pj_b, float(_pelvis_jerk(st[0], st[1]).v))
	var pj_a := 0.0
	var a_slip_mean := 0.0
	var a_slip_peak := 0.0
	for clip in auth:
		pj_a = maxf(pj_a, float(auth[clip].pelvis_jerk))
		if bool(auth[clip].get("in_place", false)):
			a_slip_mean = maxf(a_slip_mean, float(auth[clip].slip_mean))
			a_slip_peak = maxf(a_slip_peak, float(auth[clip].slip_peak))
	var lim_pj := maxf(PELVIS_JERK_K * maxf(pj_b, pj_a), PELVIS_JERK_FLOOR)
	var h_pre := _mean(fr, pre, "py")
	var h_post := _mean(fr, post, "py")
	var hmin := INF
	var hmax := -INF
	for i in trans:
		hmin = minf(hmin, fr[i].py)
		hmax = maxf(hmax, fr[i].py)
	var bmin := INF
	var bmax := -INF
	for st: Array in sets:
		for i in st[1]:
			bmin = minf(bmin, st[0][i].py)
			bmax = maxf(bmax, st[0][i].py)
	var t90 := -1.0
	if not is_nan(h_pre) and absf(h_post - h_pre) > 0.05:
		for i in trans:
			if absf(float(fr[i].py) - h_pre) >= 0.9 * absf(h_post - h_pre):
				t90 = (i - i_tg) / float(hz)
				break
	var env_ok := hmin >= bmin - ENVELOPE_M and hmax <= bmax + ENVELOPE_M
	s.pelvis = {"jerk": snappedf(pj_tr.v, 0.0001), "jerk_t": snappedf((int(pj_tr.i) - i_tg) / float(hz), 0.001),
			"base": snappedf(pj_b, 0.0001), "authored": snappedf(pj_a, 0.0001), "limit": snappedf(lim_pj, 0.0001),
			"h_pre": snappedf(h_pre, 0.001), "h_post": snappedf(h_post, 0.001), "h_min": snappedf(hmin, 0.001),
			"h_max": snappedf(hmax, 0.001), "base_min": snappedf(bmin, 0.001), "base_max": snappedf(bmax, 0.001),
			"t90": snappedf(t90, 0.001), "envelope_ok": env_ok}
	s.gates.pelvis = float(pj_tr.v) <= lim_pj and env_ok
	# foot slip
	var sl_tr := _slip(fr, trans, hz)
	var sl_b: Array = []
	for st: Array in sets:
		sl_b.append(_slip(st[0], st[1], hz))
	var b_mean := a_slip_mean
	var b_peak := a_slip_peak
	for sl: Dictionary in sl_b:
		if sl.mean != null and not is_nan(float(sl.mean)):
			b_mean = maxf(b_mean, float(sl.mean))
		if sl.peak != null and not is_nan(float(sl.peak)):
			b_peak = maxf(b_peak, float(sl.peak))
	s.slip = {"trans": sl_tr, "pre": sl_b[0], "post": sl_b[1], "companion": sl_b[2] if sl_b.size() > 2 else {},
			"authored_mean": snappedf(a_slip_mean, 0.001), "authored_peak": snappedf(a_slip_peak, 0.001),
			"limit_mean": snappedf(b_mean + SLIP_MARGIN, 0.001), "limit_peak": snappedf(b_peak + PEAK_SLIP_MARGIN, 0.001)}
	s.gates.slip = (is_nan(float(sl_tr.mean)) or float(sl_tr.mean) <= b_mean + SLIP_MARGIN) \
			and (is_nan(float(sl_tr.peak)) or float(sl_tr.peak) <= b_peak + PEAK_SLIP_MARGIN)
	# steps
	var ymin_all := _ymin(fr, range(i_pre, i_end))
	var st_tr := _steps(fr, trans, ymin_all)
	var st_pre := _steps(fr, pre, ymin_all)
	var st_post := _steps(fr, post, ymin_all)
	var b_dbl := int(st_pre.double) + int(st_post.double)
	if sets.size() > 2:
		b_dbl += int(_steps(sets[2][0], sets[2][1], _ymin(sets[2][0], sets[2][1])).double)
	s.steps = {"trans": st_tr, "pre": st_pre, "post": st_post, "base_double": b_dbl}
	s.gates.steps = int(st_tr.double) == 0 or b_dbl > 0
	# banks: gait-phase mismatch, in-place clips while moving
	var mism := 0.0
	var mism_t := -1.0
	var inplace := 0
	var inplace_first := -1.0
	var inplace_clips := {}
	for i in trans:
		var banks: Array = []
		var ip := 0.0
		for sl: Array in fr[i].slots:
			if float(sl[2]) >= 0.0:
				banks.append(sl)
			elif in_place(String(sl[0])):
				ip += float(sl[1])
		banks.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
		if banks.size() >= 2 and float(banks[1][1]) >= 0.2:
			var d := absf(wrapf(float(banks[0][2]) - float(banks[1][2]), -0.5, 0.5))
			if d > mism:
				mism = d
				mism_t = (i - i_tg) / float(hz)
		if ip >= 0.5 and float(fr[i].v) >= 0.5:
			inplace += 1
			if inplace_first < 0.0:
				inplace_first = (i - i_tg) / float(hz)
			for sl: Array in fr[i].slots:
				if float(sl[2]) < 0.0 and in_place(String(sl[0])) and float(sl[1]) >= 0.2:
					inplace_clips[String(sl[0])] = true
	s.banks = {"mismatch": snappedf(mism, 0.001), "mismatch_t": snappedf(mism_t, 0.001),
			"inplace_moving_s": snappedf(inplace / float(hz), 0.001), "inplace_first_t": snappedf(inplace_first, 0.001),
			"inplace_clips": inplace_clips.keys()}
	s.gates.banks = mism <= MISMATCH_MAX and inplace / float(hz) <= INPLACE_MAX_S
	# stance
	var want_c := String(r.expected) == "crouch"
	s.stance = {"expected": r.expected, "final_crouched": r.final_crouched, "final_lower": r.final_stance,
			"final_upper": r.final_upper_stance}
	s.gates.stance = bool(r.final_crouched) == want_c and String(r.final_stance) == String(r.expected) \
			and String(r.final_upper_stance) == String(r.expected) and bool(r.settled)
	# aim elevation step at the toggle (info: player.aim_pitch() measures from a chest 1.35 m / 0.95 m high by stance)
	var el := 0.0
	var el_t := -1.0
	for i in trans:
		if i >= 1:
			var d := absf(float(fr[i].elev) - float(fr[i - 1].elev))
			if d > el:
				el = d
				el_t = (i - i_tg) / float(hz)
	s.aim = {"elev_step_deg": snappedf(el, 0.01), "elev_step_t": snappedf(el_t, 0.001)}
	# body speed around the toggle
	s.speed = {"pre": snappedf(_mean(fr, pre, "v"), 0.01), "post": snappedf(_mean(fr, post, "v"), 0.01)}
	# lower-body path through TRANS
	var tl: Array = []
	for t: Dictionary in r.transitions:
		if int(t.i) >= i_tg and int(t.i) < i_post:
			tl.append("%+.3f %s->%s [%s %s %.2fs]" % [(int(t.i) - i_tg) / float(hz), t.from_graph, t.to_graph, t.key, t.record, float(t.fade)])
	s.transitions = tl
	s.authored = auth
	s.fail = []
	for g in s.gates:
		if not bool(s.gates[g]):
			s.fail.append(g)
	s.pass = s.fail.is_empty()
	return s


## True for a lower clip that does not step (the legs stand while the body would slide if it moved): no gait table
## and not a start / landing into movement (a "^" transition clip into walk / run / sprint / crouch-walk steps).
static func in_place(clip: String) -> bool:
	var k := clip.find("^")
	if k < 0:
		return true
	var to := clip.substr(k + 1)
	for mv in ["walk", "run", "sprint"]:
		if to.begins_with(mv) or to.begins_with("crouch-" + mv):
			return false
	return true


static func _max_spike(fr: Array, idx: Array, nb: int) -> Dictionary:
	var best := {"v": 0.0, "b": -1, "i": -1}
	var n := fr.size()
	for i in idx:
		if i < 1:
			continue
		for b in nb:
			var nbv := PackedFloat32Array()
			for k in range(i - SPIKE_NB, i + SPIKE_NB + 1):
				if k == i or k < 1 or k >= n:
					continue
				nbv.append(fr[k].w[b])
			if nbv.is_empty():
				continue
			nbv.sort()
			var med := nbv[nbv.size() / 2]
			var sp: float = float(fr[i].w[b]) - med
			if sp > float(best.v):
				best = {"v": sp, "b": b, "i": i}
	return best


static func _pelvis_jerk(fr: Array, idx: Array) -> Dictionary:
	var best := {"v": 0.0, "i": -1}
	for i in idx:
		if i < 2:
			continue
		var v1: float = (float(fr[i].py) - float(fr[i - 1].py)) / float(fr[i].dt)
		var v0: float = (float(fr[i - 1].py) - float(fr[i - 2].py)) / float(fr[i - 1].dt)
		var j := absf(v1 - v0)
		if j > float(best.v):
			best = {"v": j, "i": i}
	return best


static func _mean(fr: Array, idx: Array, key: String) -> float:
	if idx.is_empty():
		return NAN
	var s := 0.0
	for i in idx:
		s += float(fr[i][key])
	return s / idx.size()


static func _ymin(fr: Array, idx: Array) -> PackedFloat32Array:
	var ymin := PackedFloat32Array([INF, INF, INF, INF])
	for i in idx:
		for k in 4:
			ymin[k] = minf(ymin[k], fr[i].fy[k])
	return ymin


## True when foot point k is planted in frame i: low (within PLANTED_TOL of ymin) and not swinging forward (its
## velocity along the body's travel at most the body speed + SWING_MARGIN).
static func _planted(f: Dictionary, k: int, ymin: PackedFloat32Array) -> bool:
	if float(f.fy[k]) >= ymin[k] + PLANTED_TOL:
		return false
	var bv: Vector2 = f.bv
	var sp := bv.length()
	if sp < 0.3:
		return true
	var along := (f.fvv[k] as Vector2).dot(bv / sp)
	return along <= sp + SWING_MARGIN


## Planted-foot horizontal speed over frames idx (ymin: the window's own lowest heights, as FootSlip):
## {n, mean, median, p90, max, peak (max PEAK_WIN_S mean), peak_t}.
static func _slip(fr: Array, idx: Array, hz: float) -> Dictionary:
	var out := {"n": 0, "mean": NAN, "median": NAN, "p90": NAN, "max": NAN, "peak": NAN, "peak_t": -1.0}
	if idx.is_empty():
		return out
	var ymin := _ymin(fr, idx)
	var all := PackedFloat32Array()
	var per_frame: Array = []
	for i in idx:
		var sm := 0.0
		var cnt := 0
		if i >= 1:
			for k in 4:
				if _planted(fr[i], k, ymin) and _planted(fr[i - 1], k, ymin):
					all.append(fr[i].fv[k])
					sm += float(fr[i].fv[k])
					cnt += 1
		per_frame.append([sm, cnt])
	out.n = all.size()
	if all.is_empty():
		return out
	var s := 0.0
	var mx := 0.0
	for x in all:
		s += x
		mx = maxf(mx, x)
	var sorted := all.duplicate()
	sorted.sort()
	out.mean = snappedf(s / all.size(), 0.001)
	out.median = snappedf(sorted[sorted.size() / 2], 0.001)
	out.p90 = snappedf(sorted[mini(int(sorted.size() * 0.9), sorted.size() - 1)], 0.001)
	out.max = snappedf(mx, 0.001)
	var pk := _peak_at(per_frame, hz)
	out.peak = snappedf(float(pk[0]), 0.001) if not is_nan(float(pk[0])) else NAN
	out.peak_t = snappedf(int(pk[1]) / hz, 0.001) if int(pk[1]) >= 0 else -1.0
	out.peak_i = int(idx[0]) + int(pk[1]) if int(pk[1]) >= 0 else -1
	return out


## Max mean over any PEAK_WIN_S window of [sum, count] per frame (windows with >= 8 samples).
static func _peak(per_frame: Array, hz: float) -> float:
	var r := _peak_at(per_frame, hz)
	return 0.0 if is_nan(float(r[0])) else float(r[0])


static func _peak_at(per_frame: Array, hz: float) -> Array:
	var win := maxi(1, int(PEAK_WIN_S * hz))
	var peak := NAN
	var at := -1
	for a in range(0, maxi(per_frame.size() - win + 1, 1)):
		var ss := 0.0
		var cc := 0
		for k in range(a, mini(a + win, per_frame.size())):
			ss += float(per_frame[k][0])
			cc += int(per_frame[k][1])
		if cc >= 8:
			var mval := ss / cc
			if is_nan(peak) or mval > peak:
				peak = mval
				at = a
	return [peak, at]


## Plant onsets per foot (heel or ball planted, debounced) in frames idx while the body moves >= 0.3 m/s:
## {onsets: "LRLR...", double: count of same-foot onsets in a row}.
static func _steps(fr: Array, idx: Array, ymin: PackedFloat32Array) -> Dictionary:
	var seq := ""
	var dbl := 0
	var state := [false, false]
	var run := [0, 0]
	for i in idx:
		for f in 2:
			var planted := _planted(fr[i], 2 * f, ymin) or _planted(fr[i], 2 * f + 1, ymin)
			if planted != bool(state[f]):
				run[f] = int(run[f]) + 1
				if int(run[f]) >= STEP_DEBOUNCE:
					state[f] = planted
					run[f] = 0
					if planted and float(fr[i].v) >= 0.3:
						var ch := "L" if f == 0 else "R"
						if seq.length() > 0 and seq[seq.length() - 1] == ch:
							dbl += 1
						seq += ch
			else:
				run[f] = 0
	return {"onsets": seq, "double": dbl}


## One table line of an analyze() summary.
static func line(s: Dictionary) -> String:
	if s.has("pass") and not s.has("spike"):
		return "%-40s FAIL %s" % [s.key, ", ".join(s.fail)]
	var sl: Dictionary = s.slip
	return "%-40s %s  spike %5.2f/%5.2f %-16s pelvis-jerk %.3f/%.3f h %.2f->%.2f min %.2f t90 %4.2f  slip mean %s/%s peak %s/%s  dbl %d/%d  mism %.2f inplace %.2fs  settle %.2fs  %s" % [
			s.key, "PASS" if s.pass else "FAIL", float(s.spike.trans), float(s.spike.limit), String(s.spike.bone),
			float(s.pelvis.jerk), float(s.pelvis.limit), float(s.pelvis.h_pre), float(s.pelvis.h_post), float(s.pelvis.h_min), float(s.pelvis.t90),
			_f(sl.trans.mean), _f(sl.limit_mean), _f(sl.trans.peak), _f(sl.limit_peak), int(s.steps.trans.double), int(s.steps.base_double),
			float(s.banks.mismatch), float(s.banks.inplace_moving_s), float(s.settle_s), "" if s.pass else "[" + ", ".join(s.fail) + "]"]


static func _f(x: Variant) -> String:
	return "-" if x == null or (x is float and is_nan(x)) else "%.3f" % float(x)


## Per-frame curves of a run_case() result for the JSON dump (TRANS and the windows around it).
static func curves(r: Dictionary) -> Dictionary:
	if r.has("error"):
		return {}
	var fr: Array = r.frames
	var out := {"t": [], "ph": [], "crouched": [], "v": [], "py": [], "wmax": [], "wmax_bone": [], "slip": [], "state": [],
			"gs": [], "mode": [], "slots": [], "ug": [], "cc": [], "elev": [], "stab": []}
	var i_tg := int(r.marks.toggle)
	var hz := Engine.physics_ticks_per_second
	for i in fr.size():
		var f: Dictionary = fr[i]
		out.t.append(snappedf((i - i_tg) / float(hz), 0.0001))
		out.ph.append(f.ph)
		out.crouched.append(f.crouched)
		out.v.append(snappedf(f.v, 0.001))
		out.py.append(snappedf(f.py, 0.0001))
		var wm := 0.0
		var wb := -1
		for b in (f.w as PackedFloat32Array).size():
			if f.w[b] > wm:
				wm = f.w[b]
				wb = b
		out.wmax.append(snappedf(wm, 0.01))
		out.wmax_bone.append(CORE[wb] if wb >= 0 else "")
		out.slip.append([snappedf(f.fv[0], 0.001), snappedf(f.fv[1], 0.001), snappedf(f.fv[2], 0.001), snappedf(f.fv[3], 0.001),
				snappedf(f.fy[0], 0.001), snappedf(f.fy[1], 0.001), snappedf(f.fy[2], 0.001), snappedf(f.fy[3], 0.001)])
		out.state.append(f.state)
		out.gs.append(f.gs)
		out.mode.append(f.mode)
		out.slots.append(f.slots)
		out.ug.append(snappedf(f.ug, 0.001))
		out.cc.append(f.cc)
		out.elev.append(snappedf(f.elev, 0.01))
		out.stab.append(snappedf(f.stab, 0.01))
	return out
