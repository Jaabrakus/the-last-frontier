class_name PlayerBendCaster
extends BendCaster
## The player as a caster (BendCaster; his SwayCaster's lock and modes): the aim his camera's (the crosshair: its ray past him,
## FormEffects.aim_point's rule), the aim's help on a fighter near the crosshair (BendCaster.assist_target: FormEffects'
## rule), his chest SwayCaster.chest, the sidestep's side his keys (move_left / move_right; none held: by chance), his notices
## on his screen, his water his Bending. A bolt leaves from his pose's strike point when the pose has one (strike_point(), not
## Vector3.INF: the animation hooks), else from his chest a little along the aim. Exactly what the player's bends did before
## the caster was made one (the owner: "no behaviour change for the player").
## Online (NetCasts, docs/tidebreak/ring_netcode.md "Casts"): while his cast is recorded (tape_begin .. tape_end) every answer
## he gives is kept in order under its question's name (the outermost question only: one that asks another is kept once), the
## modes and tiers he gives by move, his dice drawn from the cast's seed: another machine's NetBendCaster answers the same
## questions the same way from them.

var sway: SwayCaster
var player: FrontierPlayer
## The cast being recorded online (NetCasts): question -> its answers in order ({} none).
var tape := {}
var _tape_d := 0
var _tape_rng: RandomNumberGenerator


func _init(sc: SwayCaster = null) -> void:
	sway = sc
	player = sc.player if sc != null else null
	body = player


# ---------------------------------------------------------------- online: the cast's tape
## A cast's recording begins (NetCasts.begin): its dice from `seed` from now.
func tape_begin(seed: int) -> void:
	tape = {"modes": {}, "tiers": {}}
	_tape_d = 0
	_tape_rng = RandomNumberGenerator.new()
	_tape_rng.seed = seed


## The recording ended: its tape ({} none was running). Its dice go on from its seed (a volley's later bolts draw theirs from
## it on every machine alike) until the next cast's.
func tape_end() -> Dictionary:
	var out := tape
	tape = {}
	_tape_d = 0
	return out


## An answer `v` to question `key` given (kept when recording and it is the outermost question). `v`.
func _rec(key: String, v: Variant) -> Variant:
	_tape_d -= 1
	if _tape_d == 0 and not tape.is_empty():
		if not tape.has(key):
			tape[key] = []
		(tape[key] as Array).append(NetSpells.enc(v))
	return v


# ---------------------------------------------------------------- the questions
func chest() -> Vector3:
	_tape_d += 1
	return _rec("chest", sway.chest() if sway != null and is_instance_valid(sway) else super.chest())


func facing() -> Vector3:
	_tape_d += 1
	var cam := _cam()
	var f := -cam.global_basis.z if cam != null else -player.global_basis.z
	f.y = 0.0
	return _rec("facing", f.normalized() if f.length_squared() > 1e-6 else -player.global_basis.z)


func aim_ray() -> Array:
	_tape_d += 1
	var cam := _cam()
	if cam == null:
		return _rec("aim_ray", super.aim_ray())
	return _rec("aim_ray", [cam.global_position, -cam.global_basis.z])


## The crosshair's point now: the camera's ray (from `from`, else the camera) past the player and `ex`, its hit, else 80 m along
## it; INF with no camera (FormEffects.aim_point).
func aim_point(ex: Array = [], from := Vector3.INF) -> Vector3:
	_tape_d += 1
	var cam := _cam()
	if cam == null:
		return _rec("aim_point", Vector3.INF)
	if from == Vector3.INF:
		from = cam.global_position
	var dir := -cam.global_basis.z
	var exl: Array[RID] = [player.get_rid()]
	for r in ex:
		exl.append(r)
	var h := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, 0xFFFFFFFF, exl))
	return _rec("aim_point", h.position if not h.is_empty() else from + dir * 80.0)


func aim_target() -> Node3D:
	_tape_d += 1
	var cam := _cam()
	if cam == null:
		return _rec("aim_target", null)
	return _rec("aim_target", assist_target(cam.global_position, -cam.global_basis.z))


## The aim's help by the player's setting (MatchSetup.aim_help; the owner, 2026-10-05: "the auto aim is to strong"): its
## cone (none when off), then BendCaster's rule.
func assist_target(from: Vector3, dir: Vector3, ex: Array = []) -> Node3D:
	_tape_d += 1
	var deg := MatchSetup.aim_cone_deg()
	if deg <= 0.0:
		return _rec("assist_target", null)
	assist_deg = deg
	return _rec("assist_target", super.assist_target(from, dir, ex))


## Where a cast helped onto `t` goes: "strong" his chest led by his pace over the flight (the old help); "light" the
## crosshair's point pulled part of the way toward his chest (MatchSetup.aim_pull), no lead.
func target_point(t: Node3D, mps := 0.0) -> Vector3:
	_tape_d += 1
	var at := NpcSenses.chest_of(t)
	var pull := MatchSetup.aim_pull()
	if pull >= 0.999:
		if mps > 0.0:
			var v := NpcSenses.velocity_of(t)
			return _rec("target_point", at + Vector3(v.x, 0.0, v.z) * at.distance_to(chest()) / mps)
		return _rec("target_point", at)
	var cross := aim_point()
	if cross == Vector3.INF:
		return _rec("target_point", at)
	return _rec("target_point", cross.lerp(at, pull))


func launch_point(flat := Vector3.ZERO) -> Vector3:
	_tape_d += 1
	var pose: Variant = sway.get(&"pose") if sway != null and is_instance_valid(sway) else null
	if pose is Object and is_instance_valid(pose) and (pose as Object).has_method(&"strike_point"):
		var sp: Variant = (pose as Object).call(&"strike_point")
		if sp is Vector3 and sp != Vector3.INF:
			return _rec("launch_point", sp)
	return _rec("launch_point", super.launch_point(flat))


func exclude() -> Array[RID]:
	var ex: Array[RID] = [player.get_rid()]
	return ex


func side_sign() -> float:
	_tape_d += 1
	var lr := held_side()
	if absf(lr) > 0.1:
		return _rec("side_sign", lr)
	return _rec("side_sign", 1.0 if rand_f() < 0.5 else -1.0)


## The side his keys hold (move_left -1, move_right 1; 0 neither, or both).
func held_side() -> float:
	_tape_d += 1
	var lr := Input.get_axis(&"move_left", &"move_right") if InputMap.has_action(&"move_left") and InputMap.has_action(&"move_right") else 0.0
	return _rec("held_side", signf(lr) if absf(lr) > 0.1 else 0.0)


## The way his move keys hold (x right, y forward; his controls' move vector: a test's own too).
func held_move() -> Vector2:
	_tape_d += 1
	if held_override != null:
		return _rec("held_move", held_override as Vector2)
	if player == null or player.controls == null:
		return _rec("held_move", Vector2.ZERO)
	var v := player.controls.move_vector()
	var hv := Vector2(v.x, -v.y)
	if hv.length() < 0.3 and BendStatus.now() <= press_move_until:
		hv = press_move                        # (the chord's way, its keys let go before the move went: latch_move)
	return _rec("held_move", hv)


## Tests only: not null stands for the move keys held (held_move).
var held_override: Variant = null

## The way the move keys held at key 3's press (Shift + a direction, SwayCaster.key3_press), until press_move_until: held_move's
## answer when the keys are let go before the move goes (its lock fills after the press: Skate's 0.4 s; a tap of Shift + W went
## back, the move reel 2026-10-12).
var press_move := Vector2.ZERO
var press_move_until := -INF


## The keys held now kept for `s` seconds (none held: the last kept stands).
func latch_move(s: float) -> void:
	if player == null or player.controls == null:
		return
	var v := player.controls.move_vector()
	if v.length() >= 0.3:
		press_move = Vector2(v.x, -v.y)
		press_move_until = BendStatus.now() + s


func jump_held() -> bool:
	_tape_d += 1
	return _rec("jump_held", player != null and player.controls != null and player.controls.pressed(&"jump"))


func mode_of(id: String) -> String:
	var md := sway.mode_of(id) if sway != null and is_instance_valid(sway) else super.mode_of(id)
	if not tape.is_empty() and not (tape.modes as Dictionary).has(id):
		tape.modes[id] = md
	return md


func tier(id: String) -> int:
	var t := sway.tier(id) if sway != null and is_instance_valid(sway) else 1
	if not tape.is_empty() and not (tape.tiers as Dictionary).has(id):
		tape.tiers[id] = t
	return t


func notice(text: String, s := 1.6) -> void:
	if player != null and player.interactor != null and player.is_local:
		player.interactor.notice(text, s)


func is_local() -> bool:
	return player != null and player.is_local


## The player's chances are the global ones (as his bends' were); a recorded cast's, its seed's (tape_begin).
func rand_f() -> float:
	return _tape_rng.randf() if _tape_rng != null else randf()


func rand_i() -> int:
	return _tape_rng.randi() if _tape_rng != null else randi()


func _cam() -> Camera3D:
	var cam := player.camera if player != null else null
	return cam if cam != null and cam.is_inside_tree() else null
