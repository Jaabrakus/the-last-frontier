extends SceneTree
## The story's 1757 valley layer (StoryLayer, StoryLayerProps, data/world/layers/1757.json; docs/main_story.md 10.1,
## docs/maps.md 1) on the real level, survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/world/test_story_layer.gd -- survival=on
##   free     with no layer: free play's animals (the open land's 40 bison and 4 mammoths), a spawner's bison herds there
##   places   every named place on the ground, the same as the storyline's (two_fires.json: its missions go there); the
##            homestead at [1000, 100]; the ford on the rapid at z 60, its posts on either bank; the wreck's bench near
##            [1100, -380] level enough for the hull; the camp on the east bank's flats by the upper rapid
##   farms    apply builds the Flatts farms, the Rauch farm and the mill of the build menu's pieces, all on dry land east of
##            the river in the open land, floors on the ground (their footing reaching it), walls on the floors, roofs on
##            their eave walls; no two pieces in each other's way (as build mode would refuse); every wooden piece
##            burnable (the hearths stone); none near the homestead
##   props    the church's stone walls outside the stockade by the gate (not burnable, clear of the fort's pieces and the
##            forest); the pines round the wreck's clearing, none in it (nor on the storyline's wreck point); the mill's
##            wheel burnable, its paddles in the water
##   animals  the spawner's bison leave at once, the open land holds no mammoths or bison, a restock brings none, horses
##            and deer stay; a new land and a saved land's numbers hold none
##   again    a second apply builds nothing more and makes no second church or grove
##   save     the building part through JSON: the layer's pieces come back once, tagged, a piece burnt before the save
##            stays gone, and apply after the load builds nothing
##   burn     a farm wall set alight spreads to the walls round it; the whole farm alight burns down, its hearth standing
##   clear    back to free play's numbers
## Ends with "STORY LAYER TEST PASSED (<n> checks)" or "STORY LAYER TEST FAILED (<f> of <n>)".

const G := preload("res://scripts/building/build_geometry.gd")
const OPEN := Vector2i(1, 0)

var checks := 0
var fails: Array[String] = []
var level: Node
var player: FrontierPlayer
var world: BuildWorld
var fire: FireSpread
var spawner: WildlifeSpawner
var layer: StoryLayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	level = current_scene
	player = level.get_node_or_null("Player") as FrontierPlayer
	world = BuildWorld.of(self, false)
	fire = FireSpread.find(self)
	_expect(player != null and world != null and fire != null, "the level has the player, the building and the fire")
	if player == null or world == null or fire == null:
		_end()
		return
	player.ignore_mouse_capture = true
	fire.manual = true
	fire.rain_override = 0.0
	fire.wind_override = Vector3.ZERO
	await _test_free()
	var n0 := world.pieces().size()
	layer = StoryLayer.apply(level, "1757")
	await _frames(3)
	_expect(layer != null and StoryLayer.active_id() == "1757", "apply puts the 1757 layer on the level")
	if layer == null:
		_end()
		return
	_expect(world.pieces().size() - n0 == layer.placed and layer.placed > 60, "it builds %d pieces into the level's building" % layer.placed)
	_test_places()
	_test_farms()
	_test_props()
	await _test_animals()
	await _test_again()
	await _test_save()
	await _test_burn()
	_test_clear()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("STORY LAYER TEST PASSED (%d checks)" % checks)
	else:
		print("STORY LAYER TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)


# --- Free play first ----------------------------------------------------------------------------------------------------

func _test_free() -> void:
	_expect(StoryLayer.active_id() == "", "free play has no layer")
	var land := WildlifeLand.new()
	var e := land.ecology(OPEN)
	_expect(int(e.cap_of("bison")) == 40 and int(e.cap_of("mammoth")) == 4,
			"free play keeps the open land's numbers (bison %d, mammoths %d)" % [int(e.cap_of("bison")), int(e.cap_of("mammoth"))])
	# a spawner in the level before the story's layer comes (wildlife is off in -s runs: one made here)
	spawner = WildlifeSpawner.find(self)
	if spawner == null:
		spawner = WildlifeSpawner.new()
		spawner.name = "Wildlife"
		spawner.setup(player, level.get("vegetation"), level.get("environment_rig"))
		level.add_child(spawner)
	await _frames(6)
	_expect(_alive(spawner, "bison") > 0, "free play: the open land has its bison herds (%d)" % _alive(spawner, "bison"))


func _alive(sp: WildlifeSpawner, kind: String) -> int:
	var n := 0
	for a in sp.animals():
		if not a.is_dead() and WildlifeEcology.kind_of(a.species) == kind:
			n += 1
	return n


# --- Places -------------------------------------------------------------------------------------------------------------

func _test_places() -> void:
	var names := ["homestead", "ford", "ford_west", "ford_east", "flatts_farms", "farm_ott", "farm_wendel", "farm_brenner", "rauch_farm",
			"rauch_farm_door", "mill", "mill_door", "fort_church", "raiders_camp", "wreck", "wreck_site", "pine_grove", "flatts_fort"]
	var missing: Array = []
	for nm: String in names:
		var p := StoryLayer.place(nm)
		if p == Vector3.INF or absf(p.y - FrontierTerrain.height_at(p.x, p.z)) > 0.01:
			missing.append(nm)
	_expect(missing.is_empty(), "every place is on the ground (%s)" % (", ".join(missing) if not missing.is_empty() else "%d of them" % names.size()))
	_expect(StoryLayer.place("no_such_place") == Vector3.INF, "an unknown place is Vector3.INF")
	# the storyline's own points (its missions send the player there): the same names, the same places
	var line: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/storylines/two_fires.json"))
	var lp: Dictionary = (line as Dictionary).get("places", {}) if line is Dictionary else {}
	var odd: Array = []
	var shared := 0
	for k: String in StoryLayer.places():
		if lp.get(k) is Array:
			shared += 1
			var a: Array = lp[k]
			var b: Array = StoryLayer.places()[k]
			if Vector2(float(a[0]) - float(b[0]), float(a[1]) - float(b[1])).length() > 0.01:
				odd.append("%s %s vs %s" % [k, str(a), str(b)])
	_expect(odd.is_empty() and shared >= 9, "the layer's places are the storyline's own (%d shared)%s" % [shared, _list(odd)])
	var h := StoryLayer.place("homestead")
	_expect(Vector2(h.x - 1000.0, h.z - 100.0).length() < 0.01 and h.x > WorldRiver.x_at(h.z) + 50.0,
			"the homestead is at [1000, 100], east of the river")
	var ford := StoryLayer.place("ford")
	var fw := StoryLayer.place("ford_west")
	var fe := StoryLayer.place("ford_east")
	_expect(WorldRiver.rapid_at(ford.z) > 0.99 and absf(ford.x - WorldRiver.x_at(ford.z)) < 0.5,
			"the ford is on the rapid at z %.0f (the river's middle)" % ford.z)
	_expect(fw.x < WorldRiver.x_at(fw.z) - WorldRiver.bank() and fe.x > WorldRiver.x_at(fe.z) + WorldRiver.bank()
			and WorldRiver.depth_at(fw) == 0.0 and WorldRiver.depth_at(fe) == 0.0, "the ford's ends are on dry ground either bank")
	var wr := StoryLayer.place("wreck_site")
	var yaw := deg_to_rad(float(StoryLayer.load_layer("1757").get("wreck_yaw", 0.0)))
	var r := _range(wr, yaw, 13.0, 5.0)
	var r0 := _range(StoryLayer.place("wreck"), yaw, 13.0, 5.0)
	_expect(Vector2(wr.x - 1100.0, wr.z + 380.0).length() < 25.0 and r < 1.0 and FrontierTerrain.in_world(wr.x, wr.z - 12.0),
			"the wreck's bench is near [1100, -380] and level enough for the hull (%.2f m over 26 x 10 m; %.2f at the point itself)" % [r, r0])
	var camp := StoryLayer.place("raiders_camp")
	var cr := _range(camp, 0.0, 10.0, 10.0)
	_expect(camp.x > WorldRiver.x_at(camp.z) + WorldRiver.bank() + 10.0 and cr < 0.8 and absf(camp.z + 250.0) < 40.0,
			"the raiders' camp is on the east bank's flats by the upper rapid (%.2f m over 20 m)" % cr)
	var rauch := StoryLayer.place("rauch_farm")
	var nearest := ""
	var best := INF
	for f: String in StoryLayer.site_ids("farm"):
		var d := StoryLayer.place(f).distance_to(h)
		if d < best:
			best = d
			nearest = f
	_expect(nearest == "rauch_farm" and rauch.distance_to(h) < 110.0, "the Rauch farm is the homestead's nearest neighbour (%.0f m)" % best)
	_expect(StoryLayer.place("wreck").distance_to(StoryLayer.place("wreck_site")) < 22.0, "the storyline's wreck point is in the bench's clearing")
	var pl := StoryLayer.places()
	_expect(pl.get("rauch_farm") is Array and (pl.rauch_farm as Array).size() == 2, "places() gives them as a storyline's [x, z]")


## The ground's fall (m) over a footprint of half extents (hx, hz) at `c` turned `yaw`.
func _range(c: Vector3, yaw: float, hx: float, hz: float) -> float:
	var b := Basis(Vector3.UP, yaw)
	var lo := INF
	var hi := -INF
	for i in 9:
		for j in 5:
			var p := c + b * Vector3(-hx + 2.0 * hx * i / 8.0, 0, -hz + 2.0 * hz * j / 4.0)
			var y := FrontierTerrain.height_at(p.x, p.z)
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return hi - lo


# --- The farms ----------------------------------------------------------------------------------------------------------

func _test_farms() -> void:
	var sites := StoryLayer.site_ids("farm")
	_expect(sites.size() == 4 and sites.has("rauch_farm") and sites.has("farm_brenner") and sites.has("farm_wendel") and sites.has("farm_ott"),
			"four farmsteads: %s" % ", ".join(sites))
	var yard_ok := true
	for sid: String in sites:
		var yard := StoryLayer.place(sid)
		var door := StoryLayer.place(sid + "_door")
		var house := INF
		for p: BuiltPiece in StoryLayer.farm_pieces(sid):
			if p.type == "floor":
				house = minf(house, Vector2(p.global_position.x - yard.x, p.global_position.z - yard.z).length())
		if house < 3.0 or house > 8.0 or door == Vector3.INF or door.distance_to(yard) > 4.0:
			yard_ok = false
	_expect(yard_ok, "each farm's point is its yard, the house a few metres behind it, its door by it")
	sites.append("mill")
	var all: Array = []
	for sid: String in sites:
		var pcs := StoryLayer.farm_pieces(sid)
		all.append_array(pcs)
		var types := {}
		for p: BuiltPiece in pcs:
			types[p.type] = int(types.get(p.type, 0)) + 1
		_expect(pcs.size() >= 13 and types.has("floor") and types.has("roof") and types.has("wall_door"),
				"%s: %d pieces (%s)" % [sid, pcs.size(), JSON.stringify(types)])
	var wet: Array = []
	var west: Array = []
	var away: Array = []
	for p: BuiltPiece in all:
		var o := p.global_position
		var dx := o.x - WorldRiver.x_at(o.z)
		var site := String(p.get_meta(StoryLayer.META_SITE))
		if dx < (6.0 if site == "mill" else WorldRiver.bank() + 10.0):
			west.append("%s %s %.1f" % [site, p.type, dx])
		if WorldRiver.depth_at(o) > 0.0:
			wet.append("%s %s" % [site, p.type])
		if WorldSquares.square_at(o) != OPEN or WorldSquares.type_id(OPEN) != "open_land" or not FrontierTerrain.in_world(o.x, o.z):
			away.append("%s %s" % [site, p.type])
	_expect(west.is_empty(), "every piece stands east of the river (the farms past its banks, the mill by the water)%s" % _list(west))
	_expect(wet.is_empty(), "none stands in the water%s" % _list(wet))
	_expect(away.is_empty(), "all of them are in the open land square%s" % _list(away))
	# the floors on the ground: the highest ground under them at their foot, their footing reaching the lowest
	var bad: Array = []
	for p: BuiltPiece in all:
		if p.type != "floor":
			continue
		for sx: float in [-1.25, 0.0, 1.25]:
			for sz: float in [-1.25, 0.0, 1.25]:
				var q := p.global_transform * Vector3(sx, 0, sz)
				var gy := FrontierTerrain.height_at(q.x, q.z)
				if gy > q.y + G.FLOOR_H - 0.05 or gy < q.y - G.FLOOR_FOOTING + 0.1:
					bad.append("%s floor %.2f" % [p.get_meta(StoryLayer.META_SITE), gy - q.y])
					break
	_expect(bad.is_empty(), "every floor sits on the ground, its footing reaching it%s" % _list(bad))
	# assembled as build mode snaps them: walls on floors, gables on walls, each roof bay on two eave walls
	var loose: Array = []
	for p: BuiltPiece in all:
		var on := []
		for id in p.supports:
			var s := world.by_id(id)
			if s:
				on.append(s.type)
		match p.type:
			"wall", "wall_door", "wall_window":
				if not on.has("floor"):
					loose.append("wall")
			"gable":
				if on.size() != 1 or not String(on[0]).begins_with("wall"):
					loose.append("gable")
			"roof":
				if on.size() != 2 or not String(on[0]).begins_with("wall") or not String(on[1]).begins_with("wall"):
					loose.append("roof on %s" % str(on))
	_expect(loose.is_empty(), "walls rest on floors, gables on walls, every roof bay on its two eave walls%s" % _list(loose))
	var ctx_ok := true
	for p: BuiltPiece in all:
		if p.type in ["wall", "wall_door", "wall_window"] and String(p.ctx.get("e0", "")) == "free" and String(p.ctx.get("e1", "")) == "free":
			ctx_ok = false
	_expect(ctx_ok, "every wall meets another at a corner or in line (notched, not free-standing)")
	# nothing in another's way (BuildSnap's inner boxes, as build mode would refuse)
	var hits: Array = []
	for i in all.size():
		var a: BuiltPiece = all[i]
		for j in range(i + 1, all.size()):
			var b: BuiltPiece = all[j]
			if a.global_position.distance_to(b.global_position) > 9.0:
				continue
			if (BuildSnap.OVERLAP_OK.get(a.type, []) as Array).has(b.type):
				continue
			if _overlap(a, b):
				hits.append("%s %s/%s" % [a.get_meta(StoryLayer.META_SITE), a.type, b.type])
	_expect(hits.is_empty(), "no two of them are in each other's way%s" % _list(hits))
	# burnable: every wooden piece (the hearths are stone)
	var cold: Array = []
	var hearths := 0
	for p: BuiltPiece in all:
		if p.type == "hearth":
			hearths += 1
			if fire.burnable(p):
				cold.append("a burnable hearth")
		elif not fire.burnable(p):
			cold.append(p.type)
	_expect(cold.is_empty() and hearths == 4, "every wooden piece is burnable by FireSpread, the four hearths are stone%s" % _list(cold))
	var tags_ok := true
	for p in StoryLayer.layer_pieces("1757"):
		if String(p.get_meta(StoryLayer.META_LAYER, "")) != "1757" or String(p.get_meta(StoryLayer.META_SITE, "")) == "":
			tags_ok = false
	_expect(tags_ok and StoryLayer.layer_pieces("1757").size() == layer.placed, "each is tagged as the layer's, with its site")
	var posts := StoryLayer.farm_pieces("ford")
	_expect(posts.size() == 2 and posts[0].type == "post", "the ford's two posts stand on its banks")
	var home := StoryLayer.place("homestead")
	var near_home := 0
	for p in StoryLayer.layer_pieces():
		if (p as BuiltPiece).global_position.distance_to(home) < 40.0:
			near_home += 1
	_expect(near_home == 0, "nothing of the layer stands within 40 m of the homestead (the player's own ground)")


func _overlap(a: BuiltPiece, b: BuiltPiece) -> bool:
	for ba: Array in BuildSnap.inner_local(a.type):
		for bb: Array in BuildSnap.inner_local(b.type):
			if BuildSnap.obb_overlap(a.global_transform * (ba[0] as Transform3D), ba[1], b.global_transform * (bb[0] as Transform3D), bb[1]):
				return true
	return false


func _list(a: Array) -> String:
	return "" if a.is_empty() else ": " + ", ".join(a.slice(0, 8))


# --- The church, the grove, the wheel -----------------------------------------------------------------------------------

func _test_props() -> void:
	var church := layer.props.get("fort_church") as Node3D
	_expect(church != null and church.get_node_or_null("Walls") is StaticBody3D, "the church's walls stand, with their colliders")
	if church:
		var box := AABB()
		var first := true
		for cs in church.find_children("*", "CollisionShape3D", true, false):
			var c := cs as CollisionShape3D
			var e := (c.shape as BoxShape3D).size
			var bb := c.global_transform * AABB(-e * 0.5, e)
			box = bb if first else box.merge(bb)
			first = false
		var in_way := 0
		for p in world.pieces():
			if StoryLayer.layer_pieces().has(p):
				continue
			for ib: Array in BuildSnap.inner_local(p.type):
				var t: Transform3D = p.global_transform * (ib[0] as Transform3D)
				if box.grow(-0.05).has_point(t.origin):
					in_way += 1
		var gate := Vector3(0.0, 0.0, -FrontierStructures.FORT_HALF)
		_expect(box.position.x > FrontierStructures.FORT_HALF + 1.0 and Vector3(box.get_center().x, 0, box.get_center().z).distance_to(gate) < 35.0
				and in_way == 0, "it stands outside the stockade by the gate, clear of the fort's pieces (x %.1f..%.1f, z %.1f..%.1f)" %
				[box.position.x, box.end.x, box.position.z, box.end.z])
		_expect(box.size.y > 3.0 and box.size.z > 12.0 and box.size.x > 8.0, "its walls are up to %.1f m, %.0f x %.0f m" % [box.size.y - 0.35, box.size.z, box.size.x])
		var space := (level as Node3D).get_world_3d().direct_space_state
		var hit: Array = []
		var own := church.get_node("Walls") as StaticBody3D
		for cs in church.find_children("*", "CollisionShape3D", true, false):
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = (cs as CollisionShape3D).shape
			q.transform = (cs as CollisionShape3D).global_transform
			q.exclude = [own.get_rid()]
			q.margin = -0.02
			for h in space.intersect_shape(q, 8):
				var n := h.collider as Node
				if n and not n.is_in_group(&"terrain") and not String(n.name).begins_with("Terrain") and not hit.has(String(n.name)):
					hit.append(String(n.name))
		_expect(hit.is_empty(), "nothing of the forest or the fort stands in its walls%s" % _list(hit))
		_expect(not fire.burnable(church), "the church's stone does not burn")
	var grove := layer.props.get("pine_grove") as Node3D
	var trunks := grove.get_node_or_null("Trunks") as StaticBody3D if grove else null
	_expect(trunks != null and trunks.is_in_group(&"trees"), "the pine grove stands (its trunks in the trees group)")
	if trunks:
		var wr := StoryLayer.place("wreck_site")
		var wp := StoryLayer.place("wreck")
		var n := 0
		var in_clear := 0
		var low := 0
		var near_wreck := 0
		for cs in trunks.get_children():
			var p := (cs as Node3D).global_position
			n += 1
			var d := Vector2(p.x - wr.x, p.z - wr.z).length()
			if d < 22.0 or Vector2(p.x - wp.x, p.z - wp.z).length() < 8.0:
				in_clear += 1
			if d < 60.0:
				near_wreck += 1
			if FrontierTerrain.height_at(p.x, p.z) < 1.5:
				low += 1
		_expect(n >= 60, "the grove has %d pines" % n)
		_expect(in_clear == 0 and near_wreck >= 10, "none in the wreck's clearing (22 m round its bench, the storyline's point in it), %d round it within 60 m" % near_wreck)
		_expect(low == 0, "all on the rising ground at the head of the open land")
		# the drawn trees (a window's run; headless builds the colliders only): the forest's LODs, impostors, shadow blobs
		var spec: Dictionary = {}
		for s: Dictionary in StoryLayer.load_layer("1757").sites:
			if String(s.id) == "pine_grove":
				spec = s.grove
		var trees := StoryLayerProps.grove_trees(spec, [[wr, 22.0]])
		var drawn := StoryLayerProps.grove(trees, level.get("settings") as WorldSettings, true)
		var mmis := drawn.find_children("*", "MultiMeshInstance3D", false, false)
		var inst := {}
		var ok := not mmis.is_empty()
		for m in mmis:
			var mm := (m as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.instance_count <= 0 or (m as MultiMeshInstance3D).material_override == null:
				ok = false
				continue
			var kind := String(m.name).get_slice("_", 0)
			inst[kind] = int(inst.get(kind, 0)) + mm.instance_count
		_expect(ok and int(inst.get("TreeLod0", 0)) == trees.size() and int(inst.get("TreeLod2", 0)) == trees.size()
				and int(inst.get("TreeImpostors", 0)) == trees.size(),
				"drawn, every pine has its LODs, impostor and shadow (%d MultiMeshes: %s)" % [mmis.size(), JSON.stringify(inst)])
		drawn.free()
	var wheel := layer.props.get("mill") as Node3D
	_expect(wheel != null and wheel.is_in_group(FireSpread.BURNABLE_GROUP) and fire.burnable(wheel), "the mill's wheel stands, burnable")
	if wheel:
		var c := wheel.global_position
		var lvl := WorldRiver.level_at(c.z)
		var house := INF
		for p: BuiltPiece in StoryLayer.farm_pieces("mill"):
			if p.type == "floor":
				house = minf(house, p.global_position.distance_to(c))
		_expect(c.y - 2.0 < lvl and c.x > WorldRiver.x_at(c.z) and house < 9.0,
				"its paddles dip into the river at the mill's front (axle %.2f, water %.2f, %.1f m from its floor)" % [c.y, lvl, house])


# --- The animals --------------------------------------------------------------------------------------------------------

func _test_animals() -> void:
	await _frames(2)
	_expect(_alive(spawner, "bison") == 0 and _alive(spawner, "mammoth") == 0, "the spawner's bison left as the layer came")
	var e := spawner.land.ecology(OPEN)
	_expect(e.cap_of("bison") == 0.0 and e.cap_of("mammoth") == 0.0 and float(e.pop.bison) == 0.0, "its open land holds none now")
	_expect(e.cap_of("horse") > 0.0 and e.cap_of("deer") > 0.0, "horses and deer still live there (strays and farm stock)")
	for i in 30:
		spawner._stock_square(OPEN, false)
	await _frames(2)
	_expect(_alive(spawner, "bison") == 0 and _alive(spawner, "mammoth") == 0, "a restock brings no bison (deer %d, horses %d)" %
			[_alive(spawner, "deer"), _alive(spawner, "horse")])
	var land := WildlifeLand.new()
	var none := true
	for sq: Vector2i in land.squares:
		var le: WildlifeEcology = land.squares[sq]
		if le.cap_of("bison") > 0.0 or le.cap_of("mammoth") > 0.0 or float(le.pop.mammoth) > 0.0:
			none = false
	_expect(none, "a land made with the layer on has no mammoths or bison in any square")
	land.ecology(OPEN).from_dict({"pop": {"bison": 30.0, "mammoth": 3.0, "deer": 9.0}})
	_expect(float(land.ecology(OPEN).pop.bison) == 0.0 and float(land.ecology(OPEN).pop.deer) == 9.0,
			"a saved land's bison come back as none (its deer as they were)")


# --- Applying again -----------------------------------------------------------------------------------------------------

func _test_again() -> void:
	var n := StoryLayer.layer_pieces("1757").size()
	var all := world.pieces().size()
	var again := StoryLayer.apply(level, "1757")
	await _frames(2)
	_expect(again == layer and again.placed == 0, "a second apply gives the same layer and builds nothing")
	_expect(StoryLayer.layer_pieces("1757").size() == n and world.pieces().size() == all, "no piece doubles (%d)" % n)
	var churches := 0
	var groves := 0
	for c in layer.get_children():
		if String(c.name).begins_with("Church_"):
			churches += 1
		if String(c.name).begins_with("Grove_"):
			groves += 1
	_expect(churches == 1 and groves == 1 and level.get_children().filter(func(x: Node) -> bool: return x is StoryLayer).size() == 1,
			"one church, one grove, one layer node")


# --- The save -----------------------------------------------------------------------------------------------------------

func _test_save() -> void:
	# a piece of the far farm burnt before the save (gone, as the fire takes it down)
	var gone := StoryLayer.farm_pieces("farm_ott").filter(func(p: BuiltPiece) -> bool: return p.type == "woodpile")
	_expect(gone.size() == 1, "the far farm has its woodpile")
	if gone.is_empty():
		return
	world.remove_piece(gone[0])
	await _frames(2)
	var n := StoryLayer.layer_pieces("1757").size()
	var all := world.pieces().size()
	var d: Variant = JSON.parse_string(JSON.stringify(SaveParts.save_building(level)))
	_expect(d is Dictionary and (d.get("story_layers", []) as Array).has("1757"), "the building part says the world has had the 1757 layer")
	var tagged := 0
	for e: Dictionary in (d as Dictionary).get("pieces", []):
		if e.has("layer"):
			tagged += 1
	_expect(tagged == n, "and tags its %d pieces" % n)
	SaveParts.load_building(level, d)
	await _frames(3)
	_expect(StoryLayer.layer_pieces("1757").size() == n and world.pieces().size() == all,
			"loaded, the layer's pieces come back once (%d of %d), tagged" % [StoryLayer.layer_pieces("1757").size(), n])
	_expect(StoryLayer.applied(world).has("1757"), "the loaded world knows it has the layer")
	var again := StoryLayer.apply(level, "1757")
	await _frames(2)
	_expect(again.placed == 0 and StoryLayer.layer_pieces("1757").size() == n, "apply after the load builds nothing again")
	_expect(StoryLayer.farm_pieces("farm_ott").filter(func(p: BuiltPiece) -> bool: return p.type == "woodpile").is_empty(),
			"the woodpile burnt before the save stays gone")
	_expect(StoryLayer.farm_pieces("rauch_farm").size() >= 25, "the Rauch farm is all there (%d pieces)" % StoryLayer.farm_pieces("rauch_farm").size())


# --- The raid's fire ----------------------------------------------------------------------------------------------------

func _test_burn() -> void:
	var farm := StoryLayer.farm_pieces("farm_brenner")
	var first: BuiltPiece = null
	for p: BuiltPiece in farm:
		if p.type == "wall_door":
			first = p
	_expect(first != null and fire.ignite(first), "a farm's door wall set alight catches")
	if first == null:
		return
	var spread := await _until(func() -> bool:
		var n := 0
		for p in farm:
			if is_instance_valid(p) and fire.is_burning(p):
				n += 1
		return n >= 3, 120.0)
	_expect(spread > 0.0, "the fire spreads from it to the walls round it (3 alight after %.0f s)" % spread)
	fire.ignite_area(StoryLayer.place("farm_brenner") + Vector3(0, 1, 0), 14.0)
	var down := await _until(func() -> bool:
		for p in farm:
			if is_instance_valid(p) and not (p as BuiltPiece).is_queued_for_deletion() and (p as BuiltPiece).is_inside_tree() \
					and (p as BuiltPiece).type != "hearth":
				return false
		return true, 600.0)
	var hearth_left := StoryLayer.farm_pieces("farm_brenner").filter(func(p: BuiltPiece) -> bool: return p.type == "hearth").size()
	_expect(down > 0.0 and hearth_left == 1, "the farm alight burns down in %.0f s, its stone hearth left standing" % down)
	_expect(fire.burned_count() >= farm.size() - 1, "%d of its pieces burnt to ruins" % fire.burned_count())
	fire.clear()


## Steps the fire until `cond` holds (its seconds) or `max_s` pass (-1).
func _until(cond: Callable, max_s: float) -> float:
	var t := 0.0
	var n := 0
	while t < max_s:
		fire.step(FireSpread.TICK_S)
		t += FireSpread.TICK_S
		n += 1
		if n % 8 == 0:
			await process_frame
		if cond.call():
			return t
	return -1.0


# --- Back to free play --------------------------------------------------------------------------------------------------

func _test_clear() -> void:
	StoryLayer.clear()
	var e := WildlifeLand.new().ecology(OPEN)
	_expect(StoryLayer.active_id() == "" and int(e.cap_of("bison")) == 40 and int(e.cap_of("mammoth")) == 4,
			"cleared, a new land has free play's numbers again")
