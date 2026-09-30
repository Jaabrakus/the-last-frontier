extends SceneTree
## Headless tests of building (scripts/building/, data/building/building.json):
##   data      every piece in the menu with a name and a cost, the costs, the take-down refund at Novice and
##             Master, the Building experience in gathering.json
##   geometry  every piece's mesh and colliders build; a notched corner, a shared floor edge and a roof end change
##             the look; the palisade stakes follow the ground
##   snap      sockets and attachments as numbers (a wall on a floor edge, the next wall in line and round a
##             corner, a post at a floor corner, a gable and a roof bay on a wall top, a hearth on a wall face,
##             the next floor, the next palisade section), the ground grid, the SAT box test
##   level     on the real level with the real input path: B (hands free), the wheel (the piece, not the weapon),
##             hold E builds a floor, four walls (window, door), two gables, a roof, a hearth: each where its
##             socket puts it, the pack paying exactly, Building experience; notched corners; R flips a wall;
##             validity (an occupied edge, a roof on the ground, a tree, a steep slope, the player standing
##             there, an empty pack); a palisade line with a corner and a gate; E opens the door and the player
##             walks in through the doorway, a wall stops them; take down (refused under a roof, the refund);
##             a weapon key ends build mode
##
##   Godot --headless --fixed-fps 120 --path . -s tests/building/test_building.gd -- --no-capture [only=data,geometry,snap,level]

const G := preload("res://scripts/building/build_geometry.gd")
## The cabin's floor centre (the flat clearing east of the fort) and the palisade line's first section.
const CABIN := Vector3(21.0, 0.0, 6.0)
const PAL := Vector3(21.0, 0.0, -6.0)

var failures := PackedStringArray()
var checks := 0
var only := ""
var report := {}
var player: FrontierPlayer
var mode: BuildMode


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	if _on("data"):
		_test_data()
	if _on("geometry"):
		_test_geometry()
	if _on("snap"):
		_test_snap()
	if _on("level"):
		await _test_level()
	print("REPORT ", JSON.stringify(report))
	if failures.is_empty():
		print("BUILDING TEST PASSED (%d checks)" % checks)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("BUILDING TEST FAILED (%d of %d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _on(part: String) -> bool:
	return only == "" or part in only.split(",")


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _near(a: Vector3, b: Vector3, eps := 0.02) -> bool:
	return a.distance_to(b) < eps


# --- Data -----------------------------------------------------------------------------------------------------

func _test_data() -> void:
	var d := BuildData.get_default()
	var want := {"floor": {"log": 4, "stone": 6}, "wall": {"log": 6}, "wall_window": {"log": 5}, "wall_door": {"log": 5},
			"post": {"log": 1}, "gable": {"log": 2}, "roof": {"log": 4}, "hearth": {"stone": 16}, "palisade": {"log": 8},
			"palisade_gate": {"log": 10},
			# the fort's parts (scripts/building/fort_pieces.gd)
			"walkway": {"log": 4}, "walkway_ramp": {"log": 5}, "ladder": {"log": 3}, "blockhouse": {"log": 40}, "flagpole": {"log": 4},
			# camp pieces (tests/building/test_campfire.gd)
			"campfire": {"stone": 6, "firewood": 4}, "lean_to": {"pole": 5, "branches": 10},
			# beds, racks and crafting stations (tests/survival_game/test_camp_stations.gd)
			"bough_bed": {"branches": 8, "pole": 2}, "drying_rack": {"pole": 6, "branches": 2},
			"pole_bed": {"pole": 4, "branches": 6, "deer_hide": 1}, "musket_rack": {"pole": 3, "log": 1},
			"spear_barrel": {"log": 1, "branches": 2}, "tanning_frame": {"pole": 4, "log": 1}, "alchemy_table": {"log": 2, "stone": 2},
			# the workbench, the stretching hoop, the storage chest (tests/survival_game/test_workshop.gd)
			"workbench": {"log": 2, "pole": 2}, "stretching_hoop": {"pole": 2, "branches": 4}, "storage_chest": {"log": 2},
			# the woodpile and the smokehouse (tests/survival_game/test_woodpile_smokehouse.gd)
			"woodpile": {"pole": 2, "branches": 2}, "smokehouse": {"log": 4, "pole": 4, "branches": 6},
			# the trap line's traps: what goes into them is set with E (tests/survival_game/test_traps.gd)
			"trap_steel": {}, "trap_snare": {}, "trap_deadfall": {},
			# the knapping stone: the start with nothing's first station (tests/forage/test_forage.gd has its materials)
			"work_stone": {},
			# the charcoal mound and the forge (tests/survival_game/test_bare.gd)
			"charcoal_mound": {"firewood": 8, "clay": 1}, "forge": {"stone": 10, "clay": 3, "log": 1, "rawhide": 1},
			# the baby's cradle (the household's), the boat stand (tests/boats/test_boat_stand.gd)
			"cradle": {"log": 2, "rawhide": 1}, "boat_stand": {"pole": 6, "log": 2}}
	# (and the two ways to close an opening cut in the palisade, PalisadeCuts: no pieces of their own)
	var fixes := {"opening_repair": {"log": 2}, "opening_cover": {"log": 1}}
	_check(d.order.size() == want.size() + fixes.size(), "the menu has the %d pieces and %d wall fixes (%d)" % [want.size(), fixes.size(), d.order.size()])
	for id: String in fixes:
		_check(d.order.has(id) and d.opening(id) != "" and d.cost(id) == fixes[id], "%s is a wall fix costing %s" % [id, fixes[id]])
	for id: String in want:
		_check(d.order.has(id), "%s is in the menu" % id)
		_check(d.cost(id) == want[id], "%s costs %s (%s)" % [id, want[id], d.cost(id)])
		_check((d.pieces[id] as Dictionary).has("name") and d.name_of(id) != "", "%s has a name (%s)" % [id, d.name_of(id)])
	_check(not d.free_standing("roof") and not d.free_standing("gable") and d.free_standing("wall") and d.free_standing("floor"),
			"roofs and gables need a wall; walls and floors stand on their own")
	_check(d.refund("wall", 0.0) == {"log": 3}, "a log wall gives 3 logs back at Novice (%s)" % d.refund("wall", 0.0))
	_check(d.refund("hearth", 0.0) == {"stone": 8}, "a hearth gives 8 stone back at Novice (%s)" % d.refund("hearth", 0.0))
	_check(d.refund("wall", 1.0) == {"log": 4}, "a log wall gives 4 logs back at Master (%s)" % d.refund("wall", 1.0))
	_check(d.refund("floor", 1.0) == {"log": 3, "stone": 4}, "a floor gives 3 logs and 4 stone back at Master (%s)" % d.refund("floor", 1.0))
	_check(d.refund("post", 0.0) == {"log": 1}, "a post gives its one log back (%s)" % d.refund("post", 0.0))
	_check(BuildData.cost_text({"log": 4, "stone": 6}) == "4 logs, 6 stone" and BuildData.cost_text({"log": 1}) == "1 log",
			"cost text: %s / %s" % [BuildData.cost_text({"log": 4, "stone": 6}), BuildData.cost_text({"log": 1})])
	var s := GatherSkills.new()
	_check(s.xp("building", "piece") > 0.0 and s.xp("building", "log") > 0.0 and s.xp("building", "stone") > 0.0,
			"Building experience per piece, log and stone in gathering.json")
	# pacing: cabins of 10 pieces (about 38 logs and 22 stone) to Apprentice
	var cabins := 0
	while s.level("building") < 20 and cabins < 100:
		for id: String in ["floor", "wall", "wall", "wall_window", "wall_door", "gable", "gable", "roof", "hearth", "post"]:
			var c := d.cost(id)
			s.award("building", s.xp("building", "piece") + s.xp("building", "log") * int(c.get("log", 0)) + s.xp("building", "stone") * int(c.get("stone", 0)))
		cabins += 1
	report["cabins_to_apprentice"] = cabins
	_check(cabins >= 2 and cabins <= 8, "Apprentice builder after %d one-room cabins (want 2-8)" % cabins)


# --- Geometry -------------------------------------------------------------------------------------------------

func _test_geometry() -> void:
	var d := BuildData.get_default()
	for id in d.order:
		if d.opening(id) != "":
			continue
		var ctx := {}
		if id == "palisade":
			ctx = {"gy": [0.0, 0.2], "gmin": 0.0}
		var m := BuildGeometry.mesh(id, 0, ctx)
		_check(m != null and m.get_surface_count() > 0, "%s has a mesh (%d surfaces)" % [id, m.get_surface_count() if m else 0])
		if id in ["musket_rack", "spear_barrel"]:
			continue                               # the racks collide as their WeaponRack (BuiltPiece.dress)
		_check(not BuildGeometry.colliders(id, ctx).is_empty(), "%s has colliders" % id)
	var free := BuildGeometry.mesh("wall", 0, {"p": 0, "e0": "free", "e1": "free", "g": true})
	var corner := BuildGeometry.mesh("wall", 0, {"p": 0, "e0": "corner", "e1": "corner", "g": true})
	var inline := BuildGeometry.mesh("wall", 0, {"p": 0, "e0": "inline", "e1": "inline", "g": false})
	_check(corner != free and corner.get_aabb().size.x > free.get_aabb().size.x + 0.5,
			"notched corners stick out past the wall's ends (%.2f vs %.2f m)" % [corner.get_aabb().size.x, free.get_aabb().size.x])
	_check(inline.get_aabb().size.x <= G.L + 0.02, "a wall continued in line ends at its 3 m (%.2f)" % inline.get_aabb().size.x)
	_check(free.get_aabb().position.y < -G.FOOTING + 0.02 and inline.get_aabb().position.y > -0.05,
			"a wall on the ground has a footing, one on a floor none")
	var cc := BuildGeometry.colliders("wall", {"p": 0, "e0": "corner", "e1": "free", "g": false})
	_check(cc.size() == 2, "a notched corner adds a collider for its log ends (%d)" % cc.size())
	var door := BuildGeometry.colliders("wall_door", {"g": false})
	var gap := true
	for c: Array in door:
		var sh: BoxShape3D = c[0]
		var t: Transform3D = c[1]
		# nothing solid across the opening below the door head
		if absf(t.origin.x) < 0.4 and t.origin.y - sh.size.y * 0.5 < 1.9:
			gap = false
	_check(gap, "the door wall leaves the doorway open (the leaf is its own body)")
	var win := BuildGeometry.colliders("wall_window", {"g": false})
	_check(win.size() == 4, "the window wall is four boxes round the opening (%d)" % win.size())
	var end_over := BuildGeometry.mesh("roof", 0, {"o0": 0.45, "o1": 0.45})
	var mid := BuildGeometry.mesh("roof", 0, {"o0": 0.0, "o1": 0.0})
	_check(end_over.get_aabb().size.x > mid.get_aabb().size.x + 0.8, "a roof end overhangs, a bay in the middle does not (%.2f vs %.2f)"
			% [end_over.get_aabb().size.x, mid.get_aabb().size.x])
	var floor_a := BuildGeometry.mesh("floor", 0, {"sill": [true, true, true, true], "foot": [true, true, true, true]})
	var floor_b := BuildGeometry.mesh("floor", 0, {"sill": [false, true, true, true], "foot": [false, true, true, true]})
	_check(floor_a != floor_b, "a shared floor edge changes the floor's look")
	var flat := BuildGeometry.stake_transforms(PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0]), 0)
	var slope := BuildGeometry.stake_transforms(PackedFloat32Array([0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]), 0)
	_check(flat.size() == G.STAKES and absf((slope[7][1] as Transform3D).origin.y - (flat[7][1] as Transform3D).origin.y - 0.7) < 0.01,
			"palisade stakes follow the ground under each one")
	# the gable's top follows the roof's underside
	var top := G.roof_underside(0.0)
	var gab := BuildGeometry.mesh("gable", 0, {})
	_check(absf(gab.get_aabb().end.y - top) < 0.03, "the gable's peak sits under the roof's ridge (%.2f vs %.2f)" % [gab.get_aabb().end.y, top])
	report["ridge_over_wall_top"] = snappedf(top, 0.01)


# --- Snapping as numbers --------------------------------------------------------------------------------------

func _test_snap() -> void:
	var floor_xf := Transform3D(Basis(), Vector3(10, 2, 5))
	var sockets := _sockets("floor", floor_xf)
	var edge := _socket(sockets, "edge", Vector3(10, 2 + G.FLOOR_H, 6.5))
	_check(_ok(edge), "a floor has an edge socket at the middle of its +Z edge, on the floor's top")
	if _ok(edge):
		var w: Transform3D = edge * BuildSnap.attach("wall").edge[0]
		_check(_near(w.origin, Vector3(10, 2.35, 6.5)) and _near(w.basis.z, Vector3.BACK, 0.01) and _near(w.basis.x, Vector3.RIGHT, 0.01),
				"a wall on the +Z edge: along X, outside face out (%s)" % w)
	var e_x := _socket(sockets, "edge", Vector3(11.5, 2 + G.FLOOR_H, 5))
	if _ok(e_x):
		var w2: Transform3D = e_x * BuildSnap.attach("wall").edge[0]
		_check(_near(w2.basis.z, Vector3.RIGHT, 0.01) and _near(w2.origin, Vector3(11.5, 2.35, 5)), "a wall on the +X edge faces +X (%s)" % w2)
	_check(_ok(_socket(sockets, "corner", Vector3(11.5, 2.35, 6.5))), "a floor corner socket at (+1.5, top, +1.5)")
	var side := _socket(sockets, "floor_side", Vector3(11.5, 2, 5))
	if _ok(side):
		_check(_near((side * BuildSnap.attach("floor").floor_side[0]).origin, Vector3(13, 2, 5)), "the next floor goes 3 m over, level")
	# a wall along X at the origin
	var wall_xf := Transform3D(Basis(), Vector3(0, 0, 0))
	var ws := _sockets("wall", wall_xf)
	var end := _socket(ws, "wall_end", Vector3(1.5, 0, 0))
	if _ok(end):
		var offs: Array = BuildSnap.attach("wall").wall_end
		var inl: Transform3D = end * (offs[0] as Transform3D)
		_check(_near(inl.origin, Vector3(3, 0, 0)) and _near(inl.basis.x, Vector3.RIGHT, 0.01) and _near(inl.basis.z, Vector3.BACK, 0.01),
				"the next wall in line: 3 m on, same facing (%s)" % inl)
		var rnd: Transform3D = end * (offs[1] as Transform3D)
		_check(_near(rnd.origin, Vector3(1.5, 0, -1.5)) and _near(rnd.basis.x, Vector3.FORWARD, 0.01) and _near(rnd.basis.z, Vector3.RIGHT, 0.01),
				"round the corner: from the end at right angles, its outside facing out (%s)" % rnd)
		var post: Transform3D = end * BuildSnap.attach("post").wall_end[0]
		_check(_near(post.origin, Vector3(1.5, 0, 0)), "a post goes on a wall's end")
	var top := _socket(ws, "wall_top", Vector3(0, G.WALL_H, 0))
	if _ok(top):
		var roofs: Array = BuildSnap.attach("roof").wall_top
		var r0: Transform3D = top * (roofs[0] as Transform3D)
		_check(_near(r0.origin, Vector3(0, G.WALL_H, 1.5)) and _near(r0.basis.x, Vector3.RIGHT, 0.01), "a roof bay 1.5 m in from the wall, ridge along it")
		_check(_near((top * BuildSnap.attach("gable").wall_top[0]).origin, Vector3(0, G.WALL_H, 0)), "a gable on the wall's top")
	var face := _socket(ws, "wall_face", Vector3(0, 0, -G.T * 0.5))
	if _ok(face):
		var h: Transform3D = face * BuildSnap.attach("hearth").wall_face[0]
		_check(_near(h.basis.z, Vector3.FORWARD, 0.01), "a hearth on the wall's back face opens away from it")
	var ps := _sockets("palisade", Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 1, 0)))
	var pe := _socket(ps, "pal_end", Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 1, 0)) * Vector3(1.5, 0, 0))
	if _ok(pe):
		var n: Transform3D = pe * (BuildSnap.attach("palisade").pal_end[0] as Transform3D)
		_check(_near(n.origin, Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 1, 0)) * Vector3(3, 0, 0)), "the next palisade section in line")
	# the ground grid and facing
	var fx := BuildSnap.free_xf(Vector3(3.13, 0.4, -2.87), deg_to_rad(37.0), 1, 0.25, deg_to_rad(15.0))
	_check(_near(fx.origin, Vector3(3.25, 0.4, -2.75)), "the ground grid is 0.25 m (%s)" % fx.origin)
	_check(absf(wrapf(fx.basis.get_euler().y - deg_to_rad(120.0), -PI, PI)) < 0.001, "facing in 15 degree steps, R a quarter turn (%.1f)"
			% rad_to_deg(fx.basis.get_euler().y))
	# SAT
	var a := Transform3D(Basis(), Vector3.ZERO)
	_check(BuildSnap.obb_overlap(a, Vector3.ONE, Transform3D(Basis(Vector3.UP, 0.7), Vector3(1.6, 0, 0)), Vector3(0.5, 0.5, 0.5)),
			"SAT: overlapping boxes")
	_check(not BuildSnap.obb_overlap(a, Vector3.ONE, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(2.8, 0, 0)), Vector3(1, 1, 1)),
			"SAT: a turned box clear of the other")
	# walls meeting at a corner do not overlap; the same wall twice does
	var ia: Array = BuildSnap.inner_local("wall")[0]
	var b_xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.5, 0, -1.5))
	_check(not BuildSnap.obb_overlap(ia[0], ia[1], b_xf * (ia[0] as Transform3D), ia[1]), "walls at a corner are not in each other's way")
	_check(G.parity_of(0.0) != G.parity_of(PI * 0.5) and G.parity_of(PI) == G.parity_of(0.0) and G.parity_of(-PI * 0.5) == G.parity_of(PI * 0.5),
			"walls at right angles lay their logs half a course apart")


func _sockets(type: String, xf: Transform3D) -> Array:
	var out: Array = []
	for s: Array in BuildSnap.sockets_local(type):
		out.append([s[0], xf * (s[1] as Transform3D)])
	return out


func _ok(t: Transform3D) -> bool:
	return t != Transform3D()


func _socket(list: Array, kind: String, at: Vector3) -> Transform3D:
	for s: Array in list:
		if String(s[0]) == kind and _near((s[1] as Transform3D).origin, at):
			return s[1]
	return Transform3D()


# --- On the level ---------------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _tap(action: StringName, frames := 3) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)


## Hold E past the placement delay and let go (builds what the ghost shows).
func _hold_e() -> void:
	Input.action_press(ThrownPickup.INTERACT)
	await _frames(int(ceil(PlayerInteractor.HOLD_S * 120.0)) + 12)
	Input.action_release(ThrownPickup.INTERACT)
	await _frames(3)


func _stand(at: Vector3, face: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = atan2(-face.x, -face.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-10.0)


func _give(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	player.inventory_pack = inv.pack.duplicate(true)


func _set_pack(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	inv.take(kind, inv.pack_count(kind))
	inv.add(kind, n)
	player.inventory_pack = inv.pack.duplicate(true)


## Aims at `p`, waits for the placement, builds it with E. Returns the new piece (null when none was built).
func _build(type: String, p: Vector3, want_kind := "") -> BuiltPiece:
	mode.select_type(type)
	mode.aim_at = p
	await _frames(3)
	var world := BuildWorld.of(self, false)
	var before := world.pieces().size() if world else 0
	if want_kind != "":
		_check(String(mode.cand.get("kind", "?")) == want_kind, "%s at %s snaps to a %s socket (%s, %s)" % [type, p, want_kind,
				mode.cand.get("kind", "none"), mode.verdict.get("reason", "")])
	if not bool(mode.verdict.get("ok", false)):
		_check(false, "%s at %s can be built (%s)" % [type, p, mode.verdict.get("reason", "?")])
		return null
	await _hold_e()
	world = BuildWorld.of(self, false)
	if world == null or world.pieces().size() != before + 1:
		_check(false, "hold E built the %s" % type)
		return null
	var newest: BuiltPiece = null
	for q in world.pieces():
		if newest == null or q.piece_id > newest.piece_id:
			newest = q
	return newest


func _test_level() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	_check(player != null, "level loads with a player")
	if player == null:
		return
	player.ignore_mouse_capture = true
	await _frames(40)
	mode = player.building
	_check(mode != null, "the player has BuildMode")
	if mode == null:
		return
	_check(InputMap.has_action(BuildMode.ACTION) and (InputMap.action_get_events(BuildMode.ACTION)[0] as InputEventKey).physical_keycode == KEY_B,
			"B is the build key")
	_check(not LoadoutInput.collisions().has(KEY_B), "B is bound to nothing else (%s)" % [LoadoutInput.collisions()])
	_set_pack("log", 120)
	_set_pack("stone", 60)
	_stand(CABIN + Vector3(4.0, 0, 3.5), Vector3.LEFT)
	await _frames(5)
	# B: build mode, hands free
	var weapon_before := player.weapon_key
	await _tap(BuildMode.ACTION)
	_check(mode.active and player.hands_free, "B turns build mode on and puts the weapon away (active %s, hands free %s)" % [mode.active, player.hands_free])
	# the wheel picks the piece, not the weapon
	var i0 := mode.index
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await _frames(3)
	_check(mode.index == i0 + 1 and player.weapon_key == weapon_before, "the wheel chooses the next piece and keeps the weapon (%d -> %d, %s)"
			% [i0, mode.index, player.weapon_key])
	await _level_cabin()
	await _level_validity()
	await _level_palisade()
	await _level_fort()
	await _level_walk()
	await _level_take_down()
	# a weapon key ends build mode
	var key := InputEventAction.new()
	key.action = &"weapon_1"
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(4)
	key = InputEventAction.new()
	key.action = &"weapon_1"
	key.pressed = false
	Input.parse_input_event(key)
	var left := await _until(func() -> bool: return not mode.active, 240)
	_check(left, "a weapon key ends build mode")
	await _tap(BuildMode.ACTION)
	await _frames(4)


var _floor: BuiltPiece
var _walls := {}
## The palisade section _level_palisade built out on the clearing (the fort's own are stamped: FortPlan).
var _first_pal: BuiltPiece


func _level_cabin() -> void:
	var sk := mode.skills()
	var xp0 := sk.points_of("building") if sk else 0.0
	var logs0 := mode.pack_count("log")
	var stone0 := mode.pack_count("stone")
	# the floor on the ground: its top FLOOR_H over the highest ground under it
	_floor = await _build("floor", CABIN)
	_check(_floor != null, "a floor is built on the ground")
	if _floor == null:
		return
	_check(mode.pack_count("log") == logs0 - 4 and mode.pack_count("stone") == stone0 - 6,
			"the floor took 4 logs and 6 stone from the pack (%d, %d)" % [logs0 - mode.pack_count("log"), stone0 - mode.pack_count("stone")])
	_check(sk == null or sk.points_of("building") > xp0, "building gives Building experience (%.3f -> %.3f)" % [xp0, sk.points_of("building") if sk else 0.0])
	var fo := _floor.global_position
	_check(absf(fo.x - CABIN.x) < 0.13 and absf(fo.z - CABIN.z) < 0.13, "the floor sits on the ground grid at the crosshair (%s)" % fo)
	var top := fo.y + G.FLOOR_H
	# walls on its four edges: +X log wall, -X window, +Z door, -Z log wall
	var spec := [["wall", Vector3(1.3, 0, 0), "+x"], ["wall_window", Vector3(-1.3, 0, 0), "-x"], ["wall_door", Vector3(0, 0, 1.3), "+z"],
			["wall", Vector3(0, 0, -1.3), "-z"]]
	var logs1 := mode.pack_count("log")
	for s: Array in spec:
		var w := await _build(String(s[0]), fo + (s[1] as Vector3) + Vector3(0, G.FLOOR_H, 0), "edge")
		if w == null:
			continue
		_walls[s[2]] = w
		var want := fo + (s[1] as Vector3) / 1.3 * 1.5 + Vector3(0, G.FLOOR_H, 0)
		_check(_near(w.global_position, want, 0.01), "the %s stands on the floor's %s edge (%s, want %s)" % [s[0], s[2], w.global_position, want])
		_check(_near(w.global_transform.basis.z, (s[1] as Vector3).normalized(), 0.01), "its outside faces out (%s)" % w.global_transform.basis.z)
		_check(not w.grounded and w.supports.has(_floor.piece_id), "it rests on the floor")
	_check(logs1 - mode.pack_count("log") == 6 + 5 + 5 + 6, "the four walls took 22 logs (%d)" % (logs1 - mode.pack_count("log")))
	# every corner is notched now (neighbours re-dressed)
	var corners := 0
	for k: String in _walls:
		var w: BuiltPiece = _walls[k]
		if String(w.ctx.get("e0", "")) == "corner" and String(w.ctx.get("e1", "")) == "corner":
			corners += 1
	_check(corners == 4, "all four walls show notched corners at both ends (%d)" % corners)
	_check(_walls.has("+x") and _walls.has("+z") and int((_walls["+x"] as BuiltPiece).ctx.p) != int((_walls["+z"] as BuiltPiece).ctx.p),
			"walls at right angles alternate their courses")
	# R: one press is one step, and on a socket it turns a wall end for end
	var st0 := mode.steps
	await _tap(&"reload")
	_check(mode.steps == st0 + 1, "R counts a turn (%d -> %d)" % [st0, mode.steps])
	var world := BuildWorld.of(self)
	var aim_x := fo + Vector3(1.3, G.FLOOR_H, 0)
	var c0: Array = BuildSnap.candidates("wall", world, aim_x, mode.data.snap_radius, false)
	var c1: Array = BuildSnap.candidates("wall", world, aim_x, mode.data.snap_radius, true)
	_check(not c0.is_empty() and not c1.is_empty() and _near((c0[0].xf as Transform3D).origin, (c1[0].xf as Transform3D).origin, 0.01)
			and (c0[0].xf as Transform3D).basis.z.dot((c1[0].xf as Transform3D).basis.z) < -0.99, "R turns the snapped wall end for end")
	# the occupied edge
	if _walls.has("+x"):
		var occ := BuildSnap.check("wall", {"xf": (_walls["+x"] as BuiltPiece).global_transform, "kind": "edge", "grounded": false}, world,
				player.get_world_3d().direct_space_state, {"log": 99}, mode.data)
		_check(not occ.ok and String(occ.reason).contains("in the way"), "a second wall on an occupied edge is refused (%s)" % occ.reason)
	mode.steps = 0
	# gables on the X walls, a roof along X over the Z walls
	for k: String in ["+x", "-x"]:
		if not _walls.has(k):
			continue
		var wt := (_walls[k] as BuiltPiece).global_transform * Vector3(0, G.WALL_H, 0)
		var g := await _build("gable", wt + Vector3(0, 0.01, 0), "wall_top")
		if g:
			_check(_near(g.global_position, wt, 0.01), "the gable sits on the %s wall's top" % k)
	var roof := await _build("roof", fo + Vector3(0, G.FLOOR_H, 0), "wall_top")
	if roof:
		_check(_near(roof.global_position, fo + Vector3(0, G.FLOOR_H + G.WALL_H, 0), 0.01), "the roof bay is over the room (%s)" % roof.global_position)
		_check(absf(roof.global_transform.basis.x.normalized().dot(Vector3.RIGHT)) > 0.99, "its ridge runs between the gables")
		_check(float(roof.ctx.o0) > 0.3 and float(roof.ctx.o1) > 0.3, "one bay: both ends overhang the gables")
	# a hearth against the +X (gable end) wall, outside
	if _walls.has("+x"):
		var h := await _build("hearth", fo + Vector3(2.3, 0, 0), "wall_face")
		if h:
			_check(_near(h.global_transform.basis.z, Vector3.RIGHT, 0.01) and absf(h.global_position.x - (fo.x + 1.65)) < 0.01,
					"the hearth backs onto the wall and opens away from it (%s)" % h.global_position)
	report["cabin_pieces"] = BuildWorld.of(self).pieces().size()
	report["building_points"] = snappedf(sk.points_of("building"), 0.01) if sk else 0.0
	_check(top > 0.0, "the floor top is above the ground")


func _level_validity() -> void:
	_stand(CABIN + Vector3(0, 0, 12.0), Vector3.FORWARD)
	await _frames(4)
	var world := BuildWorld.of(self)
	var space := player.get_world_3d().direct_space_state
	var d := mode.data
	var have := {"log": 99, "stone": 99}
	# a roof on the bare ground
	mode.select_type("roof")
	mode.aim_at = CABIN + Vector3(0, 0, 9.0)
	await _frames(3)
	_check(not bool(mode.verdict.get("ok", true)) and String(mode.verdict.get("reason", "")).contains("wall"),
			"a roof on the bare ground needs a wall (%s)" % mode.verdict.get("reason", ""))
	# a tree in the way
	var h := VegHarvest.find(self)
	var tree_at := Vector3.INF
	if h:
		for i in h.lay.tree_pos.size():
			var p: Vector3 = h.lay.tree_pos[i]
			if h.lay.tree_collider[i] != 0 and int(h.lay.tree_kind[i]) < VegHarvest.Assets.CANOPY_COUNT and p.distance_to(CABIN) < 90.0:
				tree_at = p
				break
	_check(tree_at != Vector3.INF, "a tree to build on")
	if tree_at != Vector3.INF:
		var v := BuildSnap.check("floor", {"xf": Transform3D(Basis(), tree_at), "kind": "", "grounded": true}, world, space, have, d)
		var v2 := BuildSnap.check("wall", {"xf": Transform3D(Basis(), tree_at), "kind": "", "grounded": true}, world, space, have, d)
		_check(not v.ok and not v2.ok and (String(v.reason).contains("tree") or String(v2.reason).contains("tree")),
				"a floor or wall on a tree trunk is refused (%s / %s)" % [v.reason, v2.reason])
	# a steep slope
	var steep := _find_steep()
	_check(steep != Vector3.INF, "a steep spot to try")
	if steep != Vector3.INF:
		var v3 := BuildSnap.check("floor", {"xf": Transform3D(Basis(), steep), "kind": "", "grounded": true}, world, space, have, d)
		_check(not v3.ok and String(v3.reason).to_lower().contains("steep"), "a floor on a steep slope is refused (%s)" % v3.reason)
		report["steep_at"] = str(steep)
	# the player standing there
	var here := player.global_position
	var v4 := BuildSnap.check("wall", {"xf": Transform3D(Basis(), here), "kind": "", "grounded": true}, world, space, have, d)
	_check(not v4.ok and String(v4.reason).contains("standing"), "a wall through the player is refused (%s)" % v4.reason)
	# an empty pack
	var clear := CABIN + Vector3(0, 0, 9.0)
	var v5 := BuildSnap.check("wall", {"xf": Transform3D(Basis(), clear), "kind": "", "grounded": true}, world, space, {"log": 2}, d)
	_check(not v5.ok and String(v5.reason) == "Needs 4 more logs", "a wall with 2 logs in the pack: \"%s\"" % v5.reason)
	var v6 := BuildSnap.check("wall", {"xf": Transform3D(Basis(), clear), "kind": "", "grounded": true}, world, space, have, d)
	_check(v6.ok, "the same wall with logs enough can be built (%s)" % v6.reason)
	# the pack really empty: the ghost says so and E builds nothing
	var logs := mode.pack_count("log")
	_set_pack("log", 1)
	mode.select_type("wall")
	mode.aim_at = clear
	await _frames(3)
	var n0 := world.pieces().size()
	await _hold_e()
	_check(world.pieces().size() == n0 and String(mode.verdict.get("reason", "")).contains("more logs"),
			"with one log E builds no wall (%s)" % mode.verdict.get("reason", ""))
	_set_pack("log", logs)


## A spot outside the flat zones where the ground drops more than a floor's footing over its 3 m.
func _find_steep() -> Vector3:
	for r in range(40, 200, 6):
		for k in 48:
			var a := TAU * k / 48.0
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if FrontierTerrain.in_flat_zone(p.x, p.z):
				continue
			var lo := INF
			var hi := -INF
			for sx: float in [-1.25, 0.0, 1.25]:
				for sz: float in [-1.25, 0.0, 1.25]:
					var y := FrontierTerrain.height_at(p.x + sx, p.z + sz)
					lo = minf(lo, y)
					hi = maxf(hi, y)
			if hi - lo > 1.05 and hi - lo < 3.0:
				p.y = FrontierTerrain.height_at(p.x, p.z)
				return p
	return Vector3.INF


func _level_palisade() -> void:
	_stand(PAL + Vector3(1.5, 0, 3.0), Vector3.FORWARD)
	await _frames(4)
	var logs0 := mode.pack_count("log")
	var first := await _build("palisade", PAL)
	_check(first != null, "a palisade section on the ground")
	if first == null:
		return
	_first_pal = first
	var fx := first.global_transform
	_check(absf(fx.basis.x.normalized().dot(Vector3.RIGHT)) > 0.99, "it runs across the view (the camera looks along -Z)")
	_check(first.ground.size() == G.STAKES, "each stake has its ground height (%d)" % first.ground.size())
	var second := await _build("palisade", fx * Vector3(3.2, 0, 0), "pal_end")
	if second:
		_check(_near(second.global_position * Vector3(1, 0, 1), (fx * Vector3(3, 0, 0)) * Vector3(1, 0, 1), 0.02),
				"the next section follows on in line")
	var corner_at := (second.global_transform if second else fx) * Vector3(1.5, 0, -1.6)
	var third := await _build("palisade", corner_at, "pal_end")
	if third:
		_check(absf(third.global_transform.basis.x.normalized().dot(fx.basis.z.normalized())) > 0.99, "a section round the corner")
	var gate := await _build("palisade_gate", fx * Vector3(-3.2, 0, 0), "pal_end")
	_check(gate != null and gate.door != null, "a gate in line at the other end, with its leaves")
	if gate:
		_check(gate.global_transform.basis.z.dot(fx.basis.z) > 0.99, "off the line's other end the gate faces the same way (its inside with the line's)")
	_check(logs0 - mode.pack_count("log") == 8 * 3 + 10, "three sections and a gate took 34 logs (%d)" % (logs0 - mode.pack_count("log")))
	if gate and gate.door:
		gate.door.interact(player)
		var opened := await _until(func() -> bool: return gate.door.swing() >= 1.0, 240)
		_check(opened, "the gate swings open")
		var blocked := false
		var mid := gate.global_transform * Vector3(0.3, 1.2, 0)
		var q := PhysicsRayQueryParameters3D.create(mid + gate.global_transform.basis.z * 1.5, mid - gate.global_transform.basis.z * 1.5)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		blocked = not hit.is_empty()
		_check(not blocked, "nothing stands in the open gateway")
		gate.door.interact(player)
		var shut := await _until(func() -> bool: return gate.door.swing() <= 0.0, 240)
		hit = player.get_world_3d().direct_space_state.intersect_ray(q)
		_check(shut and not hit.is_empty(), "the shut gate closes the gateway")


## The fort's own parts (FortPieces): a firing step on a palisade's inside, the next in line, a ramp and a ladder at its
## open edge, a blockhouse and a flag pole on the ground.
func _level_fort() -> void:
	var world := BuildWorld.of(self)
	var pal := _first_pal
	_check(pal != null and is_instance_valid(pal), "a palisade section to build the firing step on")
	if pal == null:
		return
	var fx := pal.global_transform
	_set_pack("log", 300)
	_stand(fx * Vector3(0, 0, -5.5), fx.basis.z)
	await _frames(4)
	var logs0 := mode.pack_count("log")
	var w1 := await _build("walkway", fx * Vector3(0, 0, -1.0), "pal_inside")
	_check(w1 != null, "a firing step snaps to a palisade's inside")
	if w1 == null:
		return
	var back := w1.global_transform * Vector3(0, 0, -0.8)
	var face := fx * Vector3(0, 0, -0.2)
	_check(_near(Vector3(back.x, 0, back.z), Vector3(face.x, 0, face.z), 0.05), "its back edge lies against the palisade's inside face (%s, %s)" % [back, face])
	_check(w1.global_transform.basis.z.dot(fx.basis.z) < -0.99, "its open edge faces into the fort")
	var w2 := await _build("walkway", w1.global_transform * Vector3(3.1, 0, 0))
	_check(w2 != null and _near(w2.global_position * Vector3(1, 0, 1), (w1.global_transform * Vector3(3.0, 0, 0)) * Vector3(1, 0, 1), 0.05),
			"the next firing step follows on in line")
	_stand(w1.global_transform * Vector3(5.0, 0, 4.0), w1.global_transform.basis.x)
	await _frames(4)
	var ramp := await _build("walkway_ramp", w1.global_transform * Vector3(0, 0, 0.8 + FortPieces.RAMP_RUN * 0.5), "walk_front")
	_check(ramp != null, "a ramp snaps to the open edge")
	if ramp:
		var top := ramp.global_transform * Vector3(0, FortPieces.WALK_TOP, -FortPieces.RAMP_RUN * 0.5)
		var deck := w1.global_transform * Vector3(0, FortPieces.WALK_TOP, 0.8)
		_check(absf(top.y - deck.y) < 0.4 and Vector2(top.x - deck.x, top.z - deck.z).length() < 0.1, "its top meets the deck's edge (%s, %s)" % [top, deck])
	var lad: BuiltPiece = null
	if w2:
		lad = await _build("ladder", w2.global_transform * Vector3(0, 0, 0.9), "walk_front")
		_check(lad != null and lad.get_node_or_null("Ladder") is TravLadder, "a ladder with its climb marker snaps to the open edge")
	# a person can walk up the ramp onto the deck
	if ramp and w1:
		var up := ramp.global_transform * Vector3(0, 0, FortPieces.RAMP_RUN * 0.5 + 1.0)
		var to := w1.global_transform * Vector3(0, 0, 0.0) - up
		_stand(up, Vector3(to.x, 0, to.z).normalized())
		await _frames(10)
		Input.action_press(&"move_forward")
		await _frames(420)
		Input.action_release(&"move_forward")
		await _frames(20)
		_check(player.global_position.y > w1.global_position.y + FortPieces.WALK_TOP - 0.4,
				"the player walked up the ramp onto the firing step (y %.2f, deck at %.2f)" % [player.global_position.y, w1.global_position.y + FortPieces.WALK_TOP])
	# the blockhouse and the flag pole on open ground
	var spot := fx * Vector3(0, 0, -16.0)
	_stand(spot + fx.basis.z * 6.0, -fx.basis.z)
	await _frames(4)
	var bh := await _build("blockhouse", spot)
	_check(bh != null, "a blockhouse on open ground")
	# (its lower storey is hollow with a hung door: FortPieces.HOLLOW)
	_check(bh != null and bh.door != null and not bh.door.is_open, "the blockhouse hangs a door in its doorway")
	if bh and bh.door:
		var doorway := bh.global_transform * Vector3(1.2, 1.0, 2.25)
		var qd := PhysicsRayQueryParameters3D.create(doorway + bh.global_transform.basis.z * 1.0, doorway - bh.global_transform.basis.z * 1.0)
		_check(not player.get_world_3d().direct_space_state.intersect_ray(qd).is_empty(), "a shut blockhouse door stops a ray through the doorway")
		bh.door.set_open(true, true)
		await _frames(4)
		_check(player.get_world_3d().direct_space_state.intersect_ray(qd).is_empty(), "an open one lets it through")
		var qw := PhysicsRayQueryParameters3D.create(bh.global_transform * Vector3(0, 1.0, 2.6), bh.global_transform * Vector3(0, 1.0, -2.6))
		_check(not player.get_world_3d().direct_space_state.intersect_ray(qw).is_empty(), "the walls stop a ray elsewhere")
	var flag_at := fx * Vector3(9.0, 0, -8.0)
	_stand(flag_at + fx.basis.z * 3.0, -fx.basis.z)
	await _frames(4)
	var flag := await _build("flagpole", flag_at)
	_check(flag != null and flag.get_child_count() > 0, "a flag pole")
	if flag:
		var cloth := false
		for c in flag.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("Part"):
				cloth = true
		_check(cloth, "the pole flies a flag")
	var spent := logs0 - mode.pack_count("log")
	var want := 4 + 4 + (5 if ramp else 0) + (3 if lad else 0) + (40 if bh else 0) + (4 if flag else 0)
	_check(spent == want, "the fort pieces took %d logs (%d)" % [want, spent])


func _level_walk() -> void:
	if _floor == null or not _walls.has("+z") or not _walls.has("+x"):
		_check(false, "the cabin is there to walk into")
		return
	var fo := _floor.global_position
	var door: BuiltPiece = _walls["+z"]
	_check(door.door != null and not door.door.is_open, "the door hangs shut")
	# shut, the door stops the player
	_stand(fo + Vector3(0, 0, 3.0), Vector3.FORWARD)
	await _frames(6)
	Input.action_press(&"move_forward")
	await _frames(150)
	Input.action_release(&"move_forward")
	await _frames(20)
	_check(player.global_position.z > fo.z + 1.5, "the shut door stops the player (z %.2f, door at %.2f)" % [player.global_position.z, fo.z + 1.5])
	# E opens it
	_stand(fo + Vector3(0, 0, 2.6), Vector3.FORWARD)
	mode.select_type("wall")
	await _frames(8)
	var tgt: Node = player.interactor.target
	_check(tgt == door.door, "E's target in front of the door is the door (%s)" % [tgt])
	await _tap(ThrownPickup.INTERACT)
	var opened := await _until(func() -> bool: return door.door.swing() >= 1.0, 240)
	_check(door.door.is_open and opened, "a tap of E opens the door")
	# walk in
	Input.action_press(&"move_forward")
	await _frames(240)
	Input.action_release(&"move_forward")
	await _frames(30)
	var p := player.global_position
	var inside := absf(p.x - fo.x) < 1.3 and absf(p.z - fo.z) < 1.3
	_check(inside and p.y > fo.y + G.FLOOR_H - 0.1, "the player walked in through the doorway onto the floor (%s, floor at %s)" % [p, fo])
	report["walked_in_to"] = str(p - fo)
	# a wall stops them
	_stand(fo + Vector3(0.3, 0, -3.2), Vector3.BACK)
	await _frames(6)
	Input.action_press(&"move_forward")
	await _frames(180)
	Input.action_release(&"move_forward")
	await _frames(20)
	_check(player.global_position.z < fo.z - 1.5 - 0.2, "the log wall stops the player outside (z %.2f, wall face at %.2f)"
			% [player.global_position.z, fo.z - 1.65])
	# shut the door behind
	door.door.set_open(false, true)


func _level_take_down() -> void:
	var world := BuildWorld.of(self)
	if not _walls.has("+z") or _floor == null:
		return
	var fo := _floor.global_position
	_stand(fo + Vector3(0, 0, 5.0), Vector3.FORWARD)
	mode.select(mode.data.order.size())
	_check(mode.taking_down(), "the last entry is Take down")
	# the door wall carries the roof: refused
	var wall: BuiltPiece = _walls["+z"]
	mode.aim_at = wall.global_transform * Vector3(-1.0, 1.0, 0.0)
	mode.aim_from = wall.global_transform * Vector3(-1.0, 1.0, 3.0)
	await _frames(4)
	mode.aim_from = Vector3.INF
	_check(mode.aimed_piece == wall, "Take down aims at the door wall (%s)" % [mode.aimed_piece])
	_check(mode.take_down_prompt().begins_with("The roof rests on"), "its prompt says the roof rests on it (%s)" % mode.take_down_prompt())
	var n0 := world.pieces().size()
	_check(not mode.take_down(wall) and world.pieces().size() == n0, "a wall under the roof is not taken down")
	# the hearth comes down: half its stone back (Novice)
	var hearth: BuiltPiece = null
	for q in world.pieces():
		if q.type == "hearth":
			hearth = q
	if hearth:
		var s0 := mode.pack_count("stone")
		var sk := mode.skills()
		var pts := sk.points_of("building") if sk else 0.0
		if sk:
			sk.set_points("building", 0.0)
		mode.aim_at = hearth.global_transform * Vector3(0, 0.5, 1.2)
		await _frames(4)
		_check(mode.aimed_piece == hearth, "Take down aims at the hearth")
		_check(mode.take_down_prompt() == "Take down the stone hearth and chimney  (+8 stone)", "prompt: %s" % mode.take_down_prompt())
		# a tap of E takes it down (the interactor's target is the piece)
		_stand(hearth.global_transform * Vector3(0, 0, 3.5), -hearth.global_transform.basis.z)
		mode.aim_at = hearth.global_transform * Vector3(0, 0.5, 1.2)
		await _frames(6)
		_check(player.interactor.target == hearth, "E's target is the hearth (%s)" % [player.interactor.target])
		await _tap(ThrownPickup.INTERACT)
		await _frames(3)
		_check(not is_instance_valid(hearth) or hearth.is_queued_for_deletion() or not world.pieces().has(hearth), "a tap of E takes the hearth down")
		_check(mode.pack_count("stone") == s0 + 8, "8 of its 16 stone come back (%d)" % (mode.pack_count("stone") - s0))
		if sk:
			sk.set_points("building", pts)
	# the roof, then the wall under it
	var roof: BuiltPiece = null
	for q in world.pieces():
		if q.type == "roof":
			roof = q
	if roof:
		_check(mode.take_down(roof), "the roof comes down")
		_check(mode.take_down(wall), "then the door wall")
		await _frames(3)
		var x: BuiltPiece = _walls.get("+x")
		if x:
			_check(String(x.ctx.get("e0", "")) != "corner" or String(x.ctx.get("e1", "")) != "corner",
					"the wall beside it loses its notched corner (%s)" % [x.ctx])
	mode.aim_at = Vector3.INF
