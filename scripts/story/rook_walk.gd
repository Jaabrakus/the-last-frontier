class_name RookWalk
extends Node
## The Man with No Shadow, staged (docs/main_story.md 10.2, mission 12: "Rook walks you toward the fort through the snow.
## Wolves come to the raid's dead stock, and he drives them off with Gust ... By the moon on the snow you see he casts no
## shadow"; 9.2: "his mesh doesn't cast one"; 15 item 1: "Rook's walk with the wolves").
##
##   var walk := RookWalk.begin(level, rook, toward)      rook: a StoryWalker (null: one made at the player's side)
##   walk.done.connect(...)                               Rook at `toward` (within ARRIVE_M), the wolves gone
##   walk.wolves_fled.connect(...)                        the pack driven off
##
## THE WALK: Rook goes toward `toward` at a walk (the walk grid), waiting and looking back when the player is more than
## WAIT_M behind; his lines (opts lines: [[share of the way, text], ...]) over his head as he goes (StoryBark).
## THE WOLVES: WOLVES_AFTER_S into the walk (or WOLVES_AFTER_M along it, whichever first; opts), a pack of opts wolves (3)
## comes in from WOLF_FROM_M off the way, hungry and after the player (the level's WildlifeSpawner: a pack of its own,
## WildAnimal's own stalk and chase). No wildlife in the level (wildlife=off), or another's world (a co-op joiner's: the host's
## animals): no wolves, and `wolves_fled` at once.
## GUST: one within GUST_AT_M of Rook or the player, Rook stops, turns to it and casts (the casting hand thrust out: our own
## stab clip, its swing without the musket, NpcBody's club_intro then club); at the thrust every wolf within GUST_M (the
## Sway's Gust range: docs 11.2) is blown back (the Sway's own push when the game has scripts/sway: SwayEffects.shove_animal at
## the gust's numbers; else a shove of GUST_PUSH m/s that dies away) and the pack is routed (WildGroup.routed_until: it runs from where he
## stood for ROUT_S and leaves the player be). One coming back within GUST_AT_M is cast at again (GUST_COOLDOWN_S apart,
## at most MAX_CASTS). All of them past FLED_M from the player (or running FLED_S): `wolves_fled`, and the walk goes on.
## Rook casts no shadow (StoryWalker shadow false). Not saved.

signal wolves_came(wolves: Array)
signal gust(target: Node3D)
signal wolves_fled
signal done

const GROUP := &"rook_walk"
const ARRIVE_M := 4.0
const WAIT_M := 10.0
const GO_ON_M := 5.0
const PACE := 1.25
const WOLVES := 3
const WOLVES_AFTER_S := 20.0
const WOLVES_AFTER_M := 60.0
const WOLF_FROM_M := 45.0
const GUST_AT_M := 20.0
const GUST_M := 25.0
const GUST_PUSH := 9.0
const GUST_COOLDOWN_S := 4.0
const MAX_CASTS := 3
const ROUT_S := 90.0
const FLED_M := 55.0
const FLED_S := 10.0
## The cast: the stab's strike into its swing (s), NpcFighter's club numbers.
const THRUST_AT := 0.22
## His peoples preset; his clothes are his costume (data/story/costumes.json "rook": the Drift set's sailor's dress of Act 2).
const ROOK_LOOK := "palatine_m_b"
const STAY_LINE := "Stay by me."
const AFTER_LINE := "They will not come again tonight."

var level: Node
var player: FrontierPlayer
var rook: Node3D
var toward := Vector3.ZERO
var spawner: WildlifeSpawner
var wolves: Array[WildAnimal] = []
## "walk", "wolves" (in sight, coming), "cast", "after" (driven off), "done".
var phase := ""
var casts := 0
var opts := {}
## The walk's length at the start and how far Rook has come along it.
var length := 0.0
var walked := 0.0
var fled := false

var _t := 0.0
var _phase_t := 0.0
var _cast_t := 0.0
var _cool := 0.0
var _thrust := -1.0
var _cast_on: WildAnimal
var _flee_t := 0.0
var _last := Vector3.ZERO
var _lines: Array = []
var _shoves: Array = []
var _waiting := false


## The walk begun under `level`: `rook` (a StoryWalker, or any Node3D: one that is not is moved here; null: a Rook made at
## the player's side) toward `toward`. opts: wolves (3), wolves_after_s, wolves_after_m, lines ([[share, text]]), pace.
static func begin(p_level: Node, p_rook: Node3D, p_toward: Vector3, p_opts := {}) -> RookWalk:
	var w := RookWalk.new()
	w.name = "RookWalk"
	p_level.add_child(w)
	w.start(p_rook, p_toward, p_opts)
	return w


static func find(tree: SceneTree) -> RookWalk:
	return tree.get_first_node_in_group(GROUP) as RookWalk if tree else null


## Rook as he walks the valley: a Palatine man of fifty-seven in a sky sailor's dress (check shirt, tarred slops, sea
## boots, waistcoat, mote belt and weather cape), with no shadow under our sun.
static func make_rook(parent: Node, at: Vector3, face := Vector3.INF) -> StoryWalker:
	var o := {"tag": "rook", "name": "Rook", "shadow": false, "group": [&"story_people"], "node_name": "rook"}
	if face != Vector3.INF:
		o["face"] = face
	return StoryWalker.make(parent, at, StoryWalker.person_look(ROOK_LOOK, "rook"), o)


func _ready() -> void:
	add_to_group(GROUP)


func start(p_rook: Node3D, p_toward: Vector3, p_opts := {}) -> void:
	opts = p_opts
	level = get_parent()
	player = StoryObjectives.player(get_tree())
	toward = _ground(p_toward)
	rook = p_rook
	if rook == null or not is_instance_valid(rook):
		var at := player.global_position + _side() * 1.6 if player else toward
		rook = make_rook(self, at, toward)
	spawner = level.get_node_or_null("Wildlife") as WildlifeSpawner
	if spawner == null:
		spawner = get_tree().get_first_node_in_group(&"wildlife_spawner") as WildlifeSpawner
	_lines = (opts.get("lines", []) as Array).duplicate()
	_lines.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	length = _flat(rook.global_position, toward)
	_last = rook.global_position
	phase = "walk"
	_go()


## The wolves of the walk alive and still in the world.
func live_wolves() -> Array[WildAnimal]:
	var out: Array[WildAnimal] = []
	for a in wolves:
		if is_instance_valid(a) and not a.is_queued_for_deletion() and not a.is_dead():
			out.append(a)
	return out


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	if phase == "" or phase == "done" or rook == null or not is_instance_valid(rook):
		return
	_t += dt
	_phase_t += dt
	_cool = maxf(_cool - dt, 0.0)
	walked += _flat(_last, rook.global_position)
	_last = rook.global_position
	_shove(dt)
	_say_lines()
	match phase:
		"walk", "after":
			_walking()
			# (they come at the latest as he nears the end of the way)
			if phase == "walk" and wolves.is_empty() and (_t >= float(opts.get("wolves_after_s", WOLVES_AFTER_S))
					or walked >= float(opts.get("wolves_after_m", WOLVES_AFTER_M))
					or _flat(rook.global_position, toward) <= ARRIVE_M * 3.0):
				_wolves_come()
			if phase == "after" and _flat(rook.global_position, toward) <= ARRIVE_M:
				phase = "done"
				_stop(player.global_position if player else toward)
				done.emit()
				return
			_watch_wolves()
		"wolves":
			_walking()
			_watch_wolves()
		"cast":
			_casting(dt)


## Rook along the way, waiting for the player when he falls behind (and looking back at him).
func _walking() -> void:
	if player == null:
		return
	var behind := _flat(player.global_position, rook.global_position)
	if not _waiting and behind > WAIT_M:
		_waiting = true
		_stop(player.global_position)
	elif _waiting and behind < GO_ON_M:
		_waiting = false
		_go()
	elif not _waiting and rook is StoryWalker and (rook as StoryWalker).goal == Vector3.INF:
		_go()
	if not (rook is StoryWalker) and not _waiting:
		_step_by_hand(get_physics_process_delta_time())


func _go() -> void:
	if rook is StoryWalker:
		(rook as StoryWalker).go(toward, float(opts.get("pace", PACE)), ARRIVE_M * 0.6)


func _stop(face: Vector3) -> void:
	if rook is StoryWalker:
		(rook as StoryWalker).stop(face)


## A Rook that is not a walker, moved here: straight on the ground at the pace.
func _step_by_hand(dt: float) -> void:
	var at := rook.global_position
	var d := Vector3(toward.x - at.x, 0.0, toward.z - at.z)
	if d.length() < 0.05:
		return
	var step := minf(d.length(), float(opts.get("pace", PACE)) * dt)
	var nx := at + d.normalized() * step
	nx.y = FrontierTerrain.height_at(nx.x, nx.z)
	rook.global_position = nx
	rook.rotation.y = atan2(-d.x, -d.z)


func _say_lines() -> void:
	if _lines.is_empty() or length <= 0.0:
		return
	var l: Array = _lines[0]
	if walked / length >= float(l[0]):
		_lines.pop_front()
		StoryBark.say(rook, String(l[1]), 4.0)


# ---------------------------------------------------------------- the wolves
func _wolves_come() -> void:
	if spawner == null or player == null or spawner.mirror:      # (a joiner's world shows the host's animals only)
		phase = "after"
		fled = true
		wolves_fled.emit()
		return
	var n := int(opts.get("wolves", WOLVES))
	var fwd := toward - rook.global_position
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.5 else Vector3.FORWARD
	var g: WildGroup = null
	for k in 12:
		var side := 1.0 if k % 2 == 0 else -1.0
		var ring := floorf(float(k) * 0.5)
		var ang := side * (1.1 + 0.15 * ring)
		var home := player.global_position + fwd.rotated(Vector3.UP, ang) * (WOLF_FROM_M + ring * 4.0)
		home.y = FrontierTerrain.height_at(home.x, home.z)
		g = spawner._spawn_group("wolf_pack", home, false, n)
		if g != null and not g.members.is_empty():
			break
		if g != null:
			_drop_group(g)
			g = null
	if g == null:
		phase = "after"
		fled = true
		wolves_fled.emit()
		return
	for a: WildAnimal in g.members:
		if not is_instance_valid(a):
			continue
		a.hunger = maxf(a.hunger, 0.8)
		a.awareness = 1.2
		a.threat_pos = player.global_position
		a.set_active(true)
		wolves.append(a)
	g.after_player_until = spawner.now + 240.0          # (after him: they come on, as for a kill they tracked that was his)
	g.raise_alarm(player.global_position, spawner.now)
	phase = "wolves"
	_phase_t = 0.0
	StoryBark.say(rook, STAY_LINE, 3.0)
	wolves_came.emit(wolves.duplicate())


## A pack that made no members (no room there): out of the spawner's list again.
func _drop_group(g: WildGroup) -> void:
	for i in range(spawner.groups.size() - 1, -1, -1):
		if spawner.groups[i].get("group") == g:
			spawner.groups.remove_at(i)


## The nearest wolf in reach casts Gust; driven off, the walk goes on once they are all far (or long running).
func _watch_wolves() -> void:
	var live := live_wolves()
	if live.is_empty():
		if phase == "wolves" or (phase == "after" and not fled):
			_all_fled()
		return
	var near: WildAnimal = null
	var nd := INF
	for a in live:
		var d := minf(_flat(a.global_position, rook.global_position), _flat(a.global_position, player.global_position) if player else INF)
		if d < nd:
			nd = d
			near = a
	if nd <= GUST_AT_M and _cool <= 0.0 and casts < MAX_CASTS and not _routed(near):
		_cast_at(near)
		return
	if casts > 0 and not fled:
		_flee_t += get_physics_process_delta_time()
		var far := true
		for a in live:
			if player != null and _flat(a.global_position, player.global_position) < FLED_M:
				far = false
		if far or _flee_t >= FLED_S:
			_all_fled()


func _routed(a: WildAnimal) -> bool:
	return a.group != null and spawner != null and spawner.now < a.group.routed_until and a.state == WildAnimal.State.FLEE


func _all_fled() -> void:
	fled = true
	phase = "after"
	_phase_t = 0.0
	if casts > 0:
		StoryBark.say(rook, AFTER_LINE, 3.5)
	_waiting = false
	_go()
	wolves_fled.emit()


# ---------------------------------------------------------------- Gust
func _cast_at(a: WildAnimal) -> void:
	phase = "cast"
	_phase_t = 0.0
	_cast_on = a
	_stop(a.global_position)
	if rook is StoryWalker:
		(rook as StoryWalker).face_now(a.global_position)
		var intro := (rook as StoryWalker).play_once("club_intro", 0.1)
		_thrust = intro + THRUST_AT
		_cast_t = intro + maxf((rook as StoryWalker).body.clip_length("club"), THRUST_AT + 0.3) if (rook as StoryWalker).body else 0.8
	else:
		_thrust = 0.35
		_cast_t = 0.8


func _casting(_dt: float) -> void:
	var w := rook as StoryWalker
	if w != null and w.body != null and _thrust > 0.0 and _phase_t >= _thrust - THRUST_AT and w.body.clip == "club_intro":
		w.play_once("club", 0.05)
	if _thrust > 0.0 and _phase_t >= _thrust:
		_thrust = -1.0
		_gust()
	if _phase_t >= _cast_t:
		_cool = GUST_COOLDOWN_S
		phase = "wolves"
		_flee_t = 0.0
		_go()


## The thrust: every wolf within GUST_M of Rook blown back and the pack routed (it runs from him and leaves the player be).
func _gust() -> void:
	casts += 1
	var from := rook.global_position
	var aim := _cast_on.global_position if is_instance_valid(_cast_on) else from + _rook_fwd() * 5.0
	var dir := aim - from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else _rook_fwd()
	_puff(from + Vector3.UP * 1.3, dir)
	if Sfx.has(&"arrow_whoosh"):
		Sfx.play_3d(&"arrow_whoosh", from + dir * 2.0, 4.0, 0.45)
	var hit_any: WildAnimal = null
	for a in live_wolves():
		var to := a.global_position - from
		to.y = 0.0
		if to.length() > GUST_M and _flat(a.global_position, player.global_position if player else from) > GUST_M:
			continue
		var away := to.normalized() if to.length() > 0.1 else dir
		if not _sway_push(a, from, away, to.length()):
			_shoves.append({"a": a, "v": away * GUST_PUSH * clampf(1.4 - to.length() / GUST_M, 0.4, 1.2)})
		a._start_flee(from)
		if a.group != null:
			a.group.after_player_until = -1e9
			a.group.routed_until = spawner.now + ROUT_S if spawner else a.group.routed_until
		a.threat_pos = from
		if hit_any == null:
			hit_any = a
	gust.emit(hit_any if hit_any != null else _cast_on)


## The Sway's own push (scripts/sway: SwayEffects.shove_animal, its skid and the run from the caster, at the gust's numbers in
## data/sway/moves.json, falling off with the distance as a player's gust does), when the game has it: true when it took it.
func _sway_push(a: WildAnimal, from: Vector3, away: Vector3, dist: float) -> bool:
	var fx := StoryEffects.global_script("SwayEffects")
	if fx == null or not fx.has_method("shove_animal"):
		return false
	var mps := 4.5
	var near := 8.0
	var far_share := 0.45
	var reach := GUST_M
	var mv := StoryEffects.global_script("SwayMoves")
	if mv != null and mv.has_method("move"):
		var d: Variant = mv.call("move", "gust")
		if d is Dictionary:
			reach = float((d as Dictionary).get("range_m", reach))
			var push: Variant = (d as Dictionary).get("push", {})
			if push is Dictionary:
				mps = float((push as Dictionary).get("animal_mps", mps))
				near = float((push as Dictionary).get("near_full_m", near))
				far_share = float((push as Dictionary).get("far_share", far_share))
	var k := lerpf(1.0, far_share, clampf((dist - near) / maxf(reach - near, 0.1), 0.0, 1.0))
	fx.call("shove_animal", a, away * mps * k, from)
	return true


## The blow-back without a caster: the wolf carried GUST_PUSH m/s off along the ground, dying away in a moment.
func _shove(dt: float) -> void:
	for i in range(_shoves.size() - 1, -1, -1):
		var e: Dictionary = _shoves[i]
		var a := e.a as WildAnimal
		var v: Vector3 = e.v
		if not is_instance_valid(a) or v.length() < 0.4:
			_shoves.remove_at(i)
			continue
		var np := a.global_position + v * dt
		np.y = maxf(FrontierTerrain.height_at(np.x, np.z), a.global_position.y - 0.5)
		a.global_position = np
		e.v = v * exp(-5.0 * dt)


## The air thrown: a burst of snow-dust along the thrust (a few particles, once; none headless).
func _puff(at: Vector3, dir: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles3D.new()
	p.name = "GustPuff"
	p.one_shot = true
	p.emitting = false
	p.amount = 48
	p.lifetime = 0.9
	p.explosiveness = 0.85
	p.direction = Vector3(0, 0, -1)
	p.spread = 18.0
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 16.0
	p.damping_min = 6.0
	p.damping_max = 9.0
	p.gravity = Vector3(0, -1.0, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.4
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.92, 0.95, 1.0, 0.35)
	q.material = m
	p.mesh = q
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	p.color_ramp = ramp
	add_child(p)
	p.global_position = at
	p.look_at(at + dir, Vector3.UP)
	p.emitting = true
	get_tree().create_timer(2.0, false).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- helpers
func _rook_fwd() -> Vector3:
	var f := -rook.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _side() -> Vector3:
	var d := toward - player.global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.5 else Vector3.FORWARD
	return d.cross(Vector3.UP).normalized()


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
