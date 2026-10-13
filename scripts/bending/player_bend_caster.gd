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


## Eye and hand (the owner, 2026-10-12: "in the videos you record the cross hair is perfect on target but in the run build i
## play i have to aim higher"): the crosshair looks from the camera, 2.4-3.2 m over the hand a cast leaves from, and a cast
## sent from the hand to where the crosshair's ray stops crosses the crosshair's line only THERE. On a foe that is him: exact.
## Past him (the dot over his head, beside him, ahead of a runner: the ray on the deck or the stands 16-80 m off) the cast
## passed 0.6-1.7 m under the dot where he stood, so a dot over his head hit his belly. A flight goes instead to the
## crosshair's line at the depth of the foe nearest that line (within CONVERGE_DEG of it, ahead), when the ray runs on past
## him: it crosses the dot exactly where he stands. Depth only: the point never leaves the crosshair's line, nothing is
## pulled toward him (no help, the Off setting too; the help is assist_target / target_point's). The ray stopping on him or
## on anything before him (a wall, a stone) keeps its point; bodies of the player's side are left out of the ray as his
## bolts pass them (BendCaster.ally_rids). No foe by the line: aim_point.
const CONVERGE_DEG := 10.0


func flight_point(ex: Array = [], from := Vector3.INF) -> Vector3:
	_tape_d += 1
	var cam := _cam()
	var exl: Array = ex.duplicate()
	exl.append_array(BendCaster.ally_rids(self))
	var pt := aim_point(exl, from)
	if cam == null or not pt.is_finite():
		return _rec("flight_point", pt)
	var o := cam.global_position if from == Vector3.INF else from
	var dir := -cam.global_basis.z
	var best_a := deg_to_rad(CONVERGE_DEG)
	var depth := -1.0
	var pool: Array = player.get_tree().get_nodes_in_group(NpcFighter.GROUP).duplicate()
	for pl in player.get_tree().get_nodes_in_group(&"player"):
		if not pool.has(pl):
			pool.append(pl)
	for n in pool:
		var f := n as CharacterBody3D
		if f == null or f == player or not NpcSenses.can_fight(f) or BendCaster.same_team(player, f):
			continue
		var to := NpcSenses.chest_of(f) - o
		var along := to.dot(dir)
		var a := to.angle_to(dir)
		if along > 1.0 and a < best_a:
			best_a = a
			depth = along
	if depth < 0.0 or (pt - o).dot(dir) <= depth:
		return _rec("flight_point", pt)          # (no foe by the line, or the ray stops on him or before him)
	return _rec("flight_point", o + dir * depth)


func aim_target() -> Node3D:
	_tape_d += 1
	var cam := _cam()
	if cam == null:
		return _rec("aim_target", null)
	return _rec("aim_target", assist_target(cam.global_position, -cam.global_basis.z))


## The aim's help by the player's setting (MatchSetup.aim_help; the owner, 2026-10-05: "the auto aim is to strong"): its
## cone (none when off), then BendCaster's rule. Normal's cone is the casting ring (ring_deg; the owner, 2026-10-12: "for the
## aim assit anything within the circle not just the dot"), and it never takes one of the player's side, nor lets one of
## them standing on the way hide a foe in the ring (his bolts pass them: BendCaster.ally_rids, as flight_point's ray).
func assist_target(from: Vector3, dir: Vector3, ex: Array = []) -> Node3D:
	_tape_d += 1
	var deg := MatchSetup.aim_cone_deg()
	if deg < 0.0:
		deg = ring_deg()
		ex = ex.duplicate()
		ex.append_array(BendCaster.ally_rids(self))
	if deg <= 0.0:
		return _rec("assist_target", null)
	assist_deg = deg
	return _rec("assist_target", super.assist_target(from, dir, ex))


## The ring's help never takes one of the player's side (BendCaster.same_team).
func assist_skips(f: Node3D) -> bool:
	return MatchSetup.aim_cone_deg() < 0.0 and BendCaster.same_team(player, f)


## The casting ring's angular radius now (deg): SwayRing.RADIUS as the ring is drawn on the screen (its canvas's scale, over
## the height of the viewport it is drawn in) through the camera's vertical FOV. The ring's size whether or not it is drawn
## at this moment (a tap, the jab, a flick): the help is what the ring shows. Headless (no screen) the game window's height
## from the project's settings stands for the viewport's. 0 with no camera.
func ring_deg() -> float:
	var cam := player.camera if player != null else null
	if cam == null or not is_instance_valid(cam):
		return 0.0
	var r := SwayRing.RADIUS
	var h := 0.0
	var rn: SwayRing = sway.ring if sway != null and is_instance_valid(sway) else null
	if rn != null and is_instance_valid(rn) and rn.is_inside_tree():
		r *= absf(rn.get_global_transform_with_canvas().get_scale().y)
		h = rn.get_viewport_rect().size.y
	elif cam.is_inside_tree():
		h = cam.get_viewport().get_visible_rect().size.y
	if DisplayServer.get_name() == "headless":
		# (no screen, the root a 64 px stub: the ring as the game's own window would show it)
		h = float(ProjectSettings.get_setting("display/window/size/viewport_height", h))
	if h <= 0.0:
		return 0.0
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	if cam.keep_aspect == Camera3D.KEEP_WIDTH and cam.is_inside_tree():
		var sz := cam.get_viewport().get_visible_rect().size
		half *= sz.y / maxf(sz.x, 1.0)       # (the FOV the width's: the height's half-angle from it)
	return rad_to_deg(atan(half * r / (h * 0.5)))


## Where a cast helped onto `t` goes: "strong" and Normal (the ring) his chest led by his pace over the flight; a partial
## pull (none set now) the crosshair's point at his depth (flight_point) pulled part of the way toward his chest
## (MatchSetup.aim_pull), no lead.
func target_point(t: Node3D, mps := 0.0) -> Vector3:
	_tape_d += 1
	var at := NpcSenses.chest_of(t)
	var pull := MatchSetup.aim_pull()
	if pull >= 0.999:
		if mps > 0.0:
			var v := NpcSenses.velocity_of(t)
			return _rec("target_point", at + Vector3(v.x, 0.0, v.z) * at.distance_to(chest()) / mps)
		return _rec("target_point", at)
	var cross := flight_point()
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
