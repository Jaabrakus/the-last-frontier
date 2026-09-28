class_name Woodpile
extends Node3D
## A woodpile (the build piece "woodpile"; user 2026-09-27: "a woodpile that feeds a fire by itself overnight"): split
## wood stacked between its stakes, up to MAX sticks (the pack's firewood; each an armload of split wood, two game hours
## of fire). E stacks all the pack's firewood on it; with none in the pack E takes FETCH back.
## Within FEED_M of a campfire or a hearth (the nearest; one woodpile to a fire) the pile feeds it: while the fire is
## lit and down to its last TOP_UP_MIN game minutes of wood, the next stick goes on by itself (CampLink.refresh calls
## sync() four times a second; a night's sleep runs 20 game minutes between two calls at most, so the fire never dies
## while the pile lasts). The pile keeps its own count (the survival core's fuel stack, SurvivalCamp.stack_fuel, is for
## the core's own camp) so it works the same with or without the core. The smokehouse's smudge takes from a pile beside
## it that feeds no fire (Smokehouse). Kept in the save (SaveParts building "woodpile").

const GROUP := &"woodpiles"
const MAX := 18
const FEED_M := 3.0
const FETCH := 2
## A lit fire with less than this left (game minutes) gets the next stick.
const TOP_UP_MIN := 60.0

var count := 0
var interact_reach := 2.4
## The fire it feeds (CampLink) and that fire's record id when it linked.
var fire: Campfire
var _mm: MultiMeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Wood"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var log := CylinderMesh.new()
	log.top_radius = 0.075
	log.bottom_radius = 0.08
	log.height = 0.5
	log.radial_segments = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.33, 0.24, 0.17)
	m.roughness = 0.9
	log.material = m
	mm.mesh = log
	mm.instance_count = MAX
	var per_row := 6
	for i in MAX:
		var row := i / per_row
		var col := i % per_row
		var x := -BuildGeometry.WOOD_L * 0.5 + 0.17 + (BuildGeometry.WOOD_L - 0.34) * col / float(per_row - 1) + (0.07 if row % 2 == 1 else 0.0)
		var b := Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.05 * float((i * 7) % 3 - 1))
		mm.set_instance_transform(i, Transform3D(b, Vector3(minf(x, BuildGeometry.WOOD_L * 0.5 - 0.1), 0.17 + 0.145 * row, 0.0)))
	mm.visible_instance_count = 0
	_mm.multimesh = mm
	add_child(_mm)


## Finds the fire it feeds (the nearest within FEED_M no other pile feeds; `claimed`: fire -> pile) and, while that fire
## is lit and low, puts the next stick on it. CampLink.refresh calls it four times a second.
func sync(link: CampLink, claimed: Dictionary) -> void:
	var f: Campfire = null
	var bd := FEED_M
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		var c := n as Campfire
		if c == null or c.fire_id == "" or (claimed.has(c) and claimed[c] != self):
			continue
		var d := c.global_position.distance_to(global_position)
		if d <= bd:
			bd = d
			f = c
	fire = f
	if f == null:
		return
	claimed[f] = self
	var rec := f.record()
	if count > 0 and not rec.is_empty() and str(rec.get("state", "")) == "lit" and float(rec.get("fuel_min", 0.0)) < TOP_UP_MIN:
		link.add_fuel(f.fire_id, Campfire.FUEL_MIN_PER_WOOD)
		_set_count(count - 1)


func _set_count(n: int) -> void:
	count = clampi(n, 0, MAX)
	_show()


func _show() -> void:
	if _mm and _mm.multimesh:
		_mm.multimesh.visible_instance_count = count


## Stacks the pack's firewood on the pile (as much as it has room for). How many went on.
func stack(player: Node) -> int:
	var inv := InventoryState.from_player(player)
	var n := inv.take("firewood", MAX - count)
	if n <= 0:
		return 0
	player.set("inventory_pack", inv.pack.duplicate(true))
	_set_count(count + n)
	return n


## Takes up to `n` sticks back into the pack. How many came.
func take(player: Node, n: int) -> int:
	var got := mini(n, count)
	if got <= 0:
		return 0
	_set_count(count - got)
	var inv := InventoryState.from_player(player)
	inv.add("firewood", got)
	player.set("inventory_pack", inv.pack.duplicate(true))
	return got


## One stick off the pile for something that burns it itself (the smokehouse's smudge). True when there was one.
func draw_one() -> bool:
	if count <= 0 or fire != null:
		return false
	_set_count(count - 1)
	return true


# --- E ---------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + Vector3.UP * 0.6


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func highlight_targets() -> Array:
	var p := get_parent() as BuiltPiece
	return p.highlight_targets() if p else []


func interact_prompt(player: Node) -> String:
	if is_instance_valid(BuildMode.current) and BuildMode.current.active:
		return ""
	var feeds := "      it feeds the %s" % ("hearth" if fire.hearth else "fire") if fire != null and is_instance_valid(fire) else ""
	var wood := Campfire._pack_count(player, "firewood")
	if wood > 0 and count < MAX:
		return "Stack firewood (%d on the pile, %d in the pack)%s" % [count, wood, feeds]
	if count > 0:
		return "Take firewood (%d on the pile)%s" % [count, feeds]
	return "Stack firewood (the pile is empty; none in the pack)"


## Hold E's list (PlayerInteractor): stacking the pack's wood, and taking some when the pile has any.
func interact_actions(player: Node) -> Array:
	var first := interact_prompt(player)
	if first == "":
		return []
	var out: Array = [{"id": "", "text": first}]
	if Campfire._pack_count(player, "firewood") > 0 and count < MAX and count > 0:
		out.append({"id": "take", "text": "Take firewood (%d on the pile)" % count})
	return out


func interact_action(player: Node, id: String) -> void:
	if id == "take":
		if not (is_instance_valid(BuildMode.current) and BuildMode.current.active):
			take(player, FETCH)
		return
	interact(player)


func interact(player: Node) -> void:
	if is_instance_valid(BuildMode.current) and BuildMode.current.active:
		return
	if Campfire._pack_count(player, "firewood") > 0 and count < MAX:
		stack(player)
	elif count > 0:
		take(player, FETCH)


# --- The save --------------------------------------------------------------------------------------

func to_save() -> int:
	return count


func from_save(n: int) -> void:
	count = clampi(n, 0, MAX)
	_show()
