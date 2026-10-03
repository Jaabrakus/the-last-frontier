class_name StoryLayer
extends Node3D
## A story's year layer of the valley (docs/maps.md "Year layers"; docs/main_story.md 10.1's fixes table): what stands,
## who lives where and which animals live there in that year, on the same baked terrain. The data is
## data/world/layers/<id>.json (1757: the Flatts farms of Ott, Wendel and the Brenners, the Rauch farm and the mill east
## of the river, the ford, the fort's unfinished church, the pine grove at the head of the open land with the wreck's
## clearing, the raiders' camp spot; no mammoths and no bison in any square). Its places and sites carry the storyline's
## own names and points, so the missions find the buildings. Free play never sees a layer.
##
##   StoryLayer.apply(level, "1757")     # the director, when a storyline with "layer": "1757" begins or a save brings it back
##   StoryLayer.place("rauch_farm")      # a named point on the ground (Vector3.INF: no such place)
##   StoryLayer.places()                 # name -> [x, z] (a storyline's "places" format: the director can merge them)
##   StoryLayer.farm_pieces("farm_ott")  # the built pieces of a site (to set alight in the raid: FireSpread.ignite)
##   StoryLayer.active_id()              # the layer applied ("" none); StoryLayer.clear() back to free play's animals
##
## Its buildings are the build menu's own pieces (BuildWorld.add_piece, as FortPlan stamps the fort): floors, log walls,
## gables, roofs, the stone hearths, lean-tos, woodpiles, a drying rack, the ford's posts; free of cost, exactly where the
## data puts them on the ground (a cabin's floors at the highest ground under them, its footing reaching the lowest), so
## FireSpread burns them like the player's own, in stages, a roof falling with its walls, the hearths left standing.
## Each is tagged (META_LAYER, META_SITE) and saved with the building (SaveParts.save_building: the tags, and the layers
## the world has had: BuildWorld meta WORLD_META), so a load never places them twice and a farm burned stays burned.
## A guest in a shared world (NetSession) gets them with the host's world and places none.
## What is not a build piece (the church's stone walls, the pines, the mill's wheel) is StoryLayerProps' and lives under
## this node, rebuilt with the level (the wheel is burnable: the fire part keeps it by its path).
## The animals: WildlifeLand asks animals_of() for each square's numbers (the layer's override: the "all" entry, then the
## square type's); a spawner already in the level when the layer comes is capped at once (its bodies of a species the
## layer has none of leave). clear() puts free play's numbers back for the next land made.

const DIR := "res://data/world/layers/"
## The layer place() and places() read when none is applied yet (the only one so far).
const DEFAULT_LAYER := "1757"
const NODE_PREFIX := "StoryLayer_"
const META_LAYER := &"story_layer"
const META_SITE := &"layer_site"
const WORLD_META := &"story_layers"
const G := preload("res://scripts/building/build_geometry.gd")
## A door's place: this far out from its wall's middle.
const DOOR_OUT := 1.6

static var _active := ""
static var _cache := {}
static var _places := {}

var layer_id := ""
var data := {}
## Site id -> its node (the church, the grove, the mill wheel).
var props := {}
## Pieces placed by the last apply (0 when the world had them already).
var placed := 0


# --- The API --------------------------------------------------------------------------------------------------------------

## Puts layer `id` on `level`: its buildings (once per world: saved with it), its other parts (once per level) and
## its animals' numbers. Applying it again changes nothing. Returns the layer's node (null: no such layer).
static func apply(level: Node, id: String) -> StoryLayer:
	var d := load_layer(id)
	if d.is_empty():
		push_error("StoryLayer: no layer %s (%s%s.json)" % [id, DIR, id])
		return null
	if level == null or not level.is_inside_tree():
		push_error("StoryLayer: layer %s needs a level in the tree" % id)
		return null
	_active = id
	var node := level.get_node_or_null(NODE_PREFIX + id) as StoryLayer
	if node == null:
		node = StoryLayer.new()
		node.name = NODE_PREFIX + id
		node.layer_id = id
		node.data = d
		level.add_child(node)
		node._build_props(level)
	node.placed = 0
	if not NetSession.is_guest(level.get_tree()):
		var w := _world_of(level)
		if w and not applied(w).has(id):
			node.placed = node._place_pieces(w)
			_mark(w, id)
	cap_wildlife(level.get_tree())
	return node


## The layer applied ("" none: free play).
static func active_id() -> String:
	return _active


## Back to free play's numbers for the animals of any land made from now on (the layer's buildings stay where they are).
static func clear() -> void:
	_active = ""


## Layer `id`'s data ({} none).
static func load_layer(id: String) -> Dictionary:
	if not _cache.has(id):
		var d: Variant = null
		var path := DIR + "%s.json" % id
		if FileAccess.file_exists(path):
			d = JSON.parse_string(FileAccess.get_file_as_string(path))
		_cache[id] = d if d is Dictionary else {}
	return _cache[id]


## The named point `name` of the layer (`id`, else the one applied, else DEFAULT_LAYER) on the ground; Vector3.INF when
## there is none. Its sites (their points), each site's "<id>_door", "flatts_farms" (the farms' middle) and its listed
## places, which win (the storyline's own points: data/story/storylines/two_fires.json places, the same names).
static func place(name: String, id := "") -> Vector3:
	var xz: Variant = places(id).get(name)
	if not xz is Array:
		return Vector3.INF
	var x := float(xz[0])
	var z := float(xz[1])
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


## Every named point of the layer: name -> [x, z].
static func places(id := "") -> Dictionary:
	var lid := _id_or_active(id)
	if _places.has(lid):
		return _places[lid]
	var d := load_layer(lid)
	var out := {}
	var farms := Vector2.ZERO
	var n := 0
	for s: Dictionary in d.get("sites", []):
		if not s.has("at"):
			continue
		var xf := site_xf(s)
		out[String(s.id)] = [xf.origin.x, xf.origin.z]
		var door := _door_local(s)
		if door != Vector3.INF:
			var p := xf * door
			out[String(s.id) + "_door"] = [p.x, p.z]
		if String(s.get("kind", "")) == "farm":
			farms += Vector2(xf.origin.x, xf.origin.z)
			n += 1
	if n > 0:
		out["flatts_farms"] = [farms.x / n, farms.y / n]
	# the places listed win over a site's (the storyline's own points)
	var pd: Dictionary = d.get("places", {})
	for k: String in pd:
		if not k.begins_with("_"):
			var v := _xz(pd[k])
			out[k] = [v.x, v.y]
	_places[lid] = out
	return out


## The sites of the layer (of `kind` when given: "farm", "mill", "marker", "church", "grove").
static func site_ids(kind := "", id := "") -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in load_layer(_id_or_active(id)).get("sites", []):
		if kind == "" or String(s.get("kind", "")) == kind:
			out.append(String(s.id))
	return out


## The built pieces of site `farm_id` standing in the level now (a farm, the mill, the ford's posts): [BuiltPiece].
static func farm_pieces(farm_id: String) -> Array:
	var out: Array = []
	var w := _world()
	if w == null:
		return out
	for p in w.pieces():
		if p.has_meta(META_SITE) and String(p.get_meta(META_SITE)) == farm_id:
			out.append(p)
	return out


## Every built piece of a layer (`id`; "" any) standing in the level now.
static func layer_pieces(id := "") -> Array:
	var out: Array = []
	var w := _world()
	if w == null:
		return out
	for p in w.pieces():
		if p.has_meta(META_LAYER) and (id == "" or String(p.get_meta(META_LAYER)) == id):
			out.append(p)
	return out


## The most of each animal a square of type `type_id` holds: `caps` (its type's, squares.json), with the applied layer's
## override over them (its "all" entry, then the type's own); `caps` as they are in free play.
static func animals_of(type_id: String, caps: Dictionary) -> Dictionary:
	if _active == "":
		return caps
	var a: Dictionary = load_layer(_active).get("animals", {})
	if a.is_empty():
		return caps
	var out := caps.duplicate()
	for k: String in ["all", type_id]:
		var o: Variant = a.get(k)
		if o is Dictionary:
			for s: String in o:
				if not s.begins_with("_"):
					out[s] = o[s]
	return out


## The level's wildlife (when there is a spawner) held to the applied layer's numbers at once: each square's most and
## numbers, and the bodies of a species its square now holds none of taken out of the world. Returns how many left.
static func cap_wildlife(tree: SceneTree) -> int:
	var sp := WildlifeSpawner.find(tree)
	if sp == null or sp.land == null:
		return 0
	var none := {}
	for sq: Vector2i in sp.land.squares:
		var e: WildlifeEcology = sp.land.squares[sq]
		var t := WorldSquares.type_of(sq)
		var caps := animals_of(WorldSquares.type_id(sq), t.get("animals", {}))
		for s: String in caps:
			if not e.caps.has(s):
				continue
			e.caps[s] = float(caps[s])
			e.pop[s] = clampf(float(e.pop[s]), 0.0, float(caps[s]))
			if float(caps[s]) <= 0.0:
				none["%d,%d:%s" % [sq.x, sq.y, s]] = true
	var gone := 0
	for an in sp.animals():
		if an.is_dead():
			continue
		if none.has("%d,%d:%s" % [an.home_sq.x, an.home_sq.y, WildlifeEcology.kind_of(an.species)]):
			sp.remove_animal(an)
			gone += 1
	return gone


# --- The save (SaveParts.save_building / load_building) ---------------------------------------------------------------

## A layer's piece keeps its tags in the save (e: the piece's entry).
static func save_piece(p: BuiltPiece, e: Dictionary) -> void:
	if p.has_meta(META_LAYER):
		e["layer"] = [String(p.get_meta(META_LAYER)), String(p.get_meta(META_SITE, ""))]


static func load_piece(p: BuiltPiece, e: Dictionary) -> void:
	var l: Variant = e.get("layer")
	if l is Array and (l as Array).size() >= 1:
		_tag(p, String(l[0]), String(l[1]) if (l as Array).size() > 1 else "")


## The layers the world has had (saved with the building: a load does not place them again).
static func save_world(w: BuildWorld) -> Array:
	return applied(w).duplicate()


## The layers a loaded building has had: the save's list, and those of its pieces.
static func load_world(w: BuildWorld, d: Dictionary) -> void:
	var list: Array = []
	for x in d.get("story_layers", []):
		if not list.has(String(x)):
			list.append(String(x))
	for p in w.pieces():
		if p.has_meta(META_LAYER) and not list.has(String(p.get_meta(META_LAYER))):
			list.append(String(p.get_meta(META_LAYER)))
	w.set_meta(WORLD_META, list)


## The layers whose buildings `w` has had.
static func applied(w: BuildWorld) -> Array:
	return w.get_meta(WORLD_META, []) if w else []


# --- Sites --------------------------------------------------------------------------------------------------------------

## Site `s`'s frame on the map (y 0): at its `at`, turned `yaw` degrees, or (face: river) its +Z toward the river, `turn`
## degrees more.
static func site_xf(s: Dictionary) -> Transform3D:
	var at := _xz(s.get("at", [0.0, 0.0]))
	var yaw := deg_to_rad(float(s.get("yaw", 0.0)))
	if String(s.get("face", "")) == "river":
		var f := WorldRiver.flow_at(at.y)
		var n := Vector3(-f.z, 0.0, f.x)
		if signf(WorldRiver.x_at(at.y) - at.x) != signf(n.x):
			n = -n
		yaw = atan2(n.x, n.z) + deg_to_rad(float(s.get("turn", 0.0)))
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.0, at.y))


## A cabin of `bays` cells in frame `xf` (y 0): its floor's height over the map (the highest ground under its footing's
## points, BuildSnap's rule for a floor) and the lowest ground there.
static func cabin_ground(xf: Transform3D, bays: int) -> Vector2:
	var hi := -INF
	var lo := INF
	for i in bays:
		var cx := (i - (bays - 1) * 0.5) * G.L
		for sx: float in [-1.25, 0.0, 1.25]:
			for sz: float in [-1.25, 0.0, 1.25]:
				var p := xf * Vector3(cx + sx, 0.0, sz)
				var h := FrontierTerrain.height_at(p.x, p.z)
				hi = maxf(hi, h)
				lo = minf(lo, h)
	return Vector2(hi, lo)


## [x, z] or {river_z, river_d} (river_d m along x from the river's centre at river_z) as (x, z).
static func _xz(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary and (v as Dictionary).has("river_z"):
		var z := float(v.river_z)
		return Vector2(WorldRiver.x_at(z) + float(v.get("river_d", 0.0)), z)
	return Vector2.ZERO


## Where one stands at the door of the site's first cabin with one, in the site's frame (Vector3.INF: none).
static func _door_local(s: Dictionary) -> Vector3:
	for part: Dictionary in s.get("parts", []):
		if not part.has("cabin"):
			continue
		var bays := int(part.get("bays", 1))
		var at := _xz(part.get("at", [0.0, 0.0]))
		for side: String in ["front", "back"]:
			var walls: Array = part.get(side, [])
			for i in walls.size():
				if String(walls[i]) == "wall_door":
					var cx := (i - (bays - 1) * 0.5) * G.L
					var dz := G.L * 0.5 + DOOR_OUT
					return Vector3(at.x + cx, 0.0, at.y + (dz if side == "front" else -dz))
	return Vector3.INF


static func _id_or_active(id: String) -> String:
	if id != "":
		return id
	return _active if _active != "" else DEFAULT_LAYER


static func _world() -> BuildWorld:
	var tree := Engine.get_main_loop() as SceneTree
	return BuildWorld.of(tree, false) if tree else null


static func _world_of(level: Node) -> BuildWorld:
	var w := level.get_node_or_null(BuildWorld.NODE_NAME) as BuildWorld
	if w == null:
		w = BuildWorld.of(level.get_tree())
	if w == null:
		w = BuildWorld.new()
		w.name = BuildWorld.NODE_NAME
		level.add_child(w)
	return w


static func _mark(w: BuildWorld, id: String) -> void:
	var list: Array = applied(w).duplicate()
	if not list.has(id):
		list.append(id)
	w.set_meta(WORLD_META, list)


static func _tag(p: BuiltPiece, id: String, site: String) -> void:
	p.set_meta(META_LAYER, id)
	p.set_meta(META_SITE, site)


func _exit_tree() -> void:
	if _active == layer_id:
		_active = ""


# --- Placing the buildings -------------------------------------------------------------------------------------------------

## Builds every site's pieces into `w`; returns how many.
func _place_pieces(w: BuildWorld) -> int:
	var n := 0
	for s: Dictionary in data.get("sites", []):
		var xf := site_xf(s) if s.has("at") else Transform3D.IDENTITY
		for part: Dictionary in s.get("parts", []):
			var made: Array = _cabin(w, xf, part) if part.has("cabin") else [_piece(w, xf, part)]
			for p in made:
				if p is BuiltPiece:
					_tag(p, layer_id, String(s.id))
					n += 1
	print("StoryLayer %s: %d pieces built" % [layer_id, n])
	return n


## A log cabin of the build menu's pieces (`part`: bays, front / back walls per cell, left / right end walls, hearth
## "left" / "right"), as build mode would snap it: floors on the ground, walls on their edges, a gable on each end wall, a
## roof bay over each cell resting on its eave walls, the hearth against an end wall inside.
func _cabin(w: BuildWorld, site: Transform3D, part: Dictionary) -> Array:
	var out: Array = []
	var bays := maxi(int(part.get("bays", 1)), 1)
	var at := _xz(part.get("at", [0.0, 0.0]))
	var xf := site * Transform3D(Basis(Vector3.UP, deg_to_rad(float(part.get("yaw", 0.0)))), Vector3(at.x, 0.0, at.y))
	var g := cabin_ground(xf, bays)
	if g.y < g.x - G.FLOOR_FOOTING + 0.1:
		push_warning("StoryLayer: the ground under %s falls %.2f m, more than its footing" % [part.cabin, g.x - g.y])
	var base := Transform3D(xf.basis, Vector3(xf.origin.x, g.x, xf.origin.z))
	var h := G.L * 0.5
	var floors: Array[BuiltPiece] = []
	for i in bays:
		var f := w.add_piece("floor", base * Transform3D(Basis(), Vector3((i - (bays - 1) * 0.5) * G.L, 0.0, 0.0)), true, -1)
		floors.append(f)
		out.append(f)
	var edge := func(f: BuiltPiece, k: int) -> Transform3D:
		var b := Basis(Vector3.UP, k * PI * 0.5)
		return f.global_transform * Transform3D(b, b.z * h + Vector3.UP * G.FLOOR_H)
	var fronts: Array[BuiltPiece] = []
	for i in bays:
		var types: Array = part.get("front", [])
		var wall := w.add_piece(String(types[i]) if i < types.size() else "wall", edge.call(floors[i], 0), false, floors[i].piece_id)
		fronts.append(wall)
		out.append(wall)
	for i in bays:
		var types: Array = part.get("back", [])
		out.append(w.add_piece(String(types[i]) if i < types.size() else "wall", edge.call(floors[i], 2), false, floors[i].piece_id))
	var ends := {}
	ends["left"] = w.add_piece(String(part.get("left", "wall")), edge.call(floors[0], 3), false, floors[0].piece_id)
	ends["right"] = w.add_piece(String(part.get("right", "wall")), edge.call(floors[bays - 1], 1), false, floors[bays - 1].piece_id)
	out.append(ends.left)
	out.append(ends.right)
	for k: String in ["left", "right"]:
		var e: BuiltPiece = ends[k]
		out.append(w.add_piece("gable", e.global_transform * Transform3D(Basis(), Vector3(0.0, G.WALL_H, 0.0)), false, e.piece_id))
	for i in bays:
		var top := fronts[i].global_transform * Transform3D(Basis(), Vector3(0.0, G.WALL_H, -h))
		out.append(w.add_piece("roof", top, false, fronts[i].piece_id))
	var hearth := String(part.get("hearth", ""))
	if ends.has(hearth):
		var e: BuiltPiece = ends[hearth]
		out.append(w.add_piece("hearth", e.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, -G.T * 0.5)), false, -1))
	return out


## One build piece (`part`: type, at [x, z] in the site's frame or place (a layer place), yaw degrees) on the ground, by
## its own rule: a lean-to at the highest of its posts and the foot of its slope, the camp and furniture pieces at the
## highest ground under their footprints (FortPlan.settle), a palisade's stakes following the ground.
func _piece(w: BuildWorld, site: Transform3D, part: Dictionary) -> BuiltPiece:
	var type := String(part.get("type", ""))
	if not BuildData.get_default().has(type):
		push_warning("StoryLayer: no piece %s" % type)
		return null
	var yaw := deg_to_rad(float(part.get("yaw", 0.0)))
	var xf: Transform3D
	if part.has("place"):
		var p := place(String(part.place), layer_id)
		if p == Vector3.INF:
			push_warning("StoryLayer: no place %s" % part.place)
			return null
		xf = Transform3D(Basis(Vector3.UP, site.basis.get_euler().y + yaw), Vector3(p.x, 0.0, p.z))
	else:
		var at := _xz(part.get("at", [0.0, 0.0]))
		xf = site * Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.0, at.y))
	xf = settle(type, xf)
	return w.add_piece(type, xf, true, -1, FortPlan.stake_ground(type, xf))


## `xf` (its x, z and turn) at the height `type` stands at on the ground.
static func settle(type: String, xf: Transform3D) -> Transform3D:
	if type in ["lean_to", "campfire"]:
		var pts: Array
		if type == "campfire":
			pts = [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), Vector3.ZERO]
		else:
			pts = [Vector3(-G.LEAN_W * 0.45, 0, 0), Vector3(G.LEAN_W * 0.45, 0, 0), Vector3(-G.LEAN_W * 0.45, 0, -G.LEAN_D),
					Vector3(G.LEAN_W * 0.45, 0, -G.LEAN_D)]
		var hi := -INF
		for p: Vector3 in pts:
			var q := xf * p
			hi = maxf(hi, FrontierTerrain.height_at(q.x, q.z))
		return Transform3D(xf.basis, Vector3(xf.origin.x, hi, xf.origin.z))
	if type == "post":
		return Transform3D(xf.basis, Vector3(xf.origin.x, FrontierTerrain.height_at(xf.origin.x, xf.origin.z), xf.origin.z))
	return FortPlan.settle(type, xf)


# --- The other parts -------------------------------------------------------------------------------------------------------

## The church, the grove and the mill's wheel (once per level: they are not saved).
func _build_props(level: Node) -> void:
	var sv: Variant = level.get("settings")
	var settings: WorldSettings = sv as WorldSettings if sv is WorldSettings else null
	var visuals := DisplayServer.get_name() != "headless"
	for s: Dictionary in data.get("sites", []):
		var id := String(s.id)
		match String(s.get("kind", "")):
			"church":
				var xf := site_xf(s)
				xf.origin.y = FrontierTerrain.height_at(xf.origin.x, xf.origin.z)
				var o := xf
				var ground := func(x: float, z: float) -> float:
					var p := o * Vector3(x, 0.0, z)
					return FrontierTerrain.height_at(p.x, p.z) - o.origin.y
				var c := StoryLayerProps.church(s.get("church", {}), 1757, ground)
				c.name = "Church_" + id
				add_child(c)
				c.global_transform = xf
				props[id] = c
			"grove":
				var spec: Dictionary = s.get("grove", {})
				var clear: Array = []
				for cl: Dictionary in spec.get("clear", []):
					var p := place(String(cl.get("place", "")), layer_id)
					if p != Vector3.INF:
						clear.append([p, float(cl.get("r", 15.0))])
				var gr := StoryLayerProps.grove(StoryLayerProps.grove_trees(spec, clear), settings, visuals)
				gr.name = "Grove_" + id
				add_child(gr)
				props[id] = gr
			"mill":
				if s.has("wheel"):
					var wh := _mill_wheel(s)
					if wh:
						wh.name = "MillWheel_" + id
						props[id] = wh


## The mill's wheel: in front of its front wall at `along` (m along it from the house's middle), out where the ground is
## `river_d` m (along x) from the river's centre, its paddles in the water; its shaft to the wall.
func _mill_wheel(s: Dictionary) -> Node3D:
	var spec: Dictionary = s.wheel
	var house: Dictionary = {}
	for part: Dictionary in s.get("parts", []):
		if part.has("cabin"):
			house = part
			break
	if house.is_empty():
		return null
	var at := _xz(house.get("at", [0.0, 0.0]))
	var xf := site_xf(s) * Transform3D(Basis(), Vector3(at.x, 0.0, at.y))
	var floor_y := cabin_ground(xf, int(house.get("bays", 1))).x
	var r := float(spec.get("radius", 2.0))
	var width := float(spec.get("width", 0.7))
	var wall := xf * Vector3(float(spec.get("along", 0.0)), 0.0, G.L * 0.5 + G.T * 0.5)
	var out := xf.basis.z.normalized()
	# out along the front's normal until the ground is river_d from the river's centre (along x)
	var want := float(spec.get("river_d", 8.0))
	var t0 := 0.0
	var t1 := 20.0
	for i in 24:
		var tm := (t0 + t1) * 0.5
		var q := wall + out * tm
		if absf(q.x - WorldRiver.x_at(q.z)) > want:
			t0 = tm
		else:
			t1 = tm
	var c := wall + out * ((t0 + t1) * 0.5)
	var ground := FrontierTerrain.height_at(c.x, c.z)
	var level := WorldRiver.level_at(c.z)
	var y := maxf(ground + r - 0.15, minf(level + r - 0.55, floor_y + 1.6))
	c.y = y
	var shaft := (c - wall).length()
	var flow := WorldRiver.flow_at(c.z)
	# the axle along the node's +Z toward the wall: the paddles under it pushed downstream
	var basis := Basis.looking_at(out, Vector3.UP)         # (-Z out toward the river: +Z toward the wall)
	var turn := 0.35 * signf(basis.x.dot(flow))
	var wh := StoryLayerProps.mill_wheel(r, width, shaft, turn if turn != 0.0 else 0.35, maxf(y - ground, 0.5), 1757)
	add_child(wh)
	wh.global_transform = Transform3D(basis, c)
	return wh
