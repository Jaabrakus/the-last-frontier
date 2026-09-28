class_name AnimTestContext
extends RefCounted
## Per-suite context handed to AnimTestSuite.run() by tests/anim/run_all.gd (plan section 10).
##
## Assertions (each returns the verdict and prints one line):
##   check(cond, msg)                   plain assertion
##   near(a, b, tol, msg)               |a - b| <= tol for float, int, Vector2/3/4, Quaternion
##                                      (angle, rad), Basis/Transform3D (rotation angle + origin),
##                                      Array / Packed*Array (element-wise maximum)
##   at_most(v, limit, msg) / at_least(v, limit, msg)
##   fail(msg), warn(msg), info(msg), metric(key, value), skip(reason), allow_error(substring)
## Time:      await frames(n) (physics), await idle_frames(n), await seconds(s). Once the runner
##            abandons the suite (TIMEOUT, `abandoned`), these never return: the suite's coroutine
##            stays parked and is dropped, so it cannot check, log or drive input during later
##            suites. Wait through them (and pass {"ctx": ctx} to FootSlip), not on the tree.
## Fixtures:  rig(opts) -> RigFixture (Actor_B), synthetic_rig(bones, anims) -> RigFixture,
##            oracle(rig) -> PoseOracle, await level() -> the Player node of scenes/main.tscn,
##            add_node(node[, parent]) -> node (freed after the suite)
## Options:   arg(name, default) reads `-- name=value` / `--name=value` user arguments.

const MAIN_SCENE := "res://scenes/main.tscn"

var tree: SceneTree
var suite_name := ""
var suite_path := ""
var args := {}
var quiet := false

var checks := 0
var failures := PackedStringArray()
var warnings := PackedStringArray()
var notes := PackedStringArray()
var metrics := {}
var skipped := false
var skip_reason := ""
var allowed_errors := PackedStringArray()

## Set by the runner when it gives up on the suite (TIMEOUT); see "Time" above.
var abandoned := false

var _nodes: Array[Node] = []
var _level_loaded := false
## Emits nothing, ever: an abandoned suite's waits park on it; release_parked() frees it, which
## drops the parked coroutines without resuming them.
var _park: Object = null


func _init(p_tree: SceneTree, p_name := "", p_path := "", p_args := {}) -> void:
	tree = p_tree
	suite_name = p_name
	suite_path = p_path
	args = p_args
	quiet = bool(p_args.get("quiet", false))


# --- assertions ---------------------------------------------------------------------------

func check(cond: bool, msg: String) -> bool:
	checks += 1
	if not cond:
		failures.append(msg)
	_print(("  ok   " if cond else "  FAIL ") + msg, not cond)
	return cond


## |a - b| <= tol. The measured difference is appended to the message.
func near(a: Variant, b: Variant, tol: float, msg: String) -> bool:
	var d := diff(a, b)
	return check(d <= tol, "%s (diff %s, tol %s)" % [msg, fmt(d), fmt(tol)])


func at_most(value: float, limit: float, msg: String) -> bool:
	return check(value <= limit, "%s (%s <= %s)" % [msg, fmt(value), fmt(limit)])


func at_least(value: float, limit: float, msg: String) -> bool:
	return check(value >= limit, "%s (%s >= %s)" % [msg, fmt(value), fmt(limit)])


func fail(msg: String) -> void:
	check(false, msg)


## Not a failure; listed in the summary.
func warn(msg: String) -> void:
	warnings.append(msg)
	_print("  WARN " + msg, false)


func info(msg: String) -> void:
	notes.append(msg)
	_print("  info " + msg, false)


## A measured value, written to the runner's JSON report (-- --json=<path>).
func metric(key: String, value: Variant) -> void:
	metrics[key] = value


## Marks the suite SKIP (checks already made still count). Return from run() afterwards.
func skip(reason: String) -> void:
	skipped = true
	skip_reason = reason
	_print("  SKIP " + reason, false)


## Errors logged while the suite runs fail it unless their text contains one of these.
func allow_error(substring: String) -> void:
	allowed_errors.append(substring)


func arg(name: String, default: Variant = null) -> Variant:
	return args.get(name, default)


# --- time ---------------------------------------------------------------------------------

func frames(n := 1) -> void:
	for i in n:
		await tree.physics_frame
		if abandoned:
			await _parked()


func idle_frames(n := 1) -> void:
	for i in n:
		await tree.process_frame
		if abandoned:
			await _parked()


func seconds(s: float) -> void:
	await frames(maxi(1, ceili(s * Engine.physics_ticks_per_second)))


## Called by the runner on TIMEOUT, before cleanup(): the suite's next wait parks for good.
func abandon() -> void:
	abandoned = true


## Called by the runner after cleanup(): drops the coroutines parked by an abandoned suite.
func release_parked() -> void:
	if _park != null and is_instance_valid(_park):
		_park.free()
	_park = null


func _parked() -> void:
	if _park == null:
		_park = Object.new()
		_park.add_user_signal("never")
	await Signal(_park, "never")


# --- fixtures -----------------------------------------------------------------------------

## Actor_B rig (characters/Actor_B.tscn) with a scratch AnimationTree (callback MANUAL,
## deterministic). opts: see RigFixture.actor_b().
func rig(opts := {}) -> RigFixture:
	var r := RigFixture.actor_b(tree.root, opts)
	if r == null:
		fail("Actor_B rig failed to load")
		return null
	_nodes.append(r.root)
	return r


## Small hand-built rig; see RigFixture.synthetic().
func synthetic_rig(bones: Array, anims: Dictionary) -> RigFixture:
	var r := RigFixture.synthetic(tree.root, bones, anims)
	_nodes.append(r.root)
	return r


func oracle(r: RigFixture) -> PoseOracle:
	return PoseOracle.new(r.sk, r.clip_resolver())


## Loads scenes/main.tscn (the real level, which spawns the player) and returns the Player
## node, or null after a failure. Needs `-- --no-capture` so the player leaves the mouse alone.
func level() -> Node:
	if _level_loaded and tree.current_scene and tree.current_scene.has_node("Player"):
		return tree.current_scene.get_node("Player")
	var err := tree.change_scene_to_file(MAIN_SCENE)
	if err != OK:
		fail("change_scene_to_file(%s) failed: %s" % [MAIN_SCENE, error_string(err)])
		return null
	await idle_frames(2)
	_level_loaded = true
	var player: Node = tree.current_scene.get_node_or_null("Player") if tree.current_scene else null
	if player == null:
		fail("level or player failed to load (see script errors above)")
		return null
	if "ignore_mouse_capture" in player:
		player.ignore_mouse_capture = true
	await frames(10)
	return player


func add_node(node: Node, parent: Node = null) -> Node:
	(parent if parent else tree.root).add_child(node)
	_nodes.append(node)
	return node


## Called by the runner after run(): frees fixture nodes, unloads the level, releases input.
func cleanup() -> void:
	release_inputs()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	# The level may also have been (re)loaded outside level(), e.g. by FootSlip.measure().
	var level_up := tree.current_scene != null and tree.current_scene.scene_file_path == MAIN_SCENE
	if _level_loaded or level_up:
		_level_loaded = false
		if tree.current_scene:
			tree.unload_current_scene()
	await tree.process_frame
	await tree.process_frame


func release_inputs() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)


# --- helpers ------------------------------------------------------------------------------

## True when the main loop steps faster than real time (Godot started with --fixed-fps): 30
## physics frames take well under their 0.25 s of game time. Engine arguments are not visible
## to scripts, so this is measured.
static func faster_than_realtime(p_tree: SceneTree) -> bool:
	var t0 := Time.get_ticks_usec()
	for i in 30:
		await p_tree.physics_frame
	return Time.get_ticks_usec() - t0 < 0.5 * 30.0 / Engine.physics_ticks_per_second * 1e6


## Distance used by near(): angle for rotations, length for vectors, max over arrays.
static func diff(a: Variant, b: Variant) -> float:
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return absf(float(a) - float(b))
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return a.distance_to(b)
		TYPE_QUATERNION:
			return PoseOracle.qdist(a, b)
		TYPE_BASIS:
			return PoseOracle.qdist((a as Basis).get_rotation_quaternion(), (b as Basis).get_rotation_quaternion())
		TYPE_TRANSFORM3D:
			return maxf(PoseOracle.qdist((a as Transform3D).basis.get_rotation_quaternion(),
					(b as Transform3D).basis.get_rotation_quaternion()),
					(a as Transform3D).origin.distance_to((b as Transform3D).origin))
		TYPE_BOOL:
			return 0.0 if a == b else INF
	if a is Array or (typeof(a) >= TYPE_PACKED_BYTE_ARRAY and typeof(a) <= TYPE_PACKED_VECTOR4_ARRAY):
		if a.size() != b.size():
			return INF
		var m := 0.0
		for i in a.size():
			m = maxf(m, diff(a[i], b[i]))
		return m
	return 0.0 if a == b else INF


static func fmt(x: float) -> String:
	if is_inf(x) or is_nan(x):
		return str(x)
	if x != 0.0 and (absf(x) < 1e-3 or absf(x) >= 1e5):
		var e := floori(log(absf(x)) / log(10.0))
		var m := x / pow(10.0, e)
		if absf(m) >= 9.995:
			m /= 10.0
			e += 1
		return "%.2fe%d" % [m, e]
	return "%.4f" % x


func _print(line: String, is_failure: bool) -> void:
	if quiet and not is_failure:
		return
	print(line)
