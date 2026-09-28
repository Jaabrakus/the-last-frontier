extends RefCounted
## WP4 test harness (not a suite; run_all only picks up test_*.gd): the Actor_B rig, the player
## tree built by TreeBuilder from the real graph table, the lower selector L, a virtual weapon
## selector W and a LocoBrain, driven by synthetic AnimInputs from a small kinematic model of
## scripts/player/player.gd (ground accel 14 / decel 18 m/s^2, air accel 2.5, gravity 9.8, jump
## 4.4 m/s; edge events as AnimInputs.sample()).
##
##   const LocoRig := preload("res://tests/anim/loco_rig.gd")
##   var h = LocoRig.new()
##   if not h.setup(ctx, {"overrides": ["override_no_transition_anims"]}): return
##   h.run(30, Vector2(0, 1), 3.6)          # 30 frames holding forward at run speed
##   h.until(func(): return h.brain.state == LocoBrain.MOVE, 240, Vector2(0, 1), 3.6)
##
## Local plane: x = right, y = forward; directions in degrees are + = left (graph convention).

const DT := 1.0 / 60.0
const FOOT := {"l": ["l_heel", "l_ball"], "r": ["r_heel", "r_ball"]}

var ctx: AnimTestContext
var rig: RigFixture
var data: AnimGraphData
var idx: TreeIndex
var tree: AnimationTree
var L: XFadeSelector
var W: XFadeSelector
var brain: LocoBrain
var weapon := &"musket"
var dt := DT

## Kinematic player (local plane; the body faces the camera, so local = world here).
var vel := Vector2.ZERO
var y := 0.0
var vy := 0.0
var floor_y := 0.0
var on_floor := true
var air_time := 0.0
var last_air_vy := 0.0
var yaw := 0.0
var crouched := false
var sprinting := false
var alive := true
var aim_stance := false
var accel := 14.0
var decel := 18.0
var air_accel := 2.5
var gravity := 9.8
var jump_v := 4.4

var frame := 0
var inp: AnimInputs
## Every transitioned signal: {frame, from, to, info}.
var log: Array = []
var events_seen: Array = []


## opts: weapon (musket), overrides ([flags]), options ({name: value}), build (TreeBuilder opts),
## data (AnimGraphData). Returns false after a failed check.
func setup(p_ctx: AnimTestContext, opts := {}) -> bool:
	ctx = p_ctx
	rig = ctx.rig()
	if rig == null:
		return false
	data = opts.get("data") if opts.get("data") != null else AnimGraphData.load_files()
	if data == null:
		ctx.fail("graph table loads")
		return false
	for f in opts.get("overrides", []):
		data.set_override(String(f), true)
	var o: Dictionary = opts.get("options", {})
	for k in o:
		data.set_option(String(k), o[k])
	idx = TreeBuilder.build(data, rig.ap, rig.sk, opts.get("build", {}))
	if not idx.errors.is_empty() or idx.tree_root == null:
		ctx.fail("TreeBuilder builds the player tree: %s" % [idx.errors])
		return false
	rig.play(AnimationNodeBlendTree.new())
	tree = rig.tree
	idx.install(tree)
	L = XFadeSelector.new(tree, "L", idx.L_inputs, idx.L_seek)
	weapon = StringName(opts.get("weapon", "musket"))
	W = XFadeSelector.new(null, "", idx.weapons)
	W.set_immediate(weapon)
	brain = LocoBrain.new(data, tree, idx, L, W)
	brain.transitioned.connect(_on_transition)
	inp = _make_inputs([])
	brain.snap(inp, weapon, false)
	L.write()
	tree.advance(0.0)
	tree.advance(0.0)
	return true


func _on_transition(from: StringName, to: StringName, info: Dictionary) -> void:
	log.append({"frame": frame, "from": from, "to": to, "info": info})


## One frame: move toward `wish_dir` (any length; normalized) at `speed` m/s, then
## brain.step(), then advance. extra: {jump: bool}.
func step(wish_dir := Vector2.ZERO, speed := 0.0, extra := {}) -> AnimInputs:
	frame += 1
	var wish := wish_dir.normalized() * speed if wish_dir.length() > 1e-6 else Vector2.ZERO
	var events: Array[Dictionary] = []
	var was_floor := on_floor
	if extra.get("jump", false) and on_floor:
		vy = jump_v
		on_floor = false
	var a := accel if wish.length() > vel.length() else decel
	if not was_floor:
		a = air_accel
	vel = vel.move_toward(wish, a * dt)
	if not on_floor:
		vy -= gravity * dt if was_floor == false else 0.0
	y += vy * dt
	if y <= floor_y + 1e-6 and vy <= 0.0:
		y = floor_y
		on_floor = true
		vy = 0.0
	elif y > floor_y + 1e-4:
		on_floor = false
	if not on_floor:
		air_time += dt
		last_air_vy = vy
	var prev_floor := was_floor
	if prev_floor and not on_floor:
		events.append({"t": "jumped" if vy > 1.0 else "fell"})
	elif not prev_floor and on_floor:
		events.append({"t": "landed", "impact": -last_air_vy})
	if on_floor:
		air_time = 0.0
	inp = _make_inputs(events, wish, speed if wish.length() > 0.0 else 0.0)
	for e in events:
		events_seen.append({"frame": frame, "event": e})
	brain.step(inp, inp.events, dt, weapon, aim_stance)
	tree.advance(dt)
	return inp


func _make_inputs(events: Array, wish := Vector2.ZERO, target := 0.0) -> AnimInputs:
	var s := AnimInputs.new()
	s.frame = frame
	s.dt = dt
	s.velocity_local = vel
	s.wish_local = wish
	s.target_speed = target
	s.speed = vel.length()
	s.vertical_speed = vy
	s.on_floor = on_floor
	s.air_time = air_time
	s.last_air_vy = last_air_vy
	for e in events:
		s.events.append(e)
	s.crouched = crouched
	s.sprinting = sprinting
	s.alive = alive
	s.yaw = yaw
	s.weapon_key = weapon
	return s


## Puts the kinematic player at rest on the floor at yaw 0 (no crouch, sprint or aim) and snaps
## the brain to idle with those inputs; clears the logs.
func reset() -> void:
	vel = Vector2.ZERO
	y = 0.0
	vy = 0.0
	floor_y = 0.0
	on_floor = true
	air_time = 0.0
	yaw = 0.0
	crouched = false
	sprinting = false
	aim_stance = false
	alive = true
	inp = _make_inputs([])
	brain.snap(inp, weapon)
	run(10)
	log.clear()
	events_seen.clear()


## n frames of the same input.
func run(n: int, wish_dir := Vector2.ZERO, speed := 0.0, extra := {}) -> void:
	for i in n:
		step(wish_dir, speed, extra)


## Steps until cond() is true (checked after each frame) or max frames; returns the frames taken
## (-1 on timeout).
func until(cond: Callable, max_frames: int, wish_dir := Vector2.ZERO, speed := 0.0) -> int:
	for i in max_frames:
		step(wish_dir, speed)
		if cond.call():
			return i + 1
	return -1


## Unit local direction at a graph angle (deg, + = left).
static func dir(a_deg: float) -> Vector2:
	var r := deg_to_rad(a_deg)
	return Vector2(-sin(r), cos(r))


## Transitions logged since index `from_i` whose info key is `key` (or any key when "").
func transitions(key := "", from_i := 0) -> Array:
	var out: Array = []
	for i in range(from_i, log.size()):
		if key == "" or String(log[i].info.get("key", "")) == key:
			out.append(log[i])
	return out


func last() -> Dictionary:
	return log[log.size() - 1] if not log.is_empty() else {}


## Skeleton-space height of the lowest heel / ball of a foot ("l" | "r").
func foot_height(side: String) -> float:
	var h := INF
	for b in FOOT[side]:
		h = minf(h, rig.global_pose(b).origin.y)
	return h


func lowest_foot() -> String:
	return "l" if foot_height("l") < foot_height("r") else "r"


## Hemisphere weights of a bank input ({fw, bw}; {} for other inputs).
func hemi_weights(id: StringName) -> Dictionary:
	var hs: XFadeSelector = brain._hemi_sel(id)
	if hs == null:
		return {}
	return {"fw": hs.weight(&"fw"), "bw": hs.weight(&"bw")}
