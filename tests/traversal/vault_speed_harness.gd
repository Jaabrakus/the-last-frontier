class_name VaultSpeedHarness
extends RefCounted
## Speed through a vault, measured on the REAL player (user 2026-09-26: "also when we vault the char model should
## not slow down"). A FrontierPlayer (built in code as in the game: PlayerAnim, PlayerTraversal, the weapon in the
## hands) runs with Input.action_press on a flat arena at an obstacle of the level's kinds and heights, and every
## physics tick is recorded from 1 s before the vault to 1.5 s after it:
##   capsule  the body's (CharacterBody3D) horizontal speed along the travel (finite difference of its position)
##   model    the rendered pelvis's speed along the travel (the skinned pose after every modifier, read at
##            Skeleton3D.skeleton_updated: what the player sees), and the same over a centred SMOOTH_S window
##            (the stride's own surge and sway taken out)
##   and what can slow the body: the traversal mode / move / part / clip time and its rate, the approach cap
##   (PlayerTraversal.approach_speed), PlayerAnim's lower state and its body speed cap (a START clip), the
##   player's sprint flag and speed band, the weapon (put away for the move, drawn after it).
## Also the contacts of the move as the player shows it: every full-weight IK plant's world target and the
## planted bone's world travel while it is held (TraversalIK pins), so a faster vault can be checked for
## skating hands and feet.
##
## Obstacles (the level's kinds; scripts/world/structures/fort_structures.gd, vegetation logs):
##   fence   the firing line's split rail: a 0.1 x 0.12 m top rail at 0.6 m on 0.12 m posts (vault_idle)
##   wall70  a 0.7 m wall, 0.3 m deep (vault_idle)
##   wall90  a 0.9 m wall, 0.3 m deep (the sprint vault)
##   log55   a 0.55 m log (box, 0.45 m deep: step_over)
##   box80   a 0.8 m block, 1.2 m deep (the running knee mantle onto it: a climb, for comparison)
## Gaits: walk (Alt, 1.6 m/s), jog (the stick at 70 %: 2.5 m/s), run (3.6 m/s), sprint (Shift, 5.6 m/s), stand
## (from rest 1.2 m before the obstacle, then run). Careful gaits (no Shift) press Space when the controller has
## the move planned and the body is about to reach its start point (a player pressing Space at the obstacle).
##
## Needs --fixed-fps 120 (one pose update per physics tick).

const LIFT_OFF_M := 0.03          ## a planted bone this far above where it planted has lifted (slides stop counting)
const OBSTACLES := {
	"fence": {"note": "firing line split rail 0.6 m"},
	"wall70": {"h": 0.7, "d": 0.3},
	"wall90": {"h": 0.9, "d": 0.3},
	"log55": {"h": 0.55, "d": 0.45},
	"box80": {"h": 0.8, "d": 1.2},       # (a crate-like block: the running knee mantle, no momentum)
	"truss90": {"h": 0.9, "d": 0.9},     # the range's straw trusses (FrontierStructures: 1.6 x 0.9 x 0.9)
}
const GAITS := {
	"walk": {"keys": ["walk"], "strength": 1.0, "careful": true},
	"jog": {"keys": [], "strength": 0.7, "careful": true},
	"run": {"keys": [], "strength": 1.0, "careful": true},
	"sprint": {"keys": ["sprint"], "strength": 1.0, "careful": false},
	"stand": {"keys": [], "strength": 1.0, "careful": true, "run_up": 1.2},
}
const OBSTACLE_Z := -20.0          ## the obstacle's near face (the player runs toward -Z)
const RUN_UP := 16.0               ## m from the spawn to the face (the gait is steady long before)
const PRE_S := 1.0
const POST_S := 1.5
const SMOOTH_S := 0.1              ## centred window of the smoothed model speed
const TIMEOUT_S := 12.0
const MOMENTUM := "res://scripts/traversal/momentum.gd"

var tree: SceneTree
var arena: Node3D
var player: FrontierPlayer
## Called with the player once it stands ready, before the run starts (e.g. a torch lit for the vault).
var setup: Callable
var sk: Skeleton3D
var frames: Array = []             ## per physics tick (see _sample)
var _pelvis := -1
var _pelvis_w := Vector3.INF
var _bones := {}
var _bones_w := {}                 ## bone name -> world position in the final pose (after every modifier: the IK's plants)
var _space_down := false
var _careful := false
var _strength := 1.0
var on_frame := Callable()         ## awaited after every recorded tick with (harness, record) (the strips tool)


func _init(p_tree: SceneTree) -> void:
	tree = p_tree


# --- arena ------------------------------------------------------------------------------------

## A flat floor (top at y = 0) and one obstacle, as the tree's current scene (PlayerTraversal bakes
## the current scene's colliders).
func build_arena(obstacle: String, visual := false) -> Node3D:
	if arena != null and is_instance_valid(arena):
		arena.free()
	arena = Node3D.new()
	arena.name = "VaultArena"
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position.y = -0.5
	arena.add_child(floor_body)
	var z := OBSTACLE_Z
	match obstacle:
		"fence":
			# fort_structures.gd _range(): rail 8 x 0.1 x 0.12 at y 0.55, posts 0.12 x 0.6 x 0.12 every 4 m
			_box(arena, "rail", Vector3(0, 0.55, z - 0.06), Vector3(8, 0.1, 0.12), Color(0.45, 0.31, 0.19))
			for x: float in [-4.0, 0.0, 4.0]:
				_box(arena, "rail_post", Vector3(x, 0.3, z - 0.06), Vector3(0.12, 0.6, 0.12), Color(0.4, 0.28, 0.17))
		_:
			var o: Dictionary = OBSTACLES[obstacle]
			var h := float(o.h)
			var d := float(o.d)
			_box(arena, obstacle, Vector3(0, h * 0.5, z - d * 0.5), Vector3(6, h, d), Color(0.5, 0.36, 0.22))
	if visual:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, 30, 0)
		sun.shadow_enabled = true
		arena.add_child(sun)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.62, 0.66, 0.7)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.55, 0.58)
		env.ambient_light_energy = 0.8
		we.environment = env
		arena.add_child(we)
		var mesh := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(200, 200)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.45, 0.40)
		pm.material = mat
		mesh.mesh = pm
		arena.add_child(mesh)
		# a stake every metre beside the running line, behind it from the side camera (the strips read
		# the travel off them); a taller one every 5 m
		for k in range(-40, 21):
			var stake := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var tall := k % 5 == 0
			bm.size = Vector3(0.05, 0.5 if tall else 0.25, 0.05)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(0.95, 0.95, 0.9) if tall else Color(0.8, 0.8, 0.75)
			bm.material = lm
			stake.mesh = bm
			stake.position = Vector3(-1.2, bm.size.y * 0.5, float(k))
			arena.add_child(stake)
	tree.root.add_child(arena)
	tree.current_scene = arena
	return arena


func _box(parent: Node3D, nm: String, center: Vector3, size: Vector3, color: Color) -> void:
	var sb := StaticBody3D.new()
	sb.name = nm
	sb.position = center
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	bm.material = m
	mi.mesh = bm
	sb.add_child(mi)
	parent.add_child(sb)


# --- a run --------------------------------------------------------------------------------------

## Runs `gait` at `obstacle` and returns the analysed run (analyse()); frames holds every tick.
func run(obstacle: String, gait: String, visual := false) -> Dictionary:
	release_all()
	build_arena(obstacle, visual)
	var g: Dictionary = GAITS[gait]
	var run_up := float(g.get("run_up", RUN_UP))
	player = FrontierPlayer.new()
	player.name = "Player"
	player.ignore_mouse_capture = true
	player.demo_horse = false
	player.position = Vector3(0, 0.02, OBSTACLE_Z + run_up)
	await tree.process_frame
	arena.add_child(player)
	while player.skeleton == null:
		await tree.process_frame
	sk = player.skeleton
	_pelvis = sk.find_bone("pelvis")
	for b in ["l_wrist", "r_wrist", "l_ankle", "r_ankle", "l_ball", "r_ball", "l_heel", "r_heel", "l_middlea", "r_middlea"]:
		_bones[b] = sk.find_bone(b)
	sk.skeleton_updated.connect(_on_pose)
	frames = []
	_pelvis_w = Vector3.INF
	_bones_w = {}
	# the level bakes on its second physics frame; the weapon is drawn by then
	await _ticks(90)
	while player.traversal == null or not player.traversal.world_ready:
		await _ticks(1)
	if setup.is_valid():
		await setup.call(player)
	_careful = bool(g.careful)
	_strength = float(g.strength)
	for k: String in g["keys"]:
		Input.action_press(k)
	Input.action_press("move_forward", _strength)
	var t := 0.0
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var end_t := -1.0
	var began := -1.0
	while t < TIMEOUT_S:
		await tree.physics_frame
		# (held again every tick: a windowed run without focus releases every action on a focus change;
		# the view held straight ahead: in a window the mouse turns the player)
		player.yaw = 0.0
		player.pitch = 0.0
		for k: String in g["keys"]:
			Input.action_press(k)
		Input.action_press("move_forward", _strength)
		_space()
		t += dt
		var rec := _sample(t)
		frames.append(rec)
		if on_frame.is_valid():
			await on_frame.call(self, rec)
		var mode := str(rec.mode)
		if began < 0.0 and mode != "OFF":
			began = t
		if began >= 0.0 and end_t < 0.0 and mode == "OFF":
			end_t = t
		if end_t >= 0.0 and t >= end_t + POST_S:
			break
	release_all()
	sk.skeleton_updated.disconnect(_on_pose)
	var out := analyse(frames, began, end_t)
	out["obstacle"] = obstacle
	out["gait"] = gait
	player.queue_free()
	await _ticks(2)
	return out


## Careful gaits: Space on the tick the body reaches the planned move's start point (the controller
## starts a careful move only with Space buffered at S; pressed earlier, the player's own jump takes
## the press). The plan is looked up as the controller would make it with Space held (can_traverse
## with the trigger; nothing is started). A press is released on the next tick.
func _space() -> void:
	if _space_down:
		Input.action_release("jump")
		_space_down = false
		return
	if not _careful or player.traversal == null or player.traversal.controller == null:
		return
	var c := player.traversal.controller
	if c.mode != TraversalController.Mode.OFF:
		return
	var inp := {"move": Vector2(0, -_strength), "sprint": false, "walk": player.is_walking, "yaw": player.yaw}
	var ctx := c.context(inp)
	ctx["trigger"] = true
	var p := c.can_traverse(ctx)
	if p == null or not p.ok() or p.kind == "step_assist":
		return
	var h: Vector3 = ctx.heading
	var along := Vector3(p.start.x - player.global_position.x, 0, p.start.z - player.global_position.z).dot(h)
	var v := player.horizontal_speed()
	# (a move with momentum starts its entry lead before S)
	var lead := _entry_lead(p.move_id, p.move, v)
	if along <= maxf(v / 120.0 * 2.0, 0.03) + lead or (p.approach_stop and v < 0.3):
		Input.action_press("jump")
		_space_down = true


## How far before S the move starts (TravMomentum.prepare().trigger; entry_lead on a checkout of the first
## momentum push, the "before" runs of the strips; 0 without TravMomentum).
func _entry_lead(move_id: String, move: Dictionary, v: float) -> float:
	if not ResourceLoader.exists(MOMENTUM):
		return 0.0
	var sc := load(MOMENTUM) as GDScript
	for m: Dictionary in sc.get_script_method_list():
		if str(m.name) == "prepare":
			return float((sc.call(&"prepare", move_id, move, v) as Dictionary).get("trigger", 0.0))
	return float(sc.call(&"entry_lead", move, v))


func release_all() -> void:
	for a in ["move_forward", "sprint", "walk", "jump", "crouch"]:
		Input.action_release(a)
	_space_down = false


func _ticks(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _on_pose() -> void:
	if _pelvis >= 0:
		_pelvis_w = sk.global_transform * sk.get_bone_global_pose(_pelvis).origin
	# (the planted bones as shown: read outside the modifier stack, get_bone_global_pose gives the pose before
	# the IK, which a momentum path moves on past its plants by design)
	for b: String in _bones:
		if int(_bones[b]) >= 0:
			_bones_w[b] = sk.global_transform * sk.get_bone_global_pose(int(_bones[b])).origin


func _sample(t: float) -> Dictionary:
	var tr := player.traversal
	var c: TraversalController = tr.controller if tr else null
	var st := c.anim_state() if c else {}
	var loco: LocoBrain = player.anim.loco if player.anim else null
	var cap_ap := INF
	if tr and tr.world_ready:
		cap_ap = tr.approach_speed(player.horizontal_speed(), 1.0 / 120.0)
	var ap: Dictionary = c.approach() if c else {}
	var rec := {
		"t": t,
		"pos": player.global_position,
		"pelvis": _pelvis_w,
		"rig": tr.rig.global_position if tr and tr.rig else Vector3.INF,
		"vel": player.velocity,
		"mode": c.mode_name() if c else "OFF",
		"move": str(st.get("move", "")),
		"part": int(st.get("part", -1)),
		"t_move": float(st.get("t_move", -1.0)),
		"rate": float(c.get("rate")) if c and c.get("rate") != null else 1.0,
		"pending": c.pending.move_id if c and c.pending else "",
		"ap_dist": float(ap.get("dist", -1.0)),
		"ap_speed": float(ap.get("speed", -1.0)),
		"cap_approach": cap_ap,
		"cap_anim": player.anim.body_speed_cap() if player.anim else INF,
		"loco": String(loco.state) if loco else "",
		"graph": str(loco.graph_state) if loco else "",
		"sprinting": player.is_sprinting,
		"target_speed": player.target_speed,
		"hands_free": player.hands_free,
		"weapon": player.weapon_key,
		"pins": _planted(st.get("pins", [])),
	}
	return rec


## Full-weight plants this tick: limb -> [target id, the planted bone's world position].
func _planted(pins: Array) -> Dictionary:
	var out := {}
	for p: Dictionary in pins:
		if float(p.get("weight", 0.0)) < 0.999 or str(p.get("mode", "plant")) != "plant":
			continue
		var limb := str(p.get("limb", ""))
		var bone := str({"l_hand": "l_middlea", "r_hand": "r_middlea", "l_foot": "l_ball", "r_foot": "r_ball"}.get(limb, ""))
		if bone == "" or int(_bones.get(bone, -1)) < 0:
			continue
		out[limb] = [str(p.get("id", "")), _bones_w.get(bone, sk.global_transform * sk.get_bone_global_pose(int(_bones[bone])).origin)]
	return out


# --- analysis -----------------------------------------------------------------------------------

## Speeds along the travel (-Z) over [move start - PRE_S, hand-back + POST_S]:
##   entry      capsule speed over the 0.25 s before the move starts (the approach included)
##   steady     capsule speed 1 s before the move (the gait before any approach)
##   min_cap / min_model   lowest capsule / smoothed model speed in the window (and where)
##   exit       capsule speed over 0.2-0.5 s after the hand-back; end: over the last 0.3 s of the window
##   slides     per plant (limb, id): the planted bone's world travel while held (m)
static func analyse(fr: Array, began: float, ended: float) -> Dictionary:
	var out := {"began": began, "ended": ended, "ok": began >= 0.0 and ended >= 0.0}
	if fr.size() < 3 or began < 0.0:
		out["ok"] = false
		return out
	var dt := float(fr[1].t) - float(fr[0].t)
	var n := fr.size()
	var cap := PackedFloat32Array()
	var mod := PackedFloat32Array()
	cap.resize(n)
	mod.resize(n)
	for i in n:
		var a: Dictionary = fr[maxi(i - 1, 0)]
		var b: Dictionary = fr[i]
		cap[i] = -((b.pos as Vector3).z - (a.pos as Vector3).z) / dt if i > 0 else 0.0
		var pa: Vector3 = a.pelvis
		var pb: Vector3 = b.pelvis
		mod[i] = -(pb.z - pa.z) / dt if i > 0 and pa != Vector3.INF and pb != Vector3.INF else 0.0
	var half := int(round(SMOOTH_S * 0.5 / dt))
	var smod := PackedFloat32Array()
	smod.resize(n)
	for i in n:
		var s := 0.0
		var k := 0
		for j in range(maxi(1, i - half), mini(n, i + half + 1)):
			s += mod[j]
			k += 1
		smod[i] = s / maxf(k, 1)
	for i in n:
		fr[i]["v_cap"] = cap[i]
		fr[i]["v_model"] = mod[i]
		fr[i]["v_model_s"] = smod[i]
	var i_b := _index_at(fr, began)
	var i_e := _index_at(fr, ended) if ended >= 0.0 else n - 1
	var w0 := _index_at(fr, began - PRE_S)
	var w1 := _index_at(fr, (ended if ended >= 0.0 else began) + POST_S)
	out["steady"] = _mean(cap, _index_at(fr, began - PRE_S - 0.2), w0)
	out["entry"] = _mean(cap, _index_at(fr, began - 0.25), i_b)
	out["exit"] = _mean(cap, _index_at(fr, ended + 0.2), _index_at(fr, ended + 0.5)) if ended >= 0.0 else 0.0
	out["end"] = _mean(cap, _index_at(fr, (ended if ended >= 0.0 else began) + POST_S - 0.3), w1)
	var mc := INF
	var mci := w0
	var mm := INF
	var mmi := w0
	# (The model's smoothed speed from half a window in: the centred window needs both sides.)
	for i in range(w0 + half, w1 - half):
		if cap[i] < mc:
			mc = cap[i]
			mci = i
		if smod[i] < mm:
			mm = smod[i]
			mmi = i
	out["min_cap"] = mc
	out["min_cap_t"] = float(fr[mci].t) - began
	out["min_cap_at"] = "%s/%s" % [fr[mci].mode, fr[mci].move if str(fr[mci].move) != "" else fr[mci].loco]
	out["min_model"] = mm
	out["min_model_t"] = float(fr[mmi].t) - began
	out["min_model_at"] = "%s/%s" % [fr[mmi].mode, fr[mmi].move if str(fr[mmi].move) != "" else fr[mmi].loco]
	out["move"] = str(fr[i_b].move)
	out["duration"] = ended - began if ended >= 0.0 else -1.0
	out["mean_move"] = _mean(cap, i_b, i_e)
	# Planted hands and feet: world travel of the planted bone while the same plant is held.
	var slides := {}
	var first := {}
	for i in range(i_b, i_e):
		var pins: Dictionary = fr[i].pins
		for limb: String in pins:
			var id := str(pins[limb][0])
			var pos: Vector3 = pins[limb][1]
			var key := limb + "@" + id.get_slice("@", 1)
			if not first.has(key):
				first[key] = pos
			# (a plant whose bone has risen off its surface is a limb lifting, e.g. the sprint vault's left knee
			# driving up at the take-off, not a skate: counted only while it stays within LIFT_OFF_M of where it planted)
			if pos.y - (first[key] as Vector3).y > LIFT_OFF_M:
				continue
			slides[key] = maxf(float(slides.get(key, 0.0)), Vector2(pos.x - (first[key] as Vector3).x, pos.z - (first[key] as Vector3).z).length())
	out["slides"] = slides
	var worst := 0.0
	for k: String in slides:
		worst = maxf(worst, float(slides[k]))
	out["slide_max"] = worst
	out["w0"] = w0
	out["w1"] = w1
	return out


static func _index_at(fr: Array, t: float) -> int:
	for i in fr.size():
		if float(fr[i].t) >= t:
			return i
	return fr.size() - 1


static func _mean(a: PackedFloat32Array, i0: int, i1: int) -> float:
	if i1 <= i0:
		return a[clampi(i0, 0, a.size() - 1)]
	var s := 0.0
	for i in range(i0, i1):
		s += a[i]
	return s / float(i1 - i0)


## One line per tick over the window (every `every` ticks): t (from the move start), capsule / model
## speeds, mode, move, part, rate, approach cap, anim cap, lower state, sprint flag, weapon.
static func profile_lines(fr: Array, res: Dictionary, every := 6) -> PackedStringArray:
	var out := PackedStringArray()
	if not bool(res.get("ok", false)):
		return out
	var began := float(res.began)
	for i in range(int(res.w0), int(res.w1), every):
		var f: Dictionary = fr[i]
		out.append("  %+6.2f  cap %5.2f  model %5.2f (%5.2f)  %-4s %-13s p%d tm %5.2f r %4.2f  apcap %5s  animcap %5s  %-6s %-14s spr %d hf %d" % [
			float(f.t) - began, float(f.v_cap), float(f.v_model_s), float(f.v_model), str(f.mode), str(f.move), int(f.part),
			float(f.t_move), float(f.rate), _num(float(f.cap_approach)), _num(float(f.cap_anim)), str(f.loco), str(f.graph).left(14),
			int(bool(f.sprinting)), int(bool(f.hands_free))])
	return out


static func _num(v: float) -> String:
	return "inf" if is_inf(v) else "%.2f" % v
