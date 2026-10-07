class_name BendClash
extends Node
## THE CLASH (round 4 VIRAL): two attacks meeting in the air get their own moment, at the meeting point and never on a body.
## Every number in data/ring/callouts.json "clash".
##   THE GATE      only while RingRules.stock_on() (installed under RingMode by RingReplay.install); the open world, the
##                 duel and the classic ring keep today's meetings
##   what counts   BendBolt's meetings (bend_bolt.gd meet / meet_lift, read from each bolt's `ended` why: "steam" water
##                 doused fire, "cancel" like met like, "broken" stone met stone, "stone" a stone took the other, "melted"
##                 fire melted ice, "carried" air took the flame, "scattered" air broke the water), a bolt meeting a flying
##                 stone (a GustLift: a thrown or sent-back stone) and two flying stones meeting (GustLift._meet_lifts: read
##                 as two lifts leaving their flight on the same frame within pair_m + their radii). A guard's return is a
##                 bolt (or a lift) like any other, so a sent-back stone meeting the next one is a clash too
##   the moment    effect(at, a, b, way): a burst of each element's bits flung back along its own way (the two colours), a
##                 flash in both colours, two shockwave rings standing in the air across the meeting line, a light; one
##                 sound (BendSounds "clash" when it has one, else the loudest hit, sound_fallback); BendImpact.hold(caster,
##                 hold_s) on both casters when IMPACT's class is there (their poses held a beat; never the camera, aim or
##                 lock). A clash is told once (two bolts ending on one frame within dedup_m are one clash)
##   signal        clashed(at, kind_a, kind_b, way, by_a, by_b): RingReplay's events, RingHighlights' plays, the callout
## Statics for the tests: count (clashes), effects (moments drawn), sounds (sounds played), last ({at, a, b, frame}).

signal clashed(at: Vector3, kind_a: String, kind_b: String, way: Vector3, by_a: Node, by_b: Node)

const NODE_NAME := "BendClash"
const GROUP := &"bend_clash"
## The bolt's `ended` whys that are a meeting with another attack.
const WHYS := ["steam", "cancel", "broken", "stone", "melted", "carried", "scattered"]

static var count := 0
static var effects := 0
static var sounds := 0
static var last := {}

var _recent: Array = []
## Flying lifts last frame: id -> {pos, by, vel, r}.
var _lifts := {}


static func install(m: Node) -> BendClash:
	if m == null:
		return null
	var have := m.get_node_or_null(NODE_NAME) as BendClash
	if have != null:
		return have
	var c := BendClash.new()
	c.name = NODE_NAME
	m.add_child(c)
	return c


static func find(tree: SceneTree) -> BendClash:
	return tree.get_first_node_in_group(GROUP) as BendClash if tree != null else null


static func cfg() -> Dictionary:
	var d: Variant = Callouts.data().get("clash", {})
	return d if d is Dictionary else {}


static func cnum(key: String, def := 0.0) -> float:
	return float(cfg().get(key, def))


static func cblk(key: String) -> Dictionary:
	var d: Variant = cfg().get(key, {})
	return d if d is Dictionary else {}


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = 25
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().get_nodes_in_group(BendBolt.GROUP):
		_on_node_added(n)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BendBolt and not (n as BendBolt).ended.is_connected(_on_bolt_ended):
		(n as BendBolt).ended.connect(_on_bolt_ended.bind(n))


## A bolt ended: a meeting when its why says so; the other is the nearest bolt or flying stone still there (else the one
## that ended with it this frame: then it is the same clash, told once).
func _on_bolt_ended(why: String, b: BendBolt) -> void:
	if not RingRules.stock_on() or not (why in WHYS) or not is_instance_valid(b):
		return
	var at := b.global_position
	var best: Node3D = null
	var bd := INF
	var reach := cnum("pair_m", 0.9)
	var other_kind := ""
	var other_v := Vector3.ZERO
	var other_by: Node = null
	for o in get_tree().get_nodes_in_group(BendBolt.GROUP):
		var ob := o as BendBolt
		if ob == null or ob == b or ob.spent:
			continue
		var d := ob.global_position.distance_to(at)
		if d < bd and d <= b.radius + ob.radius + reach:
			bd = d
			best = ob
			other_kind = ob.kind
			other_v = ob.velocity
			other_by = ob._by()
	for o in get_tree().get_nodes_in_group(GustLift.GROUP):
		var l := o as GustLift
		if l == null or l.stone == null or not is_instance_valid(l.stone):
			continue
		var d := l.stone.global_position.distance_to(at)
		if d < bd and d <= b.radius + l.radius + reach + 0.1:
			bd = d
			best = l.stone
			other_kind = "stone"
			other_v = l.velocity
			other_by = l.by()
	var mid := at if best == null else (at + best.global_position) * 0.5
	if best == null:
		if not (why in ["stone", "broken"]):
			return                             # (its partner ended first and was told already, or none to be seen)
		other_kind = "stone"                   # (a stone it met that is gone already: a lift's dropped stone)
	meet(b.kind, other_kind, mid, b.velocity, other_v, b._by(), other_by)


## Two flying stones that leave their flight on the same frame, close: they met (GustLift._meet_lifts).
func _physics_process(_dt: float) -> void:
	if not RingRules.stock_on():
		_lifts.clear()
		return
	var now := {}
	for o in get_tree().get_nodes_in_group(GustLift.GROUP):
		var l := o as GustLift
		if l == null or l.phase != GustLift.Phase.FLIGHT or l.stone == null or not is_instance_valid(l.stone):
			continue
		now[l.get_instance_id()] = {"pos": l.stone.global_position, "by": l.by(), "vel": l.velocity, "r": l.radius}
	var gone: Array = []
	for id in _lifts:
		if not now.has(id):
			gone.append(id)
	if gone.size() >= 1:
		for i in gone.size():
			var a := _lifts[gone[i]] as Dictionary
			# (the other: another that left with it, or one still flying right there)
			var pool: Array = []
			for j in gone.size():
				if j != i:
					pool.append(_lifts[gone[j]])
			for id in now:
				pool.append(now[id])
			for bdict: Dictionary in pool:
				if (a.pos as Vector3).distance_to(bdict.pos as Vector3) <= float(a.r) + float(bdict.r) + cnum("pair_m", 0.9) + 0.3 \
						and a.by != bdict.by:
					meet("stone", "stone", ((a.pos as Vector3) + (bdict.pos as Vector3)) * 0.5, a.vel, bdict.vel, a.by as Node,
							bdict.by as Node)
					break
	_lifts = now


## The same clash already told (this frame or the last, within dedup_m).
func _seen(at: Vector3) -> bool:
	var f := Engine.get_physics_frames()
	for r: Dictionary in _recent:
		if f - int(r.frame) <= 1 and (r.at as Vector3).distance_to(at) <= cnum("dedup_m", 1.5):
			return true
	return false


## A clash of kinds `ka` and `kb` at `at` (their ways `va`, `vb`; their casters): told once, its moment, its sound, the
## casters' beat, clashed. False when it was already told.
func meet(ka: String, kb: String, at: Vector3, va: Vector3, vb: Vector3, by_a: Node, by_b: Node) -> bool:
	if _seen(at):
		return false
	var f := Engine.get_physics_frames()
	_recent.append({"at": at, "frame": f})
	while _recent.size() > 8:
		_recent.pop_front()
	var way := va - vb
	if way.length_squared() < 1e-4:
		way = va if va.length_squared() > 1e-4 else Vector3.FORWARD
	way = way.normalized()
	count += 1
	last = {"at": at, "a": ka, "b": kb, "frame": f}
	effect(at, ka, kb, way)
	for by in [by_a, by_b]:
		_hold(by)
	clashed.emit(at, ka, kb, way, by_a if by_a != null and is_instance_valid(by_a) else null,
			by_b if by_b != null and is_instance_valid(by_b) else null)
	return true


## The clash's moment at `at` (see the header): drawn only where something is drawn; counted and heard always.
static func effect(at: Vector3, ka: String, kb: String, way: Vector3, with_sound := true) -> void:
	effects += 1
	var d := way.normalized() if way.length_squared() > 1e-6 else Vector3.FORWARD
	if with_sound:
		_sound(at)
	if not BendLooks.live():
		return
	var n := int(cnum("burst_n", 34.0))
	var size := cnum("burst_size", 0.65)
	var mps := cnum("burst_mps", 8.0)
	var spread := cnum("spread_deg", 110.0)
	# (each element's bits flung back the way it came, and a little up: the two colours meet and part)
	BendLooks.burst(at, _matter(ka), n, (-d + Vector3.UP * 0.35).normalized(), spread, mps, size)
	BendLooks.burst(at, _matter(kb), n, (d + Vector3.UP * 0.35).normalized(), spread, mps, size)
	var pool := ToonFxPool.of(BendLooks._scene())
	if pool == null:
		return
	var ca := _col(ka)
	var cb := _col(kb)
	var fl := cblk("flash")
	pool.play("flash", Transform3D(Basis.IDENTITY, at), float(fl.get("life", 0.22)), float(fl.get("from", 0.9)),
			float(fl.get("to", 3.6)), ca, cb)
	# (the shockwave: a ring standing in the air across the meeting line, and a wider, slower one after it)
	var y := d
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var b := Basis(x, y, x.cross(y).normalized())
	var r1 := cblk("ring")
	pool.play("ring", Transform3D(b, at), float(r1.get("life", 0.42)), float(r1.get("from", 0.4)), float(r1.get("to", 5.2)), ca, cb)
	var r2 := cblk("ring2")
	pool.play("ring", Transform3D(b, at), float(r2.get("life", 0.7)), float(r2.get("from", 0.6)), float(r2.get("to", 8.5)),
			cb.lerp(Color.WHITE, 0.3), ca.lerp(Color.WHITE, 0.3))
	var li := cblk("light")
	pool.light(at, ca.lerp(cb, 0.5).lerp(Color.WHITE, 0.25), float(li.get("energy", 7.0)), float(li.get("time", 0.28)),
			float(li.get("reach", 9.0)))


static func _matter(k: String) -> String:
	return {"earth": "stone"}.get(k, k) as String


static func _col(k: String) -> Color:
	return BendLooks.color(_matter(k)).lerp(Color.WHITE, 0.2)


## One sound: the clash id when the sounds have it, else the loudest hit (data).
static func _sound(at: Vector3) -> void:
	var s: Array = cfg().get("sound", ["clash", 3.0, 1.0])
	if not BendSounds.has(StringName(String(s[0]))):
		s = cfg().get("sound_fallback", ["earth_hit", 4.0, 0.78])
	sounds += 1
	BendSounds.play(StringName(String(s[0])), at, float(s[1]), float(s[2]))


## IMPACT's BendImpact.hold(body, s) on a caster (a shared beat; never the camera, aim or lock). Round 4's merge: called
## directly now both classes are in the tree.
static func _hold(by: Variant) -> void:
	if not (by is Node) or not is_instance_valid(by):
		return
	BendImpact.hold(by as Node, cnum("hold_s", 0.06))
