class_name NpcSquad
extends Node
## A band of fighters of one faction (NpcFighter): spawned together at a place in a line abreast, given one order, counted.
##   var s := NpcSquad.spawn(level, "french_marine", 6, at, {"tag": "raid", "attack": "player"})
##   s.attack(player)          after a foe (a Node3D: the player, a fighter), or s.attack(point): to a place, and hold it
##   s.patrol(points)          walk the points round and round (each man his own place in the line)
##   s.hold(at)
##   s.alive_count()           still alive;  s.fighting_count(): alive and still in the fight (not run off, not surrendered)
## Its fighters are its children (freeing the squad frees them: a story's retry). Group SQUADS ("npc_squads", with `tag` and
## `waves_left`: StoryObjectives' defend reads them): with waves left, a squad all down or out of the fight sends another
## wave of the same size from where it first came after WAVE_S, under the same order.
## StoryEffects' spawn_squad calls spawn() by name: parent (the level), faction, count, at and opts are its fields.
## opts: tag, attack ("player", a [x, z] / Vector3 place, or a Node3D), patrol (points), hold (a place), face (a point
## to face), weapon / sidearm (over the faction's), tactics ("line", "cover": NpcFighter.tactics), skill (an aim preset: "easy",
## "normal", "hard", NpcFighter.SKILLS), waves, wave_s, spacing, seed; faction (or squad, its older name) when
## the `faction` given is none of data/npc/factions.json's (an unknown one is warned of: its men would have no foes);
## element ("earth", "water", "fire", "air": with tactics "bend", element bots: NpcBending of that element, their water
## Bending.of(it), no weapon unless named, never running from the fight; a faction with element_dress (Tidebreak's ring sides,
## ring_team_a / ring_team_b) dresses them in the element's colours); y (a height: each man stood at it as given, not on the
## ground found under him: a raised deck the walk grid knows nothing of).
## A WAVE COMES IN OVER FRAMES (a man is ~10 ms to build: seven at once was a hitch in the middle of a fight): its first man at
## once (spawn() hands back a squad with someone in it), then one each frame (spawning()); each takes the squad's order as he
## comes. alive_count() and fighting_count() count the men still to come.
## Its own frame looks at the squad every LOOK_S (not each frame); a squad whose men are all gone (freed) with no waves left
## frees itself.

signal member_died(fighter: NpcFighter, killer: Node)
signal wiped(squad: NpcSquad)

const GROUP := &"npc_squads"
const SPACING := 2.5
const WAVE_S := 20.0
const LOOK_S := 0.25

var faction := "militia"
var tag := ""
var members: Array[NpcFighter] = []
## Spawned in all, and in the wave now.
var spawned := 0
var wave_count := 0
var waves_left := 0
var wave_size := 0
var wave_s := WAVE_S
var origin := Vector3.ZERO
var facing := Vector3.INF
var spacing := SPACING
var weapon := "default"
var sidearm := "default"
## How its men fight and the skill they aim with (NpcFighter.tactics, skill_preset; "" the fighter's own).
var tactics := ""
var skill_preset := ""
## Its men's element ("" none: NpcFighter.element) and the height they are stood at (INF: the ground under each).
var element := ""
var place_y := INF
var _order_kind := ""
var _order: Variant = null
var _rng := RandomNumberGenerator.new()
var _wave_t := -1.0
var _wiped := false
## The wave's men still to come (their slots), and the look's clock.
var _queue: Array[int] = []
var _fwd := Vector3.FORWARD
var _look_t := 0.0


static func spawn(parent: Node, faction := "militia", count := 4, at := Vector3.ZERO, opts := {}) -> NpcSquad:
	var s := NpcSquad.new()
	if NpcFactions.get_faction(faction).is_empty():
		var named := String(opts.get("faction", opts.get("squad", "")))
		if not NpcFactions.get_faction(named).is_empty():
			faction = named
		else:
			push_warning("NpcSquad: no faction %s in %s (its men have no foes and the default numbers)" % [faction, NpcFactions.PATH])
	s.faction = faction
	s.tag = String(opts.get("tag", ""))
	s.origin = at
	s.wave_size = maxi(count, 1)
	s.waves_left = int(opts.get("waves", 0))
	s.wave_s = float(opts.get("wave_s", WAVE_S))
	s.spacing = float(opts.get("spacing", SPACING))
	s.weapon = String(opts.get("weapon", "default"))
	s.sidearm = String(opts.get("sidearm", "default"))
	s.tactics = String(opts.get("tactics", ""))
	s.skill_preset = String(opts.get("skill", ""))
	s.element = String(opts.get("element", ""))
	if not s.element in Bending.ELEMENTS:
		s.element = ""
	if s.element != "":
		if s.tactics == "":
			s.tactics = "bend"
		if not opts.has("weapon"):
			s.weapon = ""
		if not opts.has("sidearm"):
			s.sidearm = ""
	if opts.get("y") is float or opts.get("y") is int:
		s.place_y = float(opts.y)
	var sd := int(opts.get("seed", 0))
	if sd != 0:
		s._rng.seed = sd
	else:
		s._rng.randomize()
	var face: Variant = _point(opts.get("face"), parent)
	var att: Variant = opts.get("attack")
	if face == null and att != null:
		face = _point(att, parent)
		if face == null:
			var tn := _target(att, parent)
			if tn != null:
				face = tn.global_position
	s.facing = face if face is Vector3 else Vector3.INF
	s.name = "Squad_%s_%d" % [faction, s.get_instance_id() % 100000]
	parent.add_child(s)
	s._spawn_wave()
	if att != null:
		var t: Node3D = _target(att, parent)
		if t != null:
			s.attack(t)
		elif _point(att, parent) is Vector3:
			s.attack(_point(att, parent))
	elif opts.get("patrol") is Array:
		var pts := PackedVector3Array()
		for p: Variant in opts.patrol:
			var v: Variant = _point(p, parent)
			if v is Vector3:
				pts.append(v)
		s.patrol(pts)
	elif opts.has("hold"):
		var h: Variant = _point(opts.hold, parent)
		if h is Vector3:
			s.hold(h)
	return s


func _ready() -> void:
	add_to_group(GROUP)


## A place from data: a Vector3, [x, z] (on the ground) or [x, y, z]; null otherwise.
static func _point(v: Variant, _parent: Node) -> Variant:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() >= 2:
		var a: Array = v
		if a.size() >= 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
		return Vector3(float(a[0]), FrontierTerrain.height_at(float(a[0]), float(a[1])), float(a[1]))
	return null


## A foe named in data: "player" (the level's player), or a Node3D as it is; null otherwise.
static func _target(v: Variant, parent: Node) -> Node3D:
	if v is String and String(v) == "player":
		var scene := parent.get_tree().current_scene if parent.is_inside_tree() else null
		return scene.get_node_or_null("Player") as Node3D if scene else null
	if typeof(v) == TYPE_OBJECT and is_instance_valid(v) and v is Node3D:
		return v
	return null


## One wave of wave_size fighters in a line abreast across the way they face (two ranks past six): the first now, the rest one
## each frame (_process).
func _spawn_wave() -> void:
	wave_count = wave_size
	_wiped = false
	_fwd = Vector3.FORWARD
	if facing != Vector3.INF:
		var d := facing - origin
		d.y = 0.0
		if d.length() > 0.1:
			_fwd = d.normalized()
	_queue.clear()
	for i in wave_size:
		_queue.append(i)
	_spawn_next()


## Whether men of the wave are still to come.
func spawning() -> bool:
	return not _queue.is_empty()


## The next man of the wave at his place in the line, under the squad's order.
func _spawn_next() -> void:
	if _queue.is_empty() or not is_inside_tree():
		return
	var i: int = _queue.pop_front()
	var right := _fwd.cross(Vector3.UP).normalized()
	var per_rank := 6
	var rank := floori(float(i) / per_rank)
	var in_rank := mini(wave_size - rank * per_rank, per_rank)
	var slot := float(i % per_rank) - float(in_rank - 1) * 0.5
	var off := right * slot * spacing - _fwd * float(rank) * spacing
	var f := NpcFighter.new()
	f.name = "%s_%d" % [faction, spawned]
	f.faction = faction
	f.tag = tag
	f.weapon = weapon
	f.sidearm = sidearm
	if tactics != "":
		f.tactics = tactics
	f.skill_preset = skill_preset
	f.squad = self
	f.rng_seed = _rng.randi() | 1
	if element != "":
		# (an element bot: its element, its own water, the player's whole hurt, in the fight to its end; its side's dress in
		# the element's colours: element_look)
		f.element = element
		f.flees = false
		f.calm_s = INF
		f.hurt_mult = 1.0
		var lk := element_look(faction, element, _rng)
		if not lk.is_empty():
			f.look = lk
	var at := origin + off
	f.home = Vector3(at.x, place_y, at.z) if place_y != INF else _ground(at)
	# (placed before it enters the tree: the squad is a plain Node, so its position is its place in the world)
	f.position = f.home + Vector3.UP * 0.1
	f.rotation.y = atan2(-_fwd.x, -_fwd.z)
	f.set_meta(&"slot", off)
	add_child(f)
	f.died.connect(_on_died)
	members.append(f)
	spawned += 1
	_order_one(f)


## A look for a fighter of `faction` in `element`'s colours: one of the faction's presets in its dress (NpcFactions.look_for),
## the dress coloured by the faction's element_dress[element] (slot -> its colours: a plain athletic dress of the basic garments,
## the shirt in the element's colour; Tidebreak's sides), or slot -> {id, colors}: that garment worn there instead ("-": the
## slot taken off; the ring dress, set "ring" of the catalog). {} when the faction has none for it (its own look stands).
## Round 4 (HUD; the owner: "side colours in mirror matches"): a ring side wearing away (RingSides.away: team 1 in an element team
## 0 also wears) takes RingSides' away dress (the same garments, sides.json's colours); every other look is exactly as before.
static func element_look(faction: String, element: String, rng: RandomNumberGenerator) -> Dictionary:
	var dress: Variant = (NpcFactions.get_faction(faction).get("element_dress", {}) as Dictionary).get(element)
	var away := RingSides.away_dress_for(faction, element)
	if not away.is_empty():
		dress = away
	if not (dress is Dictionary) or (dress as Dictionary).is_empty():
		return {}
	var look := NpcFactions.look_for(faction, rng)
	var outfit: Dictionary = look.get("outfit", {})
	for slot: String in dress:
		var d: Variant = (dress as Dictionary)[slot]
		if d is Dictionary and (d as Dictionary).has("id"):
			# (a garment of its own: the ring dress, {id, colors}; "-" takes the slot off)
			outfit[slot] = {"id": String((d as Dictionary).id), "colors": ((d as Dictionary).get("colors", {}) as Dictionary).duplicate()}
			continue
		var e: Variant = outfit.get(slot)
		if e is Dictionary:
			(e as Dictionary)["colors"] = ((dress as Dictionary)[slot] as Dictionary).duplicate()
	look["outfit"] = outfit
	return look


## The ground at `p` (the first solid thing under it, else the terrain).
func _ground(p: Vector3) -> Vector3:
	var h := FrontierTerrain.height_at(p.x, p.z)
	var tree := get_tree()
	var scene := tree.current_scene if tree else null
	if scene is Node3D:
		var space := (scene as Node3D).get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, h + 3.0, p.z), Vector3(p.x, h - 3.0, p.z), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and not (hit.collider is CharacterBody3D):
			return hit.position
	return Vector3(p.x, h, p.z)


## After `t`: a foe (Node3D) every man goes for, or a place (Vector3) each goes to at his place in the line, and holds.
func attack(t: Variant) -> void:
	_order_kind = "attack"
	_order = t
	for f in fighters():
		_order_one(f)


func patrol(points: PackedVector3Array) -> void:
	_order_kind = "patrol"
	_order = points
	for f in fighters():
		_order_one(f)


func hold(at: Vector3) -> void:
	_order_kind = "hold"
	_order = at
	for f in fighters():
		_order_one(f)


## The squad's order given to `f` at his place in the line (his slot).
func _order_one(f: NpcFighter) -> void:
	var off: Vector3 = f.get_meta(&"slot", Vector3.ZERO)
	match _order_kind:
		"attack":
			if _order is Vector3:
				f.order_attack((_order as Vector3) + off)
			else:
				f.order_attack(_order)
		"patrol":
			var own := PackedVector3Array()
			for p: Vector3 in (_order as PackedVector3Array):
				own.append(p + off)
			f.order_patrol(own)
		"hold":
			f.order_hold((_order as Vector3) + off)


## Its fighters still in the world (alive or dead).
func fighters() -> Array[NpcFighter]:
	var out: Array[NpcFighter] = []
	for f in members:
		if is_instance_valid(f):
			out.append(f)
	return out


## Still alive (the men of the wave still to come too).
func alive_count() -> int:
	var n := _queue.size()
	for f in fighters():
		if not f.is_dead():
			n += 1
	return n


## Alive and still in the fight (not run off, not on its knees; the men still to come too).
func fighting_count() -> int:
	var n := _queue.size()
	for f in fighters():
		if not f.is_dead() and not f.surrendered() and f.brain != null and f.brain.state != NpcBrain.State.FLEE and not f.brain.routed():
			n += 1
	return n


## How much of the wave now is down or out of the fight (0..1).
func lost_frac() -> float:
	if wave_count <= 0:
		return 0.0
	# (the waves before were all down or out before this one came: those still fighting are this wave's)
	return clampf(1.0 - float(fighting_count()) / float(wave_count), 0.0, 1.0)


func _on_died(f: NpcFighter, killer: Node) -> void:
	member_died.emit(f, killer)


func _process(dt: float) -> void:
	if not _queue.is_empty():
		_spawn_next()
		return
	if spawned == 0:
		return
	_look_t += dt
	if _look_t < LOOK_S:
		return
	var step := _look_t
	_look_t = 0.0
	if fighting_count() > 0:
		_wave_t = -1.0
		return
	if waves_left > 0:
		if _wave_t < 0.0:
			_wave_t = wave_s
		_wave_t -= step
		if _wave_t <= 0.0:
			_wave_t = -1.0
			waves_left -= 1
			_spawn_wave()                       # (each man takes the squad's order as he comes)
		return
	if not _wiped:
		_wiped = true
		wiped.emit(self)
	if fighters().is_empty():
		queue_free()                            # (every man gone: nothing left of the squad to count)
