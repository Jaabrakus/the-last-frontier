extends SceneTree
## Thủy Vân's Still Water greybox (plan phase 1, T5: WorldRegion, WorldRiver's still reach, FrontierPlayer.no_firearms,
## scenes/thuyvan_preview.tscn). Headless:
##
##   Godot --headless --path . -s tests/thuyvan/test_greybox.gd
##
##   region     with no region set, WorldRegion's paths are today's (WorldSquares.PATH, FrontierTerrain.DATA_DIR,
##              StoryLayer.DIR) and the readers use them; r1_grey's squares are its own file, its river today's numbers
##              (the baked bed still matches) with the still reach, its S1 layer has the cordon
##   still      in S1 inside the still reach WorldRiver.flow_at and WaterSurface.current_at are zero, eased at its ends,
##              unchanged outside it; in S0 and with no state unchanged everywhere
##   boat       a boat on the still reach in S1 drifts to a stop
##   level      the preview level loads in r1_grey without a SaveGame node; its player built no gun node (no musket, no
##              pistol, no socket) and has the equip wheel, building and the hotbar (the world's screens: not the arena)
##   F9         the raw key turns S0 to S1: the layer, the reach, the cordon; a fish in the reach hangs where it is; one who
##              steps over the rope is held at it; F9 again, back to S0
## Ends with "GREYBOX TEST PASSED (<n> checks)" or "GREYBOX TEST FAILED (<f> of <n>)".

const Region := preload("res://scripts/world/world_region.gd")
const SCENE := "res://scenes/thuyvan_preview.tscn"

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_region()
	_still()
	_boat()
	WorldRiver.reach_state = ""
	Region.set_region("")
	InputSetup.ensure()
	change_scene_to_file(SCENE)
	await process_frame
	await process_frame
	await _fr(30)
	await _level()
	WorldRiver.reach_state = ""
	if fails.is_empty():
		print("GREYBOX TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("GREYBOX TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _region() -> void:
	Region.set_region("")
	_expect(Region.id() == "" and Region.squares_path() == WorldSquares.PATH and Region.terrain_dir() == FrontierTerrain.DATA_DIR
			and Region.layers_dir() == StoryLayer.DIR, "region: with none set, WorldRegion's paths are today's")
	_expect(WorldSquares.path() == WorldSquares.PATH and FrontierTerrain.data_dir() == FrontierTerrain.DATA_DIR
			and Region.info().is_empty(), "region: the readers read today's (squares, baked ground)")
	var today: Dictionary = (WorldSquares.data().get("river", {}) as Dictionary).duplicate(true)
	Region.set_region("r1_grey")
	var grey: Dictionary = WorldSquares.data().get("river", {})
	var same := true
	for k: String in today:
		if not k.begins_with("_"):
			same = same and str(today[k]) == str(grey.get(k))
	_expect(Region.squares_path() == "res://data/world/maps/r1_grey/squares.json" and same and WorldSquares.squares().size() == 9,
			"region: r1_grey's squares are its own file; its river and grid today's (the baked bed matches)")
	var info := Region.info()
	_expect(absf(float(info.get("latitude_deg", 0.0)) - 21.0) < 1.0 and String(info.get("season", "")) == "early_rains"
			and not WorldRiver.reaches().is_empty(), "region: its block (latitude %.1f, %s) and the still reach" % [
			float(info.get("latitude_deg", 0.0)), info.get("season", "")])
	_expect(Region.terrain_dir() == FrontierTerrain.DATA_DIR, "region: the greybox keeps today's baked ground")
	var s1 := StoryLayer.load_layer("S1")
	_expect(not StoryLayer.load_layer("S0").is_empty() and (s1.get("cordon", {}) as Dictionary).has("ropes"),
			"region: its layers S0 and S1 (S1 with the cordon) from its own folder")
	Region.set_region("")
	_expect(WorldRiver.reaches().is_empty(), "region: back to none, today's river has no reach")


func _still() -> void:
	Region.set_region("r1_grey")
	var r: Dictionary = WorldRiver.reaches()[0]
	var z0 := float(r.z_from)
	var z1 := float(r.z_to)
	var e := float(r.ease_m)
	var mid := (z0 + z1) * 0.5
	# no state, and S0: as ever
	var before := {}
	for z: float in [z0 - 30.0, z0 + e * 0.5, mid, z1 - e * 0.5, z1 + 30.0, 200.0]:
		before[z] = WaterSurface.current_at(WorldRiver.x_at(z), z)
	WorldRiver.reach_state = ""
	var as_ever := WorldRiver.flow_at(mid).is_equal_approx(WorldRiver.dir_at(mid)) and WaterSurface.current_at(WorldRiver.x_at(mid), mid).length() > 0.3
	WorldRiver.reach_state = "S0"
	as_ever = as_ever and WorldRiver.flow_at(mid).is_equal_approx(WorldRiver.dir_at(mid)) and WorldRiver.still_band().is_empty()
	_expect(as_ever, "still: with no state and in S0 the reach runs as the river does (%.2f m/s)" % WaterSurface.current_at(WorldRiver.x_at(mid), mid).length())
	WorldRiver.reach_state = "S1"
	var still := true
	for z: float in [z0 + e, mid, z1 - e]:
		still = still and WorldRiver.flow_at(z).length() < 1e-6 and WaterSurface.current_at(WorldRiver.x_at(z), z).length() < 1e-6
	_expect(still, "still: in S1 inside the reach flow_at and current_at are zero")
	var a := WorldRiver.flow_at(z0 + e * 0.25).length()
	var b := WorldRiver.flow_at(z0 + e * 0.5).length()
	var c := WorldRiver.flow_at(z0 + e * 0.75).length()
	var d := WorldRiver.flow_at(z1 - e * 0.5).length()
	_expect(a > b and b > c and b > 0.05 and b < 0.95 and d > 0.05 and d < 0.95,
			"still: eased at its ends (%.2f %.2f %.2f upstream, %.2f downstream)" % [a, b, c, d])
	var outside := true
	for z: float in [z0 - 30.0, z0 - 0.01, z1 + 0.01, z1 + 30.0, 200.0, -300.0]:
		outside = outside and WorldRiver.flow_at(z).is_equal_approx(WorldRiver.dir_at(z))
	for z: float in [z0 - 30.0, z1 + 30.0, 200.0]:
		outside = outside and WaterSurface.current_at(WorldRiver.x_at(z), z).is_equal_approx(before[z])
	_expect(outside, "still: unchanged outside the reach")
	var band := WorldRiver.still_band()
	_expect(is_equal_approx(float(band.get("amount", 0.0)), 1.0) and is_equal_approx(WorldRiver.still_amount(mid), 1.0)
			and WorldRiver.still_amount(z1 + 5.0) == 0.0, "still: the band for the water's look, the fish and the voice")
	WorldRiver.reach_state = ""


func _boat() -> void:
	Region.set_region("r1_grey")
	WorldRiver.reach_state = "S1"
	var r: Dictionary = WorldRiver.reaches()[0]
	var z := (float(r.z_from) + float(r.z_to)) * 0.5
	var x := WorldRiver.x_at(z)
	var f := WorldRiver.dir_at(z)
	var bt := Boat.make("rowboat", Vector3(x, 0.0, z), atan2(f.x, f.z))
	bt.spec = Boat.spec_of("rowboat")
	bt.vel = f * WaterSurface.RIVER_MPS        # come in at the river's pace
	bt._settle()
	var z_start := bt.position.z
	for i in 20 * 60:
		bt.step(1.0 / 60.0)
	# (no current carries it: only the boat's own water drag slows its coast, which leaves a few cm/s after 20 s, against
	# the river's pace it came in at and the 20 s x that pace the running river would have carried it)
	_expect(bt.vel.length() < 0.15 and bt.vel.length() < WaterSurface.RIVER_MPS * 0.25 and bt.position.z - z_start < 6.0,
			"boat: on the still reach a boat drifts to a stop (%.3f m/s after 20 s, %.1f m on)" % [bt.vel.length(), bt.position.z - z_start])
	bt.free()
	WorldRiver.reach_state = ""
	Region.set_region("")


func _level() -> void:
	var level := current_scene
	var lv := level as ThuyVanLevel
	_expect(lv != null and Region.id() == "r1_grey", "level: the preview level loads, in r1_grey")
	if lv == null:
		return
	_expect(level.get_node_or_null("SaveGame") == null and SaveGame.find(self) == null, "level: no SaveGame node (no saving in the greybox)")
	var p := lv.player
	p.ignore_mouse_capture = true
	var guns := false
	for k: String in FrontierPlayer.FIREARMS:
		guns = guns or p.weapons.has(k) or p.skeleton.get_node_or_null(k + "_socket") != null
	var holder := p.get_node_or_null("Weapons")
	for w in (holder.get_children() if holder else []):
		guns = guns or w is Firearm
	_expect(p.no_firearms and not guns and p.gear == null, "level: no gun node is built (no musket, pistol, socket or gun gear)")
	_expect(not p.arena and p.equip_wheel != null and p.building != null and p.hotbar != null and p.interactor != null,
			"level: the world's screens, the equip wheel, building and the hotbar are there")
	_expect(lv.state == "S0" and StoryLayer.active_id() == "S0" and WorldRiver.reach_state == "S0" and not lv.cordon.active,
			"level: it opens in S0, the river running, no cordon")
	# F9: S1
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F9
	key.pressed = true
	lv._input(key)
	await _fr(3)
	var r: Dictionary = WorldRiver.reaches()[0]
	var z := (float(r.z_from) + float(r.z_to)) * 0.5
	_expect(lv.state == "S1" and StoryLayer.active_id() == "S1" and WorldRiver.flow_at(z).length() < 1e-6 and lv.cordon.active
			and lv.cordon.watchers.size() > 0, "F9: S1, the reach still, the layer S1, the cordon and its %d watchers" % lv.cordon.watchers.size())
	if lv.fish:
		lv.fish.restock_on = false
		var stand := Vector3(WorldRiver.x_at(-48.0) - 24.0, 0.0, -48.0)
		stand.y = FrontierTerrain.height_at(stand.x, stand.z) + 0.05
		p.global_position = stand
		p.velocity = Vector3.ZERO
		await _fr(5)
		var fz := float(r.z_to) - float(r.ease_m) - 12.0
		var fh: FishLife.Fish = lv.fish.spawn_fish(FishSpecies.ids()[0], Vector3.INF, fz, 6.0)
		if fh:
			var at := fh.pos
			lv.fish.alarm(fh.pos, 5.0)
			await _fr(90)
			_expect(fh.pos.distance_to(at) < 0.001 and is_equal_approx(fh.effort, 0.15),
					"F9: a fish in the still reach hangs where it is, startled or not, its tail still (moved %.4f m)" % fh.pos.distance_to(at))
		else:
			_expect(false, "F9: a fish put in the still reach (none placed)")
	# over the lower rope: held at it
	var rz := float((lv.cordon.spec.ropes as Array)[0].z)
	for rope: Dictionary in lv.cordon.spec.ropes:
		rz = maxf(rz, float(rope.z))
	var inside := Vector3(WorldRiver.x_at(rz - 1.5) - 20.0, 0.0, rz - 1.5)
	inside.y = FrontierTerrain.height_at(inside.x, inside.z) + 0.05
	var held0 := lv.cordon.held
	p.global_position = inside
	p.velocity = Vector3.ZERO
	await _fr(10)
	_expect(p.global_position.z > rz and lv.cordon.held > held0,
			"F9: one who steps over the rope is held at it (z %.2f, the rope at %.2f)" % [p.global_position.z, rz])
	lv._input(key)
	await _fr(3)
	_expect(lv.state == "S0" and StoryLayer.active_id() == "S0" and WorldRiver.flow_at(z).is_equal_approx(WorldRiver.dir_at(z))
			and not lv.cordon.active and lv.cordon.watchers.is_empty(), "F9 again: back to S0, the river running, the cordon gone")
