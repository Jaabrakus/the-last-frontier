class_name RockDebris
extends Node
## Broken rock pieces lying on the deck (the owner, 2026-10-12: "we can have broken rock pieces on the floor we channel it to
## make the things"): a few of the pieces a thrown stone bursts into (GustLift._chunks) and the rocks of an earth charge that
## fell away (BendCharge) stay where they landed; an earth bender's charge pulls the nearest in (take) and makes its stones
## from them. Looks only: no collision, no part in any hit or rule. One per scene (of), its pieces its children (world
## placed); at most MAX lying (the oldest crumbles first), each LIFE_S, then it crumbles into the deck over SINK_S. A ring's
## reset clears them (GROUP: RingArena.clear_dropped).

const GROUP := &"rock_debris"
const NODE_NAME := "RockDebris"
const MAX := 30
const LIFE_S := 25.0
const SINK_S := 0.8
## Of a thrown stone's burst pieces, this many are kept (GustLift._chunks), the time they fly before they lie.
const KEEP_PER_BURST := 3
const LAND_S := 0.75

## The pieces lying: {m: Node3D, t: seconds lying, s: its scale}
var _pieces: Array = []


## The scene's (made under it the first time; null without one).
static func of(scn: Node) -> RockDebris:
	if scn == null or not is_instance_valid(scn):
		return null
	var d := scn.get_node_or_null(NODE_NAME) as RockDebris
	if d == null:
		d = RockDebris.new()
		d.name = NODE_NAME
		scn.add_child(d)
	return d


## Piece `m` (placed on the deck) left lying: one of the scene's pieces from now.
func lay(m: Node3D) -> void:
	if m == null or not is_instance_valid(m):
		return
	var at := m.global_transform
	if m.get_parent() != self:
		if m.get_parent() != null:
			m.get_parent().remove_child(m)
		add_child(m)
	if m is Node3D:
		m.top_level = true
		m.global_transform = at
	m.add_to_group(GROUP)
	_pieces.append({"m": m, "t": 0.0, "s": m.scale})
	while _pieces.size() > MAX:
		var old: Dictionary = _pieces.pop_front()
		if is_instance_valid(old.m):
			(old.m as Node).queue_free()


## How many lie now.
func count() -> int:
	_prune()
	return _pieces.size()


## The pieces lying within `r` m (flat) of `at`, nearest first, at most `n` of them: theirs from now (not this scene's
## pieces any more; the taker places and frees them).
func take(at: Vector3, r: float, n: int) -> Array:
	_prune()
	var near: Array = []
	for e: Dictionary in _pieces:
		var p := (e.m as Node3D).global_position
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d <= r and float(e.t) < LIFE_S:
			near.append([d, e])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for pair: Array in near.slice(0, maxi(n, 0)):
		var e: Dictionary = pair[1]
		_pieces.erase(e)
		var m := e.m as Node3D
		m.remove_from_group(GROUP)
		m.scale = e.s
		out.append(m)
	return out


func _prune() -> void:
	_pieces = _pieces.filter(func(e: Dictionary) -> bool: return is_instance_valid(e.m) and not (e.m as Node).is_queued_for_deletion())


func _process(dt: float) -> void:
	if _pieces.is_empty():
		return
	_prune()
	for e: Dictionary in _pieces.duplicate():
		e.t = float(e.t) + dt
		var over := float(e.t) - LIFE_S
		if over <= 0.0:
			continue
		var m := e.m as Node3D
		var k := 1.0 - over / SINK_S
		if k <= 0.0:
			_pieces.erase(e)
			m.queue_free()
			continue
		m.scale = (e.s as Vector3) * k                 # (crumbling into the deck)
		m.global_position.y -= dt * 0.15
