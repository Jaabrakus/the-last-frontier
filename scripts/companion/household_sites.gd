class_name HouseholdSites
extends RefCounted
## What the spouse's chores find in the level, as small adapters over the fort's station nodes, so SpouseCore stays
## logic-only (its tests use fakes with the same few methods). Each finder returns an object (null: none) that is also a
## Node3D-like thing the body walks to: `pos()`.
##
##   pile   Pile: a woodpile low on wood         wood_room(), add_wood_units(n) -> n laid
##   smoke  Smoke: a smokehouse                  larder_raw(), smudge_min(), smudge_room(), add_venison(n), add_wood_units(n)
##   rack / frame / hoop: the CampStation node itself (only where she works; her rack and hoop records are her core's)

## A woodpile counts as low at or under this many sticks.
const PILE_LOW := 6


class Pile extends RefCounted:
	var node: Woodpile

	func _init(w: Woodpile) -> void:
		node = w

	func pos() -> Vector3:
		return node.global_position

	func wood_room() -> int:
		return Woodpile.MAX - node.count

	func add_wood_units(n: int) -> int:
		var put := clampi(n, 0, wood_room())
		if put > 0:
			node.call("_set_count", node.count + put)
		return put


class Smoke extends RefCounted:
	var node: Smokehouse

	func _init(s: Smokehouse) -> void:
		node = s

	func pos() -> Vector3:
		return node.global_position

	func larder_raw() -> int:
		return node.count_of("venison")

	func smudge_min() -> float:
		return node.smudge_min

	func smudge_room() -> int:
		return floori((Smokehouse.SMUDGE_MAX_MIN - node.smudge_min) / Smokehouse.SMUDGE_MIN_PER_WOOD)

	func add_venison(n: int, who := "", why := "") -> int:
		if n <= 0:
			return 0
		var inv := InventoryState.new()
		inv.add("venison", n)
		return node.put(inv, "venison", n, who, why)   # LEDGER: the larder notes who hung it

	func add_wood_units(n: int) -> int:
		var put := clampi(n, 0, smudge_room())
		if put > 0:
			node.smudge_min += put * Smokehouse.SMUDGE_MIN_PER_WOOD
			node.call("_show_fire")
		return put


## The nearest woodpile to `near` (within `within` m) that is low (a pile beside a fire feeds it, so it runs low first).
static func low_pile(tree: SceneTree, near: Vector3, within: float) -> Object:
	var best: Object = null
	var bd := within
	for n in tree.get_nodes_in_group(Woodpile.GROUP):
		var w := n as Woodpile
		if w == null or not is_instance_valid(w) or w.count > PILE_LOW:
			continue
		var d := w.global_position.distance_to(near)
		if d < bd:
			bd = d
			best = Pile.new(w)
	return best


static func smokehouse(tree: SceneTree, near: Vector3, within: float) -> Object:
	var best: Object = null
	var bd := within
	for n in tree.get_nodes_in_group(&"smokehouses"):
		var s := n as Smokehouse
		if s == null or not is_instance_valid(s):
			continue
		var d := s.global_position.distance_to(near)
		if d < bd:
			bd = d
			best = Smoke.new(s)
	return best


## The nearest CampStation of `kind` to `near` (within `within` m); `fire_m` > 0 wants a lit campfire that near it (a
## station without one is taken only when none has).
static func station(tree: SceneTree, kind: String, near: Vector3, within: float, fire_m := 0.0) -> Object:
	var best: Object = null
	var bd := within
	var lit_best: Object = null
	var lit_d := within
	for n in tree.get_nodes_in_group(BuiltPiece.GROUP):
		var st := (n as Node).get_node_or_null("Station") as CampStation
		if st == null or st.kind != kind:
			continue
		var d := st.global_position.distance_to(near)
		if d < bd:
			bd = d
			best = st
		if fire_m > 0.0 and d < lit_d and _lit_fire_near(tree, st.global_position, fire_m):
			lit_d = d
			lit_best = st
	return lit_best if lit_best != null else best


static func _lit_fire_near(tree: SceneTree, at: Vector3, m: float) -> bool:
	for n in tree.get_nodes_in_group(Campfire.GROUP):
		var c := n as Campfire
		if c != null and is_instance_valid(c) and c.is_lit() and c.global_position.distance_to(at) <= m:
			return true
	return false
