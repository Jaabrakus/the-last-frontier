extends RefCounted
## What a Form cast is made of (the user, 2026-10-03: "it should be earth wall where if the terrain is mud its a mud wall if
## its a tree i can make a tree wall you know"; "the matter comes from the place", docs/main_story.md 11.10). Static. The
## Earth Wall, the Pillar and Stone Form's stones take their matter, their look and their strength from what they are raised
## from (data/sway/moves.json: form_ground the rules, earth_wall.wall.materials the matters, pillar.pillar.materials the
## pillar's strengths, stone_form.looks the stones' looks):
##
##   of_ground(tree, point, col)   the ground's matter where the circle is, in this order:
##                                 "stone"  the collider is rock (its meta surface in form_ground.surfaces: the terrain's
##                                          GroundStone outcrops and steep rock, a boulder; or a group in form_ground.groups:
##                                          the vegetation's "rocks")
##                                 "snow"   snow lies there at least snow_m deep (SnowCover.depth_at: not under a roof)
##                                 "stone"  the terrain's splat is rock there (FrontierTerrain.ground_layers' LAYER_ROCK at
##                                          least rock_min)
##                                 "mud"    its splat is mud (LAYER_MUD at least mud_min: the brook's bed, the river's banks
##                                          and bed, the wet hollows of the woods, the fort's ruts); or the square's type
##                                          names it (form_ground.squares: the marsh)
##                                 "earth"  anything else (packed dirt, grass, the forest floor)
##   tree_at(tree, col, point)     the standing tree whose trunk the crosshair is on ({} none): VegHarvest's describe() and
##                                 its index "i"; a sapling or a felled one is none. Its matter is "wood"
##   take_tree(tree, i, shrink_s)  the tree goes into a wall: out of the forest as felling takes it (VegHarvest.remove_tree:
##                                 its instances, its trunk collider, its crown's shade), a stump at its foot (the felling's
##                                 stump height), both kept by the save's vegetation part like a felled tree. Drawn, the tree
##                                 shrinks into its stump over shrink_s as the wall rises
##   entry(move, matter)           a matter's entry for "earth_wall" or "pillar" (a pillar's look from the wall's, its
##                                 strength its own); numbers(base, entry): the move's numbers with the matter's over them
##   material(look, key)           the look's ShaderMaterial (shaders/sway/form_matter.gdshader), made once per key
##   label(matter)                 what the HUD's spell line and the lock's line say ("mud")
## No class_name (a new one is unknown to a script run until the editor rescans and writes the global class list): its users
## preload it, const FormMatter := preload("res://scripts/sway/form_matter.gd").

const KINDS := ["earth", "mud", "stone", "snow", "wood"]
const LOOKS := ["rock", "earth", "mud", "snow", "wood"]
const SHADER := "res://shaders/sway/form_matter.gdshader"
## A matter's keys a pillar takes from the wall's entry (its look; not the wall's size or strength).
const LOOK_KEYS := ["label", "surface", "crumble", "circle", "mended", "shape", "look"]
## The numbers a matter may set over a move's own.
const NUMBER_KEYS := ["width_m", "height_m", "thick_m", "ahead_m", "radius_m", "rise_s", "life_s", "hits", "hit_min", "crumble_s"]

static var _mats := {}
static var _shader: Shader


# ---------------------------------------------------------------- the rules and the data
static func rules() -> Dictionary:
	return SwayMoves.data().get("form_ground", {})


## Earth Wall's matters (earth_wall.wall.materials).
static func wall_materials() -> Dictionary:
	return (SwayMoves.move("earth_wall").get("wall", {}) as Dictionary).get("materials", {})


## The matter's entry for `move` ("earth_wall": the wall's; "pillar": the wall's look under the pillar's own strengths;
## {} for a matter the table lacks: the move's own numbers).
static func entry(move: String, matter: String) -> Dictionary:
	var w: Dictionary = wall_materials().get(matter, {})
	if move == "earth_wall":
		return w.duplicate(true)
	var out := {}
	for k: String in LOOK_KEYS:
		if w.has(k):
			out[k] = w[k]
	var own: Dictionary = ((SwayMoves.move(move).get("pillar", {}) as Dictionary).get("materials", {}) as Dictionary).get(matter, {})
	for k in own:
		out[k] = own[k]
	return out


## `base` (a move's numbers: wall, pillar) with the matter's entry `e` over them, and its matter, look, shape, crumble and
## surface for FormRaised.raise.
static func numbers(base: Dictionary, e: Dictionary, matter: String) -> Dictionary:
	var out := base.duplicate()
	out.erase("materials")
	for k: String in NUMBER_KEYS:
		if e.has(k):
			out[k] = e[k]
	out["matter"] = matter
	for k: String in ["look", "shape", "crumble", "surface", "mended", "label"]:
		if e.has(k):
			out[k] = e[k]
	return out


static func label(matter: String) -> String:
	return String((wall_materials().get(matter, {}) as Dictionary).get("label", matter))


## The circle's colour for a lock of `matter`: the art's blue drawn toward the matter's (earth keeps the art's own).
static func circle_color(matter: String) -> Color:
	var base := SwayMoves.art_color("form")
	var c: Variant = (wall_materials().get(matter, {}) as Dictionary).get("circle", [])
	if c is Array and (c as Array).size() >= 3:
		return base.lerp(Color(float(c[0]), float(c[1]), float(c[2])), 0.7)
	return base


# ---------------------------------------------------------------- the ground
## The ground's matter at `point` (world), `col` the collider the circle is on (null: found by a ray down). See the header.
static func of_ground(tree: SceneTree, point: Vector3, col: Object = null) -> String:
	var r := rules()
	if col == null and tree != null and tree.current_scene is Node3D:
		var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
		var ex: Array[RID] = []
		for i in 6:
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point + Vector3.DOWN * 1.5, 1, ex))
			if h.is_empty():
				break
			var c: Object = h.collider
			if c is CharacterBody3D or c is RigidBody3D or c is AnimatableBody3D or c is PhysicalBone3D:
				ex.append(h.rid)
				continue
			col = c
			break
	var n := col as Node
	if n != null:
		var surf := String(n.get_meta(&"surface", ""))
		var by_surface: Dictionary = r.get("surfaces", {"stone": "stone", "rock": "stone"})
		if surf != "" and by_surface.has(surf):
			return String(by_surface[surf])
		var by_group: Dictionary = r.get("groups", {"rocks": "stone"})
		for g in by_group:
			if n.is_in_group(StringName(String(g))):
				return String(by_group[g])
	var snow := SnowCover.find(tree) if tree != null else null
	if snow != null and snow.depth_at(point) >= float(r.get("snow_m", 0.08)):
		return "snow"
	if n == null or n.is_in_group(&"terrain") or not n.has_meta(&"surface"):
		# (the terrain, the fort's floor, and fixed things without a surface of their own stand on its splat)
		var w := FrontierTerrain.ground_layers(point.x, point.z)
		if w[FrontierTerrain.LAYER_ROCK] >= float(r.get("rock_min", 0.5)):
			return "stone"
		if w[FrontierTerrain.LAYER_MUD] >= float(r.get("mud_min", 0.45)):
			return "mud"
	var by_square: Dictionary = r.get("squares", {})
	var sq := WorldSquares.type_id(WorldSquares.square_at(point))
	if by_square.has(sq):
		return String(by_square[sq])
	return "earth"


# ---------------------------------------------------------------- a tree
## The standing tree whose trunk `col` was hit at `point` ({} none): VegHarvest.describe("tree") with its index "i".
static func tree_at(tree: SceneTree, col: Object, point: Vector3) -> Dictionary:
	var n := col as Node
	if n == null or not n.is_in_group(&"trees"):
		return {}
	var h := VegHarvest.find(tree)
	if h == null:
		return {}
	var best := {}
	var bd := INF
	for d: Dictionary in h.near(point, 0.6):
		if String(d.get("type", "")) != "tree":
			continue
		var dd := absf(float(d.get("dist", INF)))
		if dd < bd:
			bd = dd
			best = d
	return best


## Tree `i` goes into a wall (see the header): its describe() as it stood ({} when it was gone already).
static func take_tree(tree: SceneTree, i: int, shrink_s := 0.0) -> Dictionary:
	var h := VegHarvest.find(tree)
	if h == null:
		return {}
	var d := h.remove_tree(i)
	if d.is_empty():
		return d
	var stump_h := float(GatherData.get_default().felling.get("stump_height_m", 0.45))
	h.stump_h[i] = stump_h
	var visuals := DisplayServer.get_name() != "headless"
	var scene := tree.current_scene
	scene.add_child(FelledTree.make_stump(d, stump_h, visuals))
	if visuals and shrink_s > 0.0:
		var s := TreeShrink.new()
		s.name = "FormTreeShrink"
		s.harvest = h
		s.pos = d.pos
		s.dur = shrink_s
		scene.add_child(s)
	return d


## The tree drawn down into its stump as the wall rises (drawn only): its instances, hidden by remove_tree, shown again
## and scaled from whole to nothing about its foot over `dur`, then hidden for good.
class TreeShrink:
	extends Node

	const PREFIXES := ["TreeLod", "TreeShadow3_", "TreeShadow4_", "TreeDapple_", "TreeImpostors_"]

	var harvest: VegHarvest
	var pos := Vector3.ZERO
	var dur := 0.7
	var _t := 0.0
	var _nodes: Array = []

	func _ready() -> void:
		if harvest != null:
			_nodes = harvest._visual_nodes(PREFIXES, FrontierVegetation.tree_cell(pos))

	func _process(dt: float) -> void:
		_t += dt
		var u := clampf(_t / maxf(dur, 0.01), 0.0, 1.0)
		var f := 1.0 - smoothstep(0.0, 1.0, u)
		for mmi in _nodes:
			if is_instance_valid(mmi):
				harvest._set_instance_scale(mmi, pos, f if u < 1.0 else 0.0)
		if u >= 1.0:
			queue_free()


# ---------------------------------------------------------------- the look
## The ShaderMaterial of look `lk` (a matter's "look", or a stone's: kind rock / earth / mud / snow / wood, its colours
## a b c d fresh foot, its numbers), made once for `key` and kept.
static func material(lk: Dictionary, key: String) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = load(SHADER) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"look", maxi(LOOKS.find(String(lk.get("kind", "rock"))), 0))
	for k: String in ["a", "b", "c", "d", "fresh", "foot"]:
		var v: Variant = lk.get(k)
		if v is Array and (v as Array).size() >= 3:
			m.set_shader_parameter(StringName("col_" + k), Color(float(v[0]), float(v[1]), float(v[2])))
	for k: String in ["foot_h", "scale", "rough", "bump", "wet", "stones", "top_k"]:
		if lk.has(k):
			m.set_shader_parameter(StringName(k), float(lk[k]))
	_mats[key] = m
	return m


## A matter's wall look (earth_wall.wall.materials.<matter>.look), its material keyed "wall_<matter>".
static func wall_material(matter: String) -> ShaderMaterial:
	var e: Dictionary = wall_materials().get(matter, wall_materials().get("earth", {}))
	return material(e.get("look", {"kind": "earth"}), "wall_" + matter)


## The look of a stone Stone Form raises from `matter`'s ground (stone_form.looks), its material keyed "rock_<matter>".
static func rock_material(matter: String) -> ShaderMaterial:
	var looks: Dictionary = SwayMoves.move("stone_form").get("looks", {})
	var lk: Dictionary = looks.get(matter, looks.get("stone", {"kind": "rock"}))
	return material(lk, "rock_" + (matter if looks.has(matter) else "stone"))


## Forgets the made materials (tests that change the data; the next call makes them again).
static func reset() -> void:
	_mats.clear()
