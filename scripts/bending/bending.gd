class_name Bending
extends Node
## The bender's loadout and water (docs/bending_design.md; data/sway/moves.json "elements", "water_meter"; the user,
## 2026-10-04: "users create a char or a loadout where they are one of the four elements ... everyone gets the same 4",
## "have 1 and the user can toggle between the 1s and then roll the wheel to change that spell"):
##   the keys     each element has five keys: 1-4 hold two skills (the same key again switches: partner_of), 5 Mend / Patch;
##                the wheel steps through the readied skill's variations (its modes: SwayCaster.step_mode)
##   the water    a waterbender's meter (this node on the player: Bending.of): water moves spend their "water"; it comes
##                back over time, fast near water (the river, a wall of water, a pool: the group POOLS)
## Bending.ELEMENTS, keys(element) -> [[a, b], ...], bar(element) -> the first skill of each key, partner_of(id),
## element_of(id). On any body that bends (Bending.of: the player, a bot: its own water, its element).

const ELEMENTS := ["earth", "water", "fire", "air"]
const NODE_NAME := &"Bending"
## Places that give a waterbender water (Node3D; the arena's pools).
const POOLS := &"bend_pools"

## The body it is on (the player, a bot; the name kept from when only the player bent).
var player: Node3D
var water := 100.0
var water_max := 100.0
## Its element ("earth", "water", "fire", "air"; "" not chosen): set by the mode that gives it one (the duel, the ring).
var element := ""


static func data() -> Dictionary:
	return SwayMoves.data().get("elements", {})


static func keys(element: String) -> Array:
	return data().get(element, [])


## The first skill of each key: the bar an element starts with.
static func bar(element: String) -> Array:
	var out: Array = []
	for k in keys(element):
		out.append(String((k as Array)[0]))
	return out


## The other skill on `id`'s key ("" none).
static func partner_of(id: String) -> String:
	for e: String in ELEMENTS:
		for k in keys(e):
			var pair := k as Array
			if pair.size() == 2 and String(pair[0]) == id:
				return String(pair[1])
			if pair.size() == 2 and String(pair[1]) == id:
				return String(pair[0])
	return ""


static func element_of(id: String) -> String:
	return String(SwayMoves.move(id).get("element", ""))


static func of(p: Node3D) -> Bending:
	if p == null or not is_instance_valid(p):
		return null
	var b := p.get_node_or_null(NodePath(NODE_NAME)) as Bending
	if b == null:
		b = Bending.new()
		b.name = NODE_NAME
		b.player = p
		var wm: Dictionary = SwayMoves.data().get("water_meter", {})
		b.water_max = float(wm.get("max", 100.0))
		b.water = b.water_max
		p.add_child(b)
	return b


func _physics_process(dt: float) -> void:
	if player == null or water >= water_max:
		return
	var wm: Dictionary = SwayMoves.data().get("water_meter", {})
	var rate := float(wm.get("near_s", 30.0)) if near_water() else float(wm.get("regen_s", 4.0))
	water = minf(water + rate * dt, water_max)


## Water within reach of the body it is on: the river, a wall of water or a bubble, a pool (within its meta reach_m when it
## has one, else near_m + 2).
func near_water() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var r := float((SwayMoves.data().get("water_meter", {}) as Dictionary).get("near_m", 4.0))
	var p := player.global_position
	if WorldRiver.has_water():
		for o: Vector3 in [Vector3.ZERO, Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
			if WorldRiver.depth_at(p + o) > 0.0:
				return true
	for n in get_tree().get_nodes_in_group(POOLS):
		# (a pool with its own reach, meta reach_m: the ring's grates, Tidebreak's rules.json grate_reach_m)
		var reach := float(n.get_meta(&"reach_m")) if n.has_meta(&"reach_m") else r + 2.0
		if (n as Node3D).global_position.distance_to(p) <= reach:
			return true
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		if (z as BendZone).kind in ["water_wall", "bubble"] and (z as BendZone).global_position.distance_to(p) <= r + 2.0:
			return true
	return false


## `amount` of water spent (false: not enough; nothing spent).
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if water < amount:
		return false
	water -= amount
	return true
