class_name MarchStage
extends Node
## The March, staged (docs/main_story.md 10.1, mission 10: "12 Nov, by day, up the east bank. Gear stripped, hands bound, the
## cold. Toussaint Leclerc, the Canadian who spared you, shares a crust. Jost is beside you if he was taken. From the raiders'
## camp you see the fort across the river and the smoke of the farms"; 15 item 1: "the march behind a scripted Leclerc with
## two guards ... sight cones, no brain"). It ends at the raiders' camp at night, by a campfire: mission 11 begins there.
##
##   var march := MarchStage.begin(level, route, {"leclerc": raid.leclerc, "guards": raid.guards()})
##   march.arrived.connect(...)        at the camp: the fire lit, the guards at their posts
##   march.guard_sees_player()         a guard has him in its cone now (the escape's stealth)
##   MarchStage.east_bank(from, to)    a route up the east bank (points kept east of the river)
##
## THE COLUMN: Leclerc (a StoryActor, Canadian militia; opts leclerc, else one made at the player's side) is the captor:
## Captivity's forced march along the route (Captivity.march: the player keeps up within its leash, or Leclerc waits and
## turns back; the survival clock moves on with the metres, opts march_hours, by default the hours to arrive_hour, 19:00,
## the night; hunger_mult short rations). Already captive (RaidStage), the captivity goes on with Leclerc; not yet, it begins
## here (opts captivity). Leclerc and the guards handed on from RaidStage are reparented here (the raid's stage may go
## after); begun while its torch is still on the way to the house (RaidStage phase "torch"), the column waits for it (phase
## "wait") and sets off at house_alight: `set_off`.
## THE GUARDS: two (opts guards, else two marines made), scripted, with sight cones and no brain (StoryActor watch): one
## walks behind the player, one at his side on the river's side, keeping their places. The player falling behind or straying
## (the leash "waiting", "turning_back") where a guard sees him, the guard shouts at him (BARK_S apart). Once he is loose (the
## leash broken, or no captivity) a guard that sees him is alerted (StoryActor.alert: StoryObjectives.seen_by finds it, a
## stay_unseen fails) and `seen` is sent.
## JOST: beside the player (a StoryWalker at a child's size, tag "jost") when the story says he was taken (the flag
## JOST_FLAG, or opts jost).
## THE CRUST: at crust_at of the way (0.5; -1 none) Leclerc gives him one (crust_item, "item.food.biscuit": into the survival
## kit) and says CRUST_LINE: `crust_shared`.
## THE CAMP (the route's last point, or opts camp): a campfire lit there (Campfire: its warmth, its light, wolves keep off;
## at opts fire_at when given: where it was before a load), Leclerc by it, one guard sat at it, the other standing watch
## facing out; Jost sat by the player; the night (the sky clock set to arrive_hour when there is no survival core to move
## it): `arrived`. look_at_point(p): the guards stop watching and they and Leclerc stand looking at p (the second fire come
## down), and keep to it whatever the camp's placing would have them do (Leclerc's captive_wait too: StoryActor.look_over);
## a point high in the sky (the ships fighting) has their eyes up on it: the guards' muskets levelled at it, Leclerc
## craning (StoryActor.gaze), Jost on his feet. cry(beat): the camp's shouts at the sky battle's beats (CRIES: the guns
## heard, the sky struck, the cutter hit), each said aloud by its man (StoryBark), a moment apart. scatter(at): the cutter
## down, the guards break for the pines toward it at a run (SCATTER_M out, then stand staring), shouting, Leclerc shouting
## after them to stop: what camp_scatters tells.
## Not saved (as RaidStage). Freeing it frees the people it made or was handed and the fire.

## The column set off (at once, or once the raid's torch was put to the house).
signal set_off
signal arrived
signal crust_shared
## A guard has seen the player loose (alert).
signal seen(guard: StoryActor)

const GROUP := &"march_stage"
const JOST_FLAG := "tf.jost_taken"
const ARRIVE_HOUR := 19.0
const HUNGER_MULT := 1.5
const CRUST_ITEM := "item.food.biscuit"
const CRUST_LINE := "Tiens. Mange."
const SHOUTS := ["Avance!", "Allez, marche!", "Plus vite!"]
const BARK_S := 6.0
## The guards' places on the march (the player's frame: x right, z behind) and how often they are given again.
const REAR_SLOT := Vector3(0.6, 0.0, 4.5)
const SIDE_M := 5.0
const SLOT_S := 0.35
## Jost's place by the player (his left, a little behind).
const JOST_SLOT := Vector3(-1.1, 0.0, 0.6)
## At the camp: the fire this far ahead of where Leclerc stops; the watch this far out from it.
const FIRE_AHEAD_M := 2.5
const WATCH_OUT_M := 7.0
## A point this high over the camp is in the sky: eyes up on it (the muskets levelled, the chest turned up).
const SKY_UP_M := 25.0
## The camp's shouts at the sky battle's beats: [who ("guard" and its index, or "leclerc", "jost"), the line], said
## CRY_GAP_S apart in order. "down": the cutter come down in the pines (scatter).
const CRIES := {
	"fire": [["guard", 0, "Là-haut ! Regardez, là-haut !"], ["guard", 1, "Des vaisseaux... dans le ciel ?"]],
	"sky": [["guard", 1, "Le ciel ! Le ciel se fend !"], ["leclerc", 0, "Sainte Vierge..."], ["jost", 0, "Mutter..."]],
	"hit": [["guard", 0, "Il brûle ! Il tombe !"]],
	"down": [["guard", 0, "Aux pins ! Il est tombé dans le bois !"], ["guard", 1, "Allez, allez !"],
			["leclerc", 0, "Restez ici ! Arrêtez !"]],
}
const CRY_GAP_S := 1.1
const CRY_S := 3.0
## The cutter down: the guards run this far (m) toward it from the camp, a little apart, and stand there staring.
const SCATTER_M := 45.0
## The dash there: straight over the open ground, a leg this long ahead at a time (within NpcFighter.STRAIGHT_M: no walk
## grid plan round the camp's fire), turned aside by the fighter's own probe.
const DASH_LEG_M := 8.0

var level: Node
var player: FrontierPlayer
var captivity: Captivity
var leclerc: StoryActor
var guards: Array[StoryActor] = []
var jost: StoryWalker
var route: Array[Vector3] = []
var camp := Vector3.ZERO
var camp_fire: Campfire
## "wait" (the raid's torch still at the house), "march", "camp".
var phase := ""
var opts := {}
var crust_given := false
## Where the camp looks (look_at_point; INF: nowhere in particular).
var look_to := Vector3.INF
## The guards running for the pines (scatter): guard -> [where it runs to, seconds it has left to get there].
var running := {}

var _slot_t := 0.0
var _bark_t := 0.0
var _route_m := 0.0
var _last_heading := Vector3.FORWARD


## The march begun under `level` along `route` (Vector3s, or [x, z]). opts: leclerc (a StoryActor), guards (StoryActors),
## jost (bool, over the story's flag), camp (Vector3), march_hours, arrive_hour (19), hunger_mult, captivity (Captivity.begin's
## opts when the player is not captive yet), crust_at (0.5), crust_item.
static func begin(p_level: Node, p_route: Array, p_opts := {}) -> MarchStage:
	var s := MarchStage.new()
	s.name = "MarchStage"
	p_level.add_child(s)
	s.start(p_route, p_opts)
	return s


static func find(tree: SceneTree) -> MarchStage:
	return tree.get_first_node_in_group(GROUP) as MarchStage if tree else null


## Points up the east bank from `from` to `to` every `step_m`, each kept at least `bank_m` east of the river's middle (the
## farms' side, where the raiders marched: docs 10.1).
static func east_bank(from: Vector3, to: Vector3, step_m := 40.0, bank_m := 45.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := maxi(int(ceil(Vector2(to.x - from.x, to.z - from.z).length() / maxf(step_m, 1.0))), 1)
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / float(n))
		if WorldRiver.has_water():
			p.x = maxf(p.x, WorldRiver.x_at(p.z) + bank_m)
		out.append(Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z))
	return out


func _ready() -> void:
	add_to_group(GROUP)


func start(p_route: Array, p_opts := {}) -> void:
	opts = p_opts
	level = get_parent()
	var tree := get_tree()
	player = StoryObjectives.player(tree)
	route.clear()
	for v: Variant in p_route:
		var q: Variant = v
		if v is Array and (v as Array).size() >= 2:
			q = Vector3(float(v[0]), 0.0, float(v[1]))
		if q is Vector3:
			route.append(_ground(q))
	var c: Variant = opts.get("camp")
	camp = _ground(c) if c is Vector3 else (route.back() if not route.is_empty() else (player.global_position if player else Vector3.ZERO))
	if player == null:
		push_warning("MarchStage: no player")
		return
	# Leclerc: handed on (reparented here, so the stage he came from may go), or made at the player's side
	var l: Variant = opts.get("leclerc")
	if l is StoryActor and is_instance_valid(l):
		leclerc = l
		_take_in(leclerc)
	else:
		leclerc = StoryActor.make(self, "canadian_militia", player.global_position + _right_of_player() * 2.0,
				{"name": RaidStage.LECLERC, "tag": "leclerc", "face": player.global_position, "seed": 1757})
	for g: Variant in opts.get("guards", []):
		if g is StoryActor and is_instance_valid(g) and guards.size() < 2:
			guards.append(g)
			_take_in(g)
	while guards.size() < 2:
		var at := player.global_position - _right_of_player() * (2.0 + float(guards.size()) * 2.0)
		guards.append(StoryActor.make(self, "french_marine", at, {"tag": "march_guard", "face": player.global_position,
				"seed": 1760 + guards.size(), "node_name": "guard_%d" % guards.size()}))
	for g in guards:
		g.tag = "march_guard"
		g.watch = true
		g.calm()
	# Jost, if he was taken
	var want_jost: Variant = opts.get("jost")
	if want_jost == null:
		var d := StoryDirector.find(tree)
		want_jost = StoryObjectives.truthy(d.flag(JOST_FLAG)) if d != null else false
	if bool(want_jost):
		jost = StoryWalker.make(self, player.global_position + _right_of_player() * -1.2, StoryWalker.person_look("palatine_m_b", "jost", true),
				{"tag": "jost", "name": "Jost Rauch", "size": 0.7, "group": [&"story_people", WildlifeSpawner.PEOPLE],
				"face": player.global_position})
		jost.follow(player, JOST_SLOT)
	captivity = Captivity.install(level)
	# the column sets off once the raid's torch has been put to the house (RaidStage still at it), else now
	var raid := RaidStage.find(tree)
	if raid != null and raid.phase == "torch":
		phase = "wait"
		raid.house_alight.connect(func(_n: int) -> void: _set_off(), CONNECT_ONE_SHOT)
	else:
		_set_off()


## The captivity on with Leclerc (or begun here) and the forced march along the route.
func _set_off() -> void:
	if not is_inside_tree() or player == null or not is_instance_valid(player):
		return
	if leclerc == null or not is_instance_valid(leclerc):
		return
	_route_m = _route_length()
	captivity = Captivity.install(level)
	var hours := float(opts.get("march_hours", _hours_to(float(opts.get("arrive_hour", ARRIVE_HOUR)))))
	var mopts := {"march_hours": hours, "hunger_mult": float(opts.get("hunger_mult", HUNGER_MULT))}
	if not captivity.is_active():
		var co: Dictionary = (opts.get("captivity", {}) as Dictionary).duplicate()
		co.merge(mopts)
		co["route"] = route
		captivity.begin(player, leclerc, co)
	else:
		captivity.follow(leclerc)
		if not route.is_empty():
			captivity.march(route, mopts)
	if not captivity.march_done.is_connected(_on_march_done):
		captivity.march_done.connect(_on_march_done)
	phase = "march"
	set_off.emit()
	if route.is_empty() or not captivity.marching:
		_on_march_done()


## The guards stop watching the captives; they and Leclerc stand looking at `at`, and keep to it (the camp's placing, its
## seating, leaves them so).
func look_at_point(at: Vector3) -> void:
	look_to = at
	_look()


func _look() -> void:
	if look_to == Vector3.INF:
		return
	var up := look_to.y > camp.y + SKY_UP_M
	for g in guards:
		if is_instance_valid(g) and g.scripted:
			g.watch = false
			if running.has(g):
				continue                                  # (running for the pines: it stands there once it is)
			g.stand(look_to)
			g.gaze(look_to if up else Vector3.INF, true)
	if leclerc != null and is_instance_valid(leclerc) and leclerc.scripted:
		leclerc.look_over = look_to
		leclerc.stand(look_to)
		leclerc.gaze(look_to if up else Vector3.INF, false)
	if up and jost != null and is_instance_valid(jost):
		if jost.is_crouching:
			jost.crouch(false)
		jost.stop(look_to)


## The camp's shouts at a beat of the sky battle (CRIES[beat]): each line over its man, CRY_GAP_S apart.
func cry(beat: String) -> void:
	var lines: Array = CRIES.get(beat, [])
	for i in lines.size():
		var e: Array = lines[i]
		var who: Node3D = null
		match String(e[0]):
			"guard":
				var gi := int(e[1])
				who = guards[gi] if gi < guards.size() and is_instance_valid(guards[gi]) else null
			"leclerc":
				who = leclerc if leclerc != null and is_instance_valid(leclerc) else null
			"jost":
				who = jost if jost != null and is_instance_valid(jost) else null
		if who == null:
			continue
		if i == 0:
			StoryBark.say(who, String(e[2]), CRY_S)
		else:
			get_tree().create_timer(CRY_GAP_S * i, false).timeout.connect(_cry_later.bind(who.get_instance_id(), String(e[2])))


## A cry a moment later, over its man if he is still there (by his id: a load may have freed him meanwhile).
static func _cry_later(who_id: int, line: String) -> void:
	var who := instance_from_id(who_id) as Node3D
	if who != null and who.is_inside_tree():
		StoryBark.say(who, line, CRY_S)


## The cutter down at `at`: the camp's eyes on it, the guards breaking for the pines toward it at a run (SCATTER_M out
## from the camp, a little apart), shouting; Leclerc shouting after them, staying by his captive.
func scatter(at: Vector3) -> void:
	look_at_point(at)
	var to := Vector3(at.x - camp.x, 0.0, at.z - camp.z)
	var d := to.length()
	if d < 1.0:
		cry("down")
		return
	to /= d
	var side := to.cross(Vector3.UP)
	for i in guards.size():
		var g := guards[i]
		if not is_instance_valid(g) or not g.scripted or g.alerted:
			continue
		var p := camp + to * minf(SCATTER_M + 8.0 * i, d - 20.0) + side * (6.0 * (i - 0.5))
		running[g] = [_ground(p), SCATTER_M / NpcFighter.RUN_SPEED + 8.0]
		g.gaze(Vector3.INF)
		g.crouch(false)
		_dash(g, _ground(p))
	cry("down")


## A guard's dash toward `to`: the next DASH_LEG_M of the straight line there, at a run.
func _dash(a: StoryActor, to: Vector3) -> void:
	var flat := Vector3(to.x - a.global_position.x, 0.0, to.z - a.global_position.z)
	var d := flat.length()
	if d < 0.1:
		return
	var leg := a.global_position + flat / d * minf(d, DASH_LEG_M)
	a.walk_to(_ground(leg), NpcFighter.RUN_SPEED, 1.5 if d <= DASH_LEG_M else 0.3, true)


## Whether a guard has the player in its cone now.
func guard_sees_player() -> bool:
	for g in guards:
		if is_instance_valid(g) and g.sees_player():
			return true
	return false


## Everyone it walks: Leclerc, the guards, Jost.
func people() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if leclerc != null and is_instance_valid(leclerc):
		out.append(leclerc)
	for g in guards:
		if is_instance_valid(g):
			out.append(g)
	if jost != null and is_instance_valid(jost):
		out.append(jost)
	return out


func _take_in(n: Node) -> void:
	if n.get_parent() == self:
		return
	var st := RaidStage.find(get_tree())
	if st != null and (n.get_parent() == st):
		st.handed_on()
	n.reparent(self, true)


# ---------------------------------------------------------------- the march
func _process(dt: float) -> void:
	if phase == "" or player == null or not is_instance_valid(player):
		return
	_bark_t = maxf(_bark_t - dt, 0.0)
	for g: Variant in running.keys():
		var a := g as StoryActor
		if a == null or not is_instance_valid(a):
			running.erase(g)
			continue
		var r: Array = running[g]
		r[1] = float(r[1]) - dt
		var to: Vector3 = r[0]
		if Vector2(a.global_position.x - to.x, a.global_position.z - to.z).length() < 2.5 or float(r[1]) <= 0.0:
			running.erase(g)                              # (there, or as far as it got: it stands staring at the fire)
			a.stand(look_to)
		else:
			_dash(a, to)
	var loose := captivity == null or not captivity.is_active() or captivity.has_escaped
	if phase == "march":
		_slot_t -= dt
		if _slot_t <= 0.0:
			_slot_t = SLOT_S
			_place_guards()
		_crust()
	for g in guards:
		if not is_instance_valid(g) or not g.scripted:
			continue
		if not g.sees_player():
			continue
		if loose:
			if not g.alerted:
				g.alert(player)
				seen.emit(g)
		elif captivity.leash in ["waiting", "turning_back"] and _bark_t <= 0.0:
			_bark_t = BARK_S
			g.face_point(player.global_position)
			StoryBark.say(g, String(SHOUTS[randi() % SHOUTS.size()]), 2.5)


## The guards' places: one behind the player, one at his river side, along the way the column goes.
func _place_guards() -> void:
	var heading := leclerc.global_position - player.global_position if leclerc != null and is_instance_valid(leclerc) else _last_heading
	heading.y = 0.0
	if heading.length() > 0.5:
		_last_heading = heading.normalized()
	var fwd := _last_heading
	var right := fwd.cross(Vector3.UP).normalized()
	var p := player.global_position
	var slots := [p - fwd * REAR_SLOT.z + right * REAR_SLOT.x, p + right * SIDE_M * _river_side_sign(right) - fwd * 0.5]
	for i in mini(guards.size(), 2):
		var g := guards[i]
		if not is_instance_valid(g) or not g.scripted or g.alerted or look_to != Vector3.INF:
			continue
		var to: Vector3 = _ground(slots[i])
		var d := Vector2(to.x - g.global_position.x, to.z - g.global_position.z).length()
		var pace := NpcFighter.WALK_SPEED if d < 4.0 else (StoryActor.JOG if d < 12.0 else NpcFighter.RUN_SPEED)
		if d < 0.8:
			g.stand(g.global_position + fwd * 4.0)
		else:
			g.walk_to(to, pace, 0.6)


## +1 when `right` points to the river, else -1.
func _river_side_sign(right: Vector3) -> float:
	if not WorldRiver.has_water():
		return 1.0
	var x := WorldRiver.x_at(player.global_position.z)
	return 1.0 if signf(x - player.global_position.x) == signf(right.x) else -1.0


func _crust() -> void:
	var at := float(opts.get("crust_at", 0.5))
	if crust_given or at < 0.0 or captivity == null or _route_m <= 0.0:
		return
	if captivity.march_m / _route_m < at:
		return
	crust_given = true
	StoryBark.say(leclerc, CRUST_LINE, 3.5)
	leclerc.last_bark = CRUST_LINE
	StoryEffects.give(get_tree(), String(opts.get("crust_item", CRUST_ITEM)), 1)
	crust_shared.emit()


# ---------------------------------------------------------------- the camp
func _on_march_done() -> void:
	if phase == "camp":
		return
	phase = "camp"
	var stop := leclerc.global_position if leclerc != null and is_instance_valid(leclerc) else camp
	var dir := _last_heading
	var fire_at := _ground(opts.fire_at) if opts.get("fire_at") is Vector3 else _ground(stop + dir * FIRE_AHEAD_M)
	camp_fire = Campfire.new()
	camp_fire.name = "RaidersCampfire"
	add_child(camp_fire)
	camp_fire.global_position = fire_at
	camp_fire.light()
	var right := dir.cross(Vector3.UP).normalized()
	if leclerc != null and is_instance_valid(leclerc):
		leclerc.stand(fire_at)
	if guards.size() >= 1 and is_instance_valid(guards[0]):
		var g0 := guards[0]
		g0.walk_to(_ground(fire_at + right * 1.8), NpcFighter.WALK_SPEED, 0.5)
		g0.set_meta(&"sit_at", fire_at)
	if guards.size() >= 2 and is_instance_valid(guards[1]):
		var g1 := guards[1]
		var out := _ground(fire_at + dir * WATCH_OUT_M)
		g1.walk_to(out, NpcFighter.WALK_SPEED, 0.5)
		g1.set_meta(&"watch_from", fire_at)
	if jost != null and is_instance_valid(jost):
		jost.follow(player, JOST_SLOT)
	_look()
	_seat.call_deferred()
	# the night: the sky clock set when there is no survival core to have moved it with the march
	var core := StoryObjectives._core(get_tree())
	if core == null:
		var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig
		if rig != null and rig.clock_driver != null and rig.clock_driver.clock != null:
			rig.clock_driver.clock.set_time(float(opts.get("arrive_hour", ARRIVE_HOUR)))
	arrived.emit()


## A few seconds on (the guards at their posts): the one by the fire sits, the watch faces out from it, Jost sits.
func _seat() -> void:
	await get_tree().create_timer(4.0, false).timeout
	if not is_inside_tree() or phase != "camp":
		return
	for g in guards:
		if not is_instance_valid(g) or not g.scripted or g.alerted:
			continue
		if g.has_meta(&"sit_at"):
			g.stand(g.get_meta(&"sit_at"))
			g.crouch(true)
		elif g.has_meta(&"watch_from"):
			var from: Vector3 = g.get_meta(&"watch_from")
			g.stand(g.global_position + (g.global_position - from).normalized() * 5.0)
	if jost != null and is_instance_valid(jost) and camp_fire != null:
		jost.stop(camp_fire.global_position)
		jost.crouch(true)
	if look_to != Vector3.INF:
		for g in guards:
			if is_instance_valid(g) and g.scripted and not g.alerted:
				g.crouch(false)
		_look()


# ---------------------------------------------------------------- helpers
func _route_length() -> float:
	if route.is_empty():
		return 0.0
	var from := leclerc.global_position if leclerc != null else player.global_position
	var m := Vector2(route[0].x - from.x, route[0].z - from.z).length()
	for i in range(1, route.size()):
		m += Vector2(route[i].x - route[i - 1].x, route[i].z - route[i - 1].z).length()
	return m


## Game hours from now to `h` o'clock (at least half an hour).
func _hours_to(h: float) -> float:
	var core := StoryObjectives._core(get_tree())
	var now := -1.0
	if core != null:
		now = SurvivalClock.hour(core)
	else:
		var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig if level else null
		if rig != null and rig.clock_driver != null and rig.clock_driver.clock != null:
			now = rig.clock_driver.clock.hour
	if now < 0.0:
		return 6.0
	return maxf(fposmod(h - now, 24.0), 0.5)


func _right_of_player() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var f := -cam.global_basis.z if cam != null else -player.global_basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	return f.cross(Vector3.UP).normalized()


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)
