class_name NpcBending
extends RefCounted
## A fighter that bends the earth and the air instead of shooting (NpcFighter.tactics "bend": the duel's opponent; the user,
## 2026-10-04: "remove the guns in 1v1 its just spells", "we switch to a elemental avatar the last airbender type of game").
## NpcBrain's COMBAT hands it each think (step) once it has a foe; it has no gun and no axe. Its moves are the player's spells'
## own pieces (FormStone, FormRaised, the hollow, the sounds), cast by its own body (the player's push clip: NpcBody
## "cast_push"), each with a wind-up the player can read and a cooldown:
##   SPIKE   a stone spike bursts out of the ground before it and is hurled at the foe's chest (led by his pace over the
##           flight, scattered by its skill: SKILL_DEG), flying as the player's do (Flight: struck on the point, sticks
##           where it lands)
##   WALL    struck since its last wall: an earth wall of the ground's matter raised between it and the foe (the player's
##           Earth Wall's numbers: FormMatter), and it fights on from behind it
##   GUST    the foe within GUST.near_m: a blast of air that throws him off his feet (FrontierPlayer.knock_down; pushed
##           when he cannot fall)
## Between casts it keeps its range (KEEP_M: in when far or unseen, back when near) and circles him, facing him. Struck in a
## wind-up (a flinch), the cast is lost. Counted for the tests (spikes, walls, gusts, hits).

const FormMatter := preload("res://scripts/sway/form_matter.gd")
## Its spikes in flight (Flight): a guard can catch, deflect or cushion them (BendZone).
const FLIGHT_GROUP := &"bend_stone_flights"
const KEEP_M := Vector2(9.0, 17.0)
const SPIKE := {"cool_s": [1.8, 3.0], "wind_s": 0.8, "ahead_m": 1.3, "mps": 30.0, "gravity": 3.0, "damage": 34.0, "range_m": 40.0}
const WALL := {"cool_s": 10.0, "wind_s": 0.55, "ahead_m": 1.6}
const GUST := {"cool_s": 4.5, "wind_s": 0.4, "near_m": 5.0, "reach_m": 7.0, "push_mps": 9.0, "up_mps": 3.0}
## Its throw's scatter by its skill preset (deg, one sigma; "" a fighter's own: normal).
const SKILL_DEG := {"easy": 3.2, "normal": 1.8, "hard": 0.9}
const STRAFE_S := Vector2(1.4, 3.0)

var brain: NpcBrain
var me: NpcFighter
var casting := ""
var spikes := 0
var walls := 0
var gusts := 0
var hits := 0
var last_wall: FormRaised
var _t := 0.0
var _cast_t := 0.0
var _next := {"spike": 1.0, "wall": 0.0, "gust": 0.0}
var _hits_seen := 0
var _stone: FormStone
var _strafe := 1.0
var _strafe_t := 0.0


func _init(b: NpcBrain) -> void:
	brain = b
	me = b.me


func reset() -> void:
	casting = ""
	_cast_t = 0.0
	_hits_seen = me.hits_taken


func step(dt: float) -> void:
	_t += dt
	var t := brain.target
	if not NpcSenses.can_fight(t):
		return
	var tp := t.global_position
	var d := NpcBrain._flat(me.global_position, tp)
	if casting != "":
		if me.action != "cast":
			_lost()                               # (struck in the wind-up: a flinch took it)
			return
		_casting(dt, t, d)
		return
	if me.busy():
		return
	if d < float(GUST.near_m) and brain.seen_now and _t >= float(_next.gust):
		_begin("gust", t)
	elif me.hits_taken > _hits_seen and _t >= float(_next.wall):
		_hits_seen = me.hits_taken
		_begin("wall", t)
	elif brain.seen_now and d <= float(SPIKE.range_m) and _t >= float(_next.spike):
		_begin("spike", t)
	else:
		_move(dt, t, d)


# ---------------------------------------------------------------- moving between casts
func _move(dt: float, t: Node3D, d: float) -> void:
	var tp := t.global_position
	me.crouch(false)
	if not brain.seen_now or d > KEEP_M.y:
		me.face_lock = Vector3.INF
		var goal := brain.last_seen if brain.last_seen != Vector3.INF else tp
		me.go(goal, NpcFighter.RUN_SPEED, KEEP_M.x)
		return
	var away := me.global_position - tp
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 1e-6 else -me.forward()
	_strafe_t -= dt
	if _strafe_t <= 0.0:
		_strafe = -_strafe if me.rng.randf() < 0.6 else _strafe
		_strafe_t = me.rng.randf_range(STRAFE_S.x, STRAFE_S.y)
	var side := away.cross(Vector3.UP) * _strafe
	var want := side * 3.0
	if d < KEEP_M.x:
		want += away * 3.0
	me.face_lock = tp
	me.go(me.global_position + want, NpcFighter.RUN_SPEED * 0.75, 0.4, true)


# ---------------------------------------------------------------- the casts
func _begin(kind: String, t: Node3D) -> void:
	casting = kind
	_cast_t = 0.0
	me.halt()
	me.face_lock = Vector3.INF
	me.face_point(t.global_position)
	me.action = "cast"
	var wind := float(_d(kind).wind_s)
	if me.body != null:
		var len := me.body.clip_length("cast_push")
		me.body.play_once("cast_push", 0.1, clampf(len / maxf(wind * 1.6, 0.1), 0.6, 2.5) if len > 0.0 else 1.0)
	if kind == "spike":
		# (the stone comes up at once: the wind-up is it rising before the caster, read by the foe)
		var way := _way(t)
		var foot := FormEffects.ground_at(me, me.global_position + way * float(SPIKE.ahead_m))
		var matter := FormMatter.of_ground(me.get_tree(), foot)
		var sd: Dictionary = SwayMoves.move("stone_form").get("spike", {})
		_stone = FormStone.spike(me.get_tree().current_scene, foot, way, sd, me.rng.randi() % 97, matter)
		FormEffects.sfx("rise", foot, -2.0, 0.9)
		GatherFx.stone_chips(me.get_tree().current_scene, foot + Vector3.UP * 0.2, Vector3.UP, 10)


func _casting(dt: float, t: Node3D, _d0: float) -> void:
	_cast_t += dt
	me.face_point(t.global_position)
	if _cast_t < float(_d(casting).wind_s):
		return
	match casting:
		"spike":
			_throw(t)
		"wall":
			_wall(t)
		"gust":
			_gust(t)
	var cd: Variant = _d(casting).cool_s
	_next[casting] = _t + (me.rng.randf_range(float(cd[0]), float(cd[1])) if cd is Array else float(cd))
	casting = ""
	me.action = ""


func _lost() -> void:
	_next[casting] = _t + 0.8
	casting = ""
	_stone = null                                  # (a spike raised and not thrown stands where it rose)


func _throw(t: Node3D) -> void:
	if _stone == null or not is_instance_valid(_stone):
		return
	var from := _stone.global_position + Vector3.UP * _stone.height * 0.5
	var chest := NpcSenses.chest_of(t)
	var tf := from.distance_to(chest) / float(SPIKE.mps)
	var v := NpcSenses.velocity_of(t)
	var aim := chest + Vector3(v.x, 0.0, v.z) * tf * float(me.aim_cfg.get("lead", 0.8))
	aim = me.scatter(from, aim, float(SKILL_DEG.get(me.skill_preset, SKILL_DEG.normal)))
	aim += Vector3.UP * 0.5 * float(SPIKE.gravity) * tf * tf
	var f := Flight.new()
	f.add_to_group(FLIGHT_GROUP)
	f.stone = _stone
	f.velocity = (aim - from).normalized() * float(SPIKE.mps)
	f.gravity = float(SPIKE.gravity)
	f.damage = float(SPIKE.damage)
	f.shooter = me
	f.owner_ex = me.ray_exclude()
	_stone.take()
	_stone.global_position = from
	me.get_tree().current_scene.add_child(f)
	f.hit.connect(func(_who: Node, _dmg: float) -> void: hits += 1)
	FormEffects.sfx("hurl", from, 0.0, 1.0)
	NpcSenses.noise(from, 30.0, me)
	spikes += 1
	_stone = null


func _wall(t: Node3D) -> void:
	var way := _way(t)
	var foot := FormEffects.ground_at(me, me.global_position + way * float(WALL.ahead_m))
	var matter := FormMatter.of_ground(me.get_tree(), foot)
	if matter == "wood":
		matter = "earth"
	var w: Dictionary = (SwayMoves.move("earth_wall") as Dictionary).get("wall", {})
	var wn := FormMatter.numbers(w, FormMatter.entry("earth_wall", matter), matter)
	var across := Vector3.UP.cross(way).normalized()
	var scn := me.get_tree().current_scene
	last_wall = FormRaised.raise(scn, "wall", Transform3D(Basis(across, Vector3.UP, way), foot), wn, absi(hash(foot)) % 97)
	FormHollow.dig(scn, FormEffects.ground_at(me, me.global_position + way * 0.4), way, 3.0, 1.5, 600.0)
	FormEffects.sfx("rise", foot, 0.0, 0.55)
	FormEffects.sfx("rumble", foot, -2.0, 0.7)
	GatherFx.fall_dust(scn, foot, 1.5)
	walls += 1
	var wg := WalkGrid.of(me.get_tree())
	if wg != null:
		wg.dirty(foot, 4.0)


func _gust(t: Node3D) -> void:
	var tp := t.global_position
	if NpcBrain._flat(me.global_position, tp) > float(GUST.reach_m):
		return
	var way := _way(t)
	var push := way * float(GUST.push_mps) + Vector3.UP * float(GUST.up_mps)
	if t is FrontierPlayer:
		var p := t as FrontierPlayer
		if not p.knock_down(push):
			p.velocity += push
	elif t is NpcFighter:
		SwayEffects.shove_fighter(t as NpcFighter, Vector3(push.x, 0.0, push.z), me)
	var scn := me.get_tree().current_scene
	GatherFx._dust(scn, me.global_position + way * 1.5 + Vector3.UP * 1.0, way, 22, Vector2(0.2, 0.6), 1.4, Color(0.85, 0.85, 0.82, 0.35))
	FormEffects.sfx("hurl", me.global_position, 0.0, 1.4)
	gusts += 1


func _way(t: Node3D) -> Vector3:
	var v := t.global_position - me.global_position
	v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-6 else me.forward()


func _d(kind: String) -> Dictionary:
	match kind:
		"spike":
			return SPIKE
		"wall":
			return WALL
	return GUST


## A bent stone in flight (the bender's spike): its point leads (struck as the point reaches a man; a wall met at the point),
## gravity on it; a man met is struck (Hit.deliver, from its bender) and it drops; the world met, it sticks there (its own
## time begins again: FormStone.rest_again).
class Flight:
	extends Node

	signal hit(who: Node, damage: float)

	var stone: FormStone
	var velocity := Vector3.ZERO
	var gravity := 3.0
	var damage := 30.0
	var shooter: Node
	var owner_ex: Array[RID] = []
	var _t := 0.0
	var _q: PhysicsShapeQueryParameters3D

	func _physics_process(dt: float) -> void:
		if stone == null or not is_instance_valid(stone):
			queue_free()
			return
		_t += dt
		velocity.y -= gravity * dt
		var dir := velocity.normalized()
		var lead := dir * stone.height * 0.85
		var from := stone.global_position
		var to := from + velocity * dt
		if _q == null:
			_q = PhysicsShapeQueryParameters3D.new()
			var sph := SphereShape3D.new()
			sph.radius = stone.radius * 0.7
			_q.shape = sph
			var ex: Array[RID] = owner_ex.duplicate()
			ex.append(stone.get_rid())
			_q.exclude = ex
		_q.transform = Transform3D(Basis.IDENTITY, from + lead)
		_q.motion = to - from
		var space := stone.get_world_3d().direct_space_state
		var frac := space.cast_motion(_q)
		if frac.size() == 2 and frac[1] < 1.0:
			var at := from + lead + (to - from) * frac[1]
			_q.transform = Transform3D(Basis.IDENTITY, at)
			_q.motion = Vector3.ZERO
			var info := space.get_rest_info(_q)
			var col := instance_from_id(int(info.get("collider_id", 0))) as Node if not info.is_empty() else null
			var who := FormSpikes.taker(col, null) if col != null else null
			if who != null:
				# (a stone's blow is blunt force: all of it now, no wound to bleed: PlayerWounds.kind_of reads the striker's meta)
				var had: Variant = shooter.get_meta(&"damage_kind") if shooter != null and shooter.has_meta(&"damage_kind") else null
				if shooter != null:
					shooter.set_meta(&"damage_kind", "blunt")
				Hit.deliver(col, damage, at, dir, shooter)
				if shooter != null and is_instance_valid(shooter):
					if had == null:
						shooter.remove_meta(&"damage_kind")
					else:
						shooter.set_meta(&"damage_kind", had)
				hit.emit(who, damage)
			_place(from + (to - from) * frac[0], dir)
			if who is CharacterBody3D:
				# (a man struck: it drops by him)
				stone.freeze = false
				stone.sleeping = false
				stone.linear_velocity = velocity * 0.15
			stone.rest_again()
			queue_free()
			return
		_place(to, dir)
		if _t > 4.0:
			stone.freeze = false
			stone.rest_again()
			queue_free()

	func _place(p: Vector3, dir: Vector3) -> void:
		var b := Basis(Quaternion(Vector3.UP, dir)) if dir.length_squared() > 1e-6 else Basis.IDENTITY
		stone.global_transform = Transform3D(b, p)
