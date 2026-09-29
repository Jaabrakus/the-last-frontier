extends "res://tools/showcase/clips.gd"
## The trailer's footage (user 2026-09-28: "lets create a trailer for the game we have a lot going on"): every shot a
## take of its own through a film camera, nothing drawn over the picture (no HUD, prompts, aim arc or highlight: the
## game's CanvasLayers stay out of the view), for tools/showcase/trailer_edit.py to cut to the score.
##
##   <out>/<shot>/frames/f00000.jpg ...   the take
##   <out>/<shot>/frames.txt              the engine frame of each (its sound: trailer_edit.py cuts it from the AVI)
##   <out>/<shot>/marks.txt               "<frame> <name>": the moments the edit cuts on (the shot fired, the tree down)
##
##   Godot --path . --resolution 640x360 --fixed-fps 30 --write-movie <dir>/raw.avi -s tools/showcase/trailer.gd -- \
##       out=<dir> new_game size=1920x1080 survival=on survival_seed=7 wildlife=on birdlife=on [only=<shot>,<shot>]
##   the mammoth is in the climbing yard: scene=res://scenes/climb_yard.tscn only=mammoth, a run of its own
## tools/showcase/make_trailer.sh does all of it. The player is Actor_B; see CREDITS.md for the rest.

## (climb_tree before chop: clips.gd's tree picks do not skip a tree an earlier take felled.)
const SHOTS := ["dawn_river", "valley", "herd", "gate", "walk", "climb_tree", "chop", "build", "forage", "cast", "fight",
		"ride", "stalk", "musket", "throw", "vault", "wolves", "storm", "camp", "torch", "owl", "night_shot", "dusk",
		"bison", "stampede", "charge", "reload", "autumn", "winter_walk", "river_ice", "yoga", "mammoth"]
## Takes the cut does not use, recorded only when named (only=): the musket's reload walking and crouched (to check
## it), the shot from the palisade's firing step (the rebuilt fort's step moved: it does not fire from there).
const EXTRA := ["wall", "reload_walk", "reload_crouch", "reload_crouch_walk"]

var marks := PackedStringArray()
var hide_arc := false               ## the throw's aim arc kept out of the picture
## The take's date, a survival calendar day (the core's date is the sky's, the leaves' and the snow's: _clock() sets it).
## Late August unless a take says otherwise (a new game starts in September, and the evenings had gone dark).
var season := "aug_late"


func _order() -> Array:
	return SHOTS + EXTRA if args.has("only") else SHOTS


# --- the picture: the film camera's alone ------------------------------------------------------------------------------

func _build_overlay() -> void:
	super()
	tut_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_no_highlight()


## The game's 2D layers (HUD, prompts, the build panel, menus) draw to the window, not into the film.
func _redirect(_n: Node) -> void:
	pass


## What E would take glows gold (the interactor's overlay): not in a trailer.
func _no_highlight() -> void:
	var it = player.get("interactor")
	if it == null:
		return
	var m := it.get("_hl_mat") as ShaderMaterial
	if m == null:
		return
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() {\n\tdiscard;\n}\n"
	m.shader = sh
	m.next_pass = null


func _overlay(_t: float) -> void:
	black_rect.color = Color(0, 0, 0, 0)
	cap_box.modulate.a = 0.0
	tut_panel.modulate.a = 0.0
	fade_rect.visible = false
	(readout.get_parent() as Control).visible = false


func late(dt: float) -> void:
	super(dt)
	if hide_arc:
		for n in level.find_children("*", "ThrowableArc", true, false):
			(n as Node3D).visible = false


func _step(_spec: String) -> void:
	pass


## A moment the edit cuts on, at the frame being recorded now.
func mark(name: String) -> void:
	marks.append("%d %s" % [clip_frame, name])
	print("TRAILER mark %s %s at frame %d (%.2f s)" % [cur_id, name, clip_frame, seg_t])


## Marks the next shot of the weapon in the hands (and runs `then` with it).
func _mark_fire(tag := "shot", then := Callable()) -> void:
	var w := player.weapon
	if w == null:
		return
	var cb := func() -> void:
		mark(tag)
		if then.is_valid():
			then.call()
	w.fired.connect(cb, CONNECT_ONE_SHOT)


# --- a take each -------------------------------------------------------------------------------------------------------

func _begin_segment() -> void:
	super()
	show_vitals = false
	marks = PackedStringArray()
	hide_arc = false
	season = "aug_late"
	cine_takes_over = false
	aim_target = Vector3.INF
	DirAccess.make_dir_recursive_absolute(out.path_join(cur_id).path_join("frames"))
	_no_highlight()
	# every take starts on foot, standing, nothing lit, nothing in the rod hand (the fight goes on from the cast)
	if player.riding:
		player.dismount()
	if player.is_crouching and cur_id != "fight":
		player.set_crouched(false)
	if player.torch and player.torch.holding():
		player.torch.put_away()
	var fg := FishingGear.find(player)
	if fg and fg.gear != "" and cur_id != "fight":
		fg.put_away()
	# the hands on the weapons again (the camp's take stows them: a weapon takes no fire hands-free, so every shot
	# after it silently failed to go off), and every gun loaded (one fired in an earlier take is empty: fire then
	# starts a reload instead of a shot)
	if player.hands_free:
		player.toggle_hands_free()
	for w: Variant in player.weapons.values():
		if w is Firearm and not (w as Firearm).loaded:
			(w as Firearm).loaded = true
			(w as Firearm).state = Firearm.State.READY
	# the body never faded for the game's own camera (it comes in close as a gun is shouldered: the film camera saw
	# him turn see-through; user 2026-09-29 "the user becomes transparent")
	if player.grip:
		player.grip.near_fade_m = Vector2(-2.0, -1.0)
		player.grip.aim_fade = 0.0


## The take's hour on its date (`season`), the snow its winter would have on the ground: the survival core carries the
## date (it drives the sky clock, SeasonLeaves and SnowCover), so it is set there, not only on the sky.
func _clock(hour: float, weather := "fair", cover := -1.0) -> void:
	super(hour, weather, cover)
	var b := SurvivalBridge.find(self)
	if b == null or b.core == null:
		return
	var core := b.core
	core.state.minutes = SurvivalClock.minutes_at(core, season, SurvivalClock.year(core), hour)
	core.state.world["clock_acc"] = 0.0
	core.state.weather["snow_depth_cm"] = SurvivalWeather.normal_snow_depth(core)
	for sc in level.find_children("*", "SnowCover", true, false):
		sc.set("_last_core_cm", -1.0)
	_rested()
	print("TRAILER %s: %s %.2f h" % [cur_id, SurvivalClock.date_string(core), hour])


## Snow falling (the sky overcast with its drizzle: in winter it falls as snow, SnowFall).
func _snowing() -> void:
	var w: Node = get_first_node_in_group(&"weather")
	if w and w.has_method(&"force_weather"):
		w.call(&"force_weather", "overcast")
		var ws: Variant = w.get("weather")
		if ws:
			ws.set("drizzle", true)


func _end_segment() -> void:
	var f := FileAccess.open(out.path_join(cur_id).path_join("marks.txt"), FileAccess.WRITE)
	for m in marks:
		f.store_line(m)
	f.close()
	await super()


func _save_frame(img: Image) -> void:
	var path := out.path_join(cur_id).path_join("frames/f%05d.jpg" % clip_frame)
	clip_log.append("%d %d %s %.4f" % [clip_frame, Engine.get_process_frames() - 1, cur_id, seg_t])
	clip_frame += 1
	frame_no += 1
	while pending.size() >= SAVE_QUEUE:
		WorkerThreadPool.wait_for_task_completion(pending.pop_front())
	var q := jpg_q
	pending.append(WorkerThreadPool.add_task(func() -> void: img.save_jpg(path, q)))


# --- helpers -----------------------------------------------------------------------------------------------------------

func _on(p: Vector3, up := 0.0) -> Vector3:
	return Vector3(p.x, _ground(p.x, p.z) + up, p.z)


## A film camera driven by `fn(dt) -> [pos, look, fov]`.
func _cam_fn(fn: Callable) -> void:
	cam_fn = fn
	use_cine = true
	cine.current = cine_takes_over
	view.source = cine


## A straight lane `length` m long along `dir` near `near`: the fewest trees, plants and props between `lo` and `hi` m
## to its side (the walker's right +), off the fort and the range, on gentle ground. The start on the ground.
func _lane(near: Vector3, dir: Vector3, length: float, lo: float, hi: float) -> Vector3:
	var h := VegHarvest.find(self)
	var pts := PackedVector3Array()
	if h and h.lay:
		for arr: PackedVector3Array in [h.lay.tree_pos, h.lay.plant_pos, h.lay.prop_pos]:
			for q in arr:
				if absf(q.x - near.x) < 110.0 + length and absf(q.z - near.z) < 110.0 + length:
					pts.append(q)
	var right := Vector3(-dir.z, 0.0, dir.x)
	var best := near
	var best_s := INF
	for gx in range(-16, 17):
		for gz in range(-16, 17):
			var st := near + Vector3(gx * 4.0, 0.0, gz * 4.0)
			var en := st + dir * length
			if not _line_off_structures(st, en):
				continue
			var lo_g := INF
			var hi_g := -INF
			for k in 10:
				var p := st.lerp(en, k / 9.0)
				var g := _ground(p.x, p.z)
				lo_g = minf(lo_g, g)
				hi_g = maxf(hi_g, g)
			if hi_g - lo_g > 1.6:
				continue
			var n := 0
			for q in pts:
				var d := q - st
				var along := d.x * dir.x + d.z * dir.z
				var side := d.x * right.x + d.z * right.z
				if along > -3.0 and along < length + 3.0 and side > lo and side < hi:
					n += 1
			var sc := n * 100.0 + Vector2(st.x - near.x, st.z - near.z).length()
			if sc < best_s:
				best_s = sc
				best = st
	print("TRAILER lane near %s along %s: %s (score %.0f)" % [near, dir, best, best_s])
	return _on(best)


## A camera spot `dist` m from `target` with the clearest sightline to it (the fewest trees, then bushes, near the
## line), off the fort and the range; nearest the way `prefer` points from the target.
func _sight(target: Vector3, dist: float, prefer: Vector3, up := 1.6) -> Vector3:
	var h := VegHarvest.find(self)
	var best := target + prefer.normalized() * dist
	var best_s := INF
	for k in 36:
		var a := TAU * k / 36.0
		var dir := Vector3(sin(a), 0.0, cos(a))
		var p := target + dir * dist
		if not _line_off_structures(p, target + dir * 3.0):
			continue
		var n := 0.0
		if h and h.lay:
			for pair: Array in [[h.lay.tree_pos, 10.0, 2.2], [h.lay.plant_pos, 1.0, 1.2]]:
				for q: Vector3 in pair[0]:
					var v := Vector3(q.x - target.x, 0.0, q.z - target.z)
					var along := v.dot(dir)
					if along < 3.0 or along > dist + 1.0:
						continue
					if (v - dir * along).length() < float(pair[2]):
						n += float(pair[1])
		var sc := n + (1.0 - dir.dot(prefer.normalized())) * 6.0
		if sc < best_s:
			best_s = sc
			best = p
	print("TRAILER sight on %s from %s (score %.1f)" % [target, best, best_s])
	return _on(best, up)


## showcase_video.gd's piece, and why when build mode will not have it.
func _build_piece(mode: BuildMode, type: String, p: Vector3) -> BuiltPiece:
	var bp := await super(mode, type, p)
	if bp == null:
		print("TRAILER build: no %s at %s: %s (socket %s)" % [type, p.snappedf(0.01), mode.verdict.get("reason", "?"),
				mode.cand.get("kind", "none")])
	return bp


func _bison_herds() -> Array[WildGroup]:
	var w := WildlifeSpawner.find(self)
	var hs: Array[WildGroup] = []
	if w == null:
		return hs
	for e in w.groups:
		if String(e.kind) == "bison_herd" and not (e.group as WildGroup).alive().is_empty():
			hs.append(e.group)
	hs.sort_custom(func(a: WildGroup, b: WildGroup) -> bool: return a.alive().size() > b.alive().size())
	return hs


## On the open land, well off the herd (it grazes on, awake), the herd settled.
func _to_plains(g: WildGroup, off: Vector3) -> void:
	var w := WildlifeSpawner.find(self)
	w._restock_t = 1e9
	var p := g.centroid() + off
	_place(p.x, p.z, g.centroid())
	player.traversal.controller.teleported()
	w._lod()
	await _skip(8.0)


# --- act one: the land -------------------------------------------------------------------------------------------------

## Low over the river at sunrise, gliding downstream toward its white water.
func seg_dawn_river() -> void:
	_clock(5.55, "fair", 0.15)
	var z0 := 8.0
	var z1 := 30.0
	var bank := Vector3(WorldRiver.x_at(z0 - 24.0) - 18.0, 0.0, z0 - 24.0)
	_place(bank.x, bank.z, Vector3(WorldRiver.x_at(z0), 0.0, z0))
	player.traversal.controller.teleported()
	cine_takes_over = true
	var dur := 9.0
	_cam_fn(func(_dt: float) -> Array:
		var k := clampf(seg_t / dur, 0.0, 1.0)
		var z := lerpf(z0, z1, k)
		var p := Vector3(WorldRiver.x_at(z), WorldRiver.level_at(z) + lerpf(1.0, 2.2, k), z)
		var zl := z + 32.0
		return [p, Vector3(WorldRiver.x_at(zl), WorldRiver.level_at(zl) + 0.4, zl), 50.0])
	await _skip(3.0)
	await _roll("", "", "", 150)
	await _sec(dur)


## Over the forest to the fort in its clearing, morning.
func seg_valley() -> void:
	_clock(6.9, "fair", 0.22)
	_place(0.0, 6.0, Vector3(0, 0, -40))
	cine_takes_over = true
	_cam_path([[Vector3(130.0, 72.0, 130.0), Vector3(0.0, 0.0, -10.0)],
			[Vector3(80.0, 44.0, 78.0), Vector3(0.0, 1.0, -8.0)],
			[Vector3(38.0, 21.0, 34.0), Vector3(0.0, 2.0, -6.0)]], 10.0, 50.0)
	await _roll("", "", "", 150)
	await _sec(10.0)


## The range herd feeding in the morning meadow, a long lens.
func seg_herd() -> void:
	_clock(7.3, "fair", 0.15)
	var herd := _herd("deer_herd")
	if herd == null:
		print("TRAILER: no deer herd (wildlife=on)")
		return
	var hs := _on(Vector3(28.0, 0.0, -126.0))       # (the meadow east of the range, off its dummies and signs)
	var cp := _sight(hs, 55.0, Vector3(-0.3, 0.0, 1.0), 1.5)
	_place(cp.x - 3.0, cp.z + 6.0, hs)
	_move_group(herd, hs, WildGroup.Activity.FEED)
	await _skip(4.0)
	_cam_at(cp, func() -> Vector3: return herd.centroid() + Vector3.UP * 0.8, 14.0, 1.5)
	await _roll("", "", "", 60)
	await _sec(7.0)


## The fort's gate swings open and he walks out, the afternoon sun behind the fort.
func seg_gate() -> void:
	_clock(9.6, "fair", 0.25)
	var gate := FortGate.find(self)
	if gate:
		gate.set_open(false, true)
	await _equip("musket")
	_place(0.3, -9.0, Vector3(0.3, 0.0, -60.0))
	player.traversal.controller.teleported()
	var gc := _on(Vector3(0.0, 0.0, -16.0), 1.9)
	_cam_at(_on(Vector3(3.6, 0.0, -24.5), 1.0), func() -> Vector3: return gc.lerp(player.global_position + Vector3.UP * 1.3, 0.75), 42.0, 3.0)
	await _roll("", "", "", 60)
	await _sec(0.8)
	if gate:
		gate.interact(player)
	await _sec(1.8)
	_press(&"walk")
	_press(&"move_forward")
	await _sec(5.8)
	_release(&"move_forward")
	_release(&"walk")
	await _sec(0.6)


## Walking toward the lens at golden hour, the low sun at his back.
func seg_walk() -> void:
	_clock(18.45, "fair", 0.2)
	await _equip("musket")
	var dir := Vector3(1, 0, 0)
	var a := _lane(Vector3(30.0, 0.0, -95.0), dir, 36.0, -3.0, 3.0)
	_place(a.x, a.z, a + dir * 60.0)
	player.traversal.controller.teleported()
	_cam_rel(Vector3(0.35, 1.3, -3.8), Vector3(0.0, 1.45, 0.0), 40.0, 3.0)
	await _roll("", "", "", 60)
	_press(&"walk")
	_press(&"move_forward")
	await _sec(8.0)


# --- act two: make a life ----------------------------------------------------------------------------------------------

## The felling axe biting (low, beside the trunk, looking back at him), then the fall from behind him.
func seg_chop() -> void:
	_clock(10.2, "fair", 0.2)
	var h := VegHarvest.find(self)
	var lt := _lone_tree(false)
	if lt.is_empty():
		print("TRAILER: no tree to fell")
		return
	var tree := h.describe("tree", "tree", int(lt[0]))
	var tp: Vector3 = tree.pos
	var tall := float(tree.height)
	var d := _fall_lane(tp, tall)
	var side := d.cross(Vector3.UP).normalized()
	var at := tp - d * (float(tree.radius) + 1.0)
	_place(at.x, at.z, tp)
	player.pitch = deg_to_rad(4.0)
	var gt: GatherTools = player.gather
	if gt.skills:
		gt.skills.set_points("woodcutting", 55.0)
	await _tap(&"tool_axe")
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 3.0)
	_cam_at(_on(tp + side * 1.6 - d * 0.1, 0.7), func() -> Vector3: return player.global_position + Vector3.UP * 1.25, 46.0, 4.0)
	await _roll("", "", "", 50)
	await _sec(0.3)
	var felled := [null]
	gt.felled.connect(func(f: FelledTree) -> void: felled[0] = f, CONNECT_ONE_SHOT)
	_press(&"fire")
	await _until(func() -> bool: return felled[0] != null, 16.0)
	_release(&"fire")
	var ft: FelledTree = felled[0]
	if ft == null:
		return
	mark("felled")
	# the fall, from behind him: it goes away from the axe
	var cp := _sight(at, 7.5, -d + side * 0.4, 1.9)
	var look := _on(tp + d * tall * 0.3, tall * 0.3)
	_cam_at(cp, func() -> Vector3: return look, 58.0, 50.0)
	await _until(func() -> bool: return ft.is_down(), 8.0)
	mark("down")
	await _sec(2.4)


## A cabin raised piece by piece in the afternoon, the camera circling low.
func seg_build() -> void:
	_clock(16.4, "fair", 0.25)
	var cabin := Vector3(21.0, 0.0, 6.0)
	var mode: BuildMode = player.building
	var inv := InventoryState.from_player(player)
	inv.add("log", 300)
	inv.add("stone", 200)
	player.inventory_pack = inv.pack.duplicate(true)
	_place(cabin.x + 4.0, cabin.z + 3.5, cabin)
	if not player.hands_free:
		player.toggle_hands_free()
	var c := _on(cabin)
	var st := {"a": 0.0}
	_cam_fn(func(dt: float) -> Array:
		st.a = float(st.a) + dt * 0.11
		var a := float(st.a) + 0.3
		return [c + Vector3(sin(a) * 9.5, 3.1, cos(a) * 9.5), c + Vector3(0, 1.7, 0), 50.0])
	mode.set_active(true)
	await _roll("", "", "", 60)
	await _sec(0.4)
	var G := BuildGeometry
	var fl := await _build_piece(mode, "floor", c)
	if fl:
		# every aim in the floor's own frame (it is turned as its snap turned it): the gable ends at local +-Z, the
		# door in an eave side, the hearth against the plain gable wall's outer face (its middle 1 m up, 0.5 m out)
		var fx := fl.global_transform
		var top := float(G.FLOOR_H)
		var walls := {}
		for s: Array in [["wall", Vector3(0, 0, 1.3)], ["wall_window", Vector3(0, 0, -1.3)], ["wall_door", Vector3(-1.3, 0, 0)],
				["wall", Vector3(1.3, 0, 0)]]:
			walls[s[1]] = await _build_piece(mode, String(s[0]), fx * ((s[1] as Vector3) + Vector3(0, top, 0)))
		for k: Vector3 in [Vector3(0, 0, 1.3), Vector3(0, 0, -1.3)]:
			var w: BuiltPiece = walls.get(k)
			if w:
				await _build_piece(mode, "gable", w.global_transform * Vector3(0, float(G.WALL_H) + 0.01, 0))
		await _build_piece(mode, "roof", fx * Vector3(0, top, 0))
		# the hearth as a player places one: looking at the wall's outer face from outside (build mode's aim ray)
		mode.select_type("hearth")
		mode.aim_at = fx * Vector3(0, top + 1.0, 0.5 * float(G.L))
		mode.aim_from = fx * Vector3(0, top + 1.0, 0.5 * float(G.L) + 3.0)
		await _sec(0.55)
		if mode.place() == null:
			print("TRAILER build: no hearth: %s (socket %s)" % [mode.verdict.get("reason", "?"), mode.cand.get("kind", "none")])
		mode.aim_from = Vector3.INF
		await _sec(0.25)
		var door: BuiltPiece = walls.get(Vector3(-1.3, 0, 0))
		if door and door.door:
			door.door.set_open(true)
		for sp in level.find_children("*", "BuiltPiece", true, false):
			spawned.append(sp)
			var bp := sp as BuiltPiece
			var rel := fx.affine_inverse() * bp.global_transform
			print("TRAILER build %-12s at %s  yaw %4.0f" % [bp.type, rel.origin.snappedf(0.01), rad_to_deg(rel.basis.get_euler().y)])
	mode.aim_at = Vector3.INF
	mode.set_active(false)
	mark("built")
	await _sec(2.5)


## The fishing rod: crouched on the bank, the overhead cast out over the river.
func seg_cast() -> void:
	_clock(8.0, "fair", 0.2)
	if not await _fishing_bank():
		return
	var g := FishingGear.find(player)
	_cam_rel(Vector3(-2.4, 0.9, 2.8), Vector3(0.6, 1.4, -7.0), 48.0, 4.0)
	await _roll("", "", "", 40)
	await _sec(0.8)
	await _cast(g, true)
	await _sec(2.5)


## The fight: the strike, the rod bent, the line coming tight; a camera beside him on the bank.
func seg_fight() -> void:
	_clock(8.1, "fair", 0.2)
	var g := FishingGear.find(player)
	var life := FishLife.find(self)
	if g == null or life == null:
		return
	if g.rod_state == FishingGear.Rod.OFF or g.bait == null:
		if not await _fishing_bank():
			return
		await _cast(g, false)
	var fz := g.float_pos.z + WorldRiver.flow_at(g.float_pos.z).z * 2.2
	var fx := g.float_pos.x + WorldRiver.flow_at(g.float_pos.z).x * 2.2
	var fish := life.spawn_fish("brook_trout", Vector3(fx, 0.0, fz))
	fish.lb = 1.6
	fish.pos.y = life.layer_y(fish, fx, fz)
	fish.lie = fish.pos
	fish.goal = fish.pos
	fish.state = FishLife.State.HOLD
	fish.base = FishLife.State.HOLD
	fish.hunger = 1.0
	await _until(func() -> bool: return g.rod_state == FishingGear.Rod.BITE or g.bait == null, 15.0)
	_cam_rel(Vector3(6.8, 2.0, -1.2), Vector3(0.0, 1.7, -2.4), 50.0, 3.0)
	await _roll("", "", "", 2)
	g.fire_override = 1
	await _sec(0.1)
	g.fire_override = 0
	mark("strike")
	player.set_crouched(false)
	var got := []
	g.fish_landed.connect(func(_info: Dictionary) -> void: got.append(true), CONNECT_ONE_SHOT)
	var t := 0
	var hard := true
	var walking := false
	var back_t := 0
	while got.is_empty() and t < 420 and g.rod_state in [FishingGear.Rod.FIGHT, FishingGear.Rod.LAND]:
		if g.rod_state == FishingGear.Rod.FIGHT:
			if hard and (g.tension > 0.97 or t > 75):
				hard = false
			if hard and t > 20:
				g.pull_by(1.4 / 30.0)
			else:
				g.pull_by((0.45 if g.tension < 0.5 else (-1.4 if g.tension > 0.78 else 0.0)) / 30.0)
			var want: bool = float(fish.stamina) < 0.45 and back_t < 75
			if want:
				back_t += 1
			if want != walking:
				walking = want
				if want:
					_press(&"walk")
					_press(&"move_back")
				else:
					_release(&"move_back")
					_release(&"walk")
		await _frame()
		t += 1
	_release(&"move_back")
	_release(&"walk")
	if not got.is_empty():
		mark("landed")
	await _sec(1.5)


## Crouched on the east bank, the water to the west, the rod out (as tools/fishing/fish_fight_film.gd stands).
func _fishing_bank() -> bool:
	var life := FishLife.find(self)
	var g := FishingGear.find(player)
	if life == null or g == null:
		print("TRAILER: no fishing (FishLife %s, gear %s)" % [life, g])
		return false
	life.restock_on = false
	life.hour_override = 19.0
	life.month_override = 6
	for f in life.fish:
		f.gone = true
	life._sweep()
	var z := -140.0
	var cx := WorldRiver.x_at(z)
	var o := 0.0
	while life.depth(cx + o + 0.25, z) > 0.0 and o < 14.0:
		o += 0.25
	var ex := cx + o
	_place(ex + 1.2, z, Vector3(ex - 20.0, 0.0, z))
	player.traversal.controller.teleported()
	player.pitch = deg_to_rad(-14.0)
	player.set_crouched(true)
	await _warm(200)
	g.give("fishing_rod")
	var ok := g.take_out("fishing_rod")
	await _warm(12)
	if not ok or g.gear != "fishing_rod":
		print("TRAILER: the rod is not out (gear '%s')" % g.gear)
		return false
	return true


func _cast(g: FishingGear, marked: bool) -> void:
	var landed := []
	g.cast_landed.connect(func(_p: Vector3, wet: bool) -> void: landed.append(wet), CONNECT_ONE_SHOT)
	var ex := player.global_position.x - 1.2
	g.cast_override = "W"
	g.aim_override = Vector3(ex - 4.0, 0.0, player.global_position.z - 1.5)
	g.fire_override = 1
	if marked:
		mark("cast")
	await _sec(0.9)
	g.fire_override = 0
	await _until(func() -> bool: return not landed.is_empty(), 5.0)
	if marked:
		mark("float")


## At a canter along the meadow in the evening, the camera riding beside, into the low sun.
func seg_ride() -> void:
	_clock(17.9, "fair", 0.2)
	var horse := _horse()
	if horse == null:
		print("TRAILER: no horse")
		return
	var lead := horse.get_node_or_null("Lead")
	if lead and lead.has_method("stop"):
		lead.stop()
	var dir := Vector3(0, 0, -1)
	var a := _lane(Vector3(36.0, 0.0, -50.0), dir, 95.0, -3.0, 9.0)
	horse.global_position = a
	horse.look_at(a + dir, Vector3.UP)
	horse.speed = 0.0
	await _warm(10)
	_place(a.x + 1.3, a.z + 0.3, a + dir * 4.0)
	player.mount(horse)
	await _warm(70)
	player.yaw = horse.global_rotation.y
	_cam_rel(Vector3(6.0, 1.5, -1.2), Vector3(0.0, 1.4, -2.6), 42.0, 2.5, horse)
	_press(&"move_forward")
	await _sec(1.0)
	await _tap(&"sprint")
	await _sec(1.0)
	await _tap(&"sprint")
	await _roll("", "", "", 45)
	await _sec(7.5)
	_release(&"move_forward")
	await _sec(1.5)


# --- act three: the hunt, the weather, the dark ------------------------------------------------------------------------

## Crouched with the bow at a deer in the evening meadow, over his shoulder; loosed through the vitals.
func seg_stalk() -> void:
	_clock(17.2, "fair", 0.15)
	await _equip("bow")
	var at := Vector3(9.0, 0.0, -84.0)
	var dp := _on(Vector3(12.0, 0.0, -99.0))
	var bw := player.weapons.get("bow") as Weapon
	if bw:
		for f in ["spread_base", "spread_move", "spread_undercharge", "spread_air", "spread_fatigue", "spread_unaimed", "spread"]:
			bw.set(f, 0.0)
	var deer := WildAnimal.new()
	deer.setup("deer", WildlifeSpawner.find(self), null, 21)
	level.add_child(deer)
	spawned.append(deer)
	deer.global_position = dp
	deer.rotation.y = PI * 0.5
	deer.set("_yaw", deer.rotation.y)
	deer.set_active(true)
	_place(at.x, at.z, dp)
	await _tap(&"crouch")
	var vit := deer.get_node_or_null("Hit_vitals") as Node3D
	var vp := func() -> Vector3: return vit.global_position if vit else deer.global_position + Vector3.UP * 0.8
	aim_rate = 4.0
	for k in 60:
		deer.awareness = 0.0
		aim_target = vp.call()
		await _frame()
	_cam_rel(Vector3(0.62, 1.02, 1.35), Vector3(0.05, 0.85, -10.0), 30.0, 6.0)
	await _roll("", "", "", 20)
	for k in int(0.8 * fps):
		deer.awareness = 0.0
		aim_target = vp.call()
		await _frame()
	_press(&"fire")
	mark("draw")
	for k in int(1.9 * fps):
		deer.awareness = 0.0
		aim_target = vp.call()
		await _frame()
	_release(&"fire")
	mark("loose")
	await _sec(1.0)
	if not deer.is_dead() and vit:
		Hit.deliver(vit as StaticBody3D, 150.0, vit.global_position, Vector3(1, 0, 0), player)
	aim_target = Vector3.INF
	await _sec(2.4)


## The musket at the firing line in the golden hour: shouldered, the pan flash, the shot and its smoke; a camera
## ahead of the muzzle's side.
func seg_musket() -> void:
	_clock(18.6, "fair", 0.2)
	var tgt := Vector3(2.5, 1.25, -70.0)
	_place(1.0, FrontierStructures.FIRING_LINE_Z - 1.3, tgt)
	await _equip("musket")
	aim_target = tgt
	aim_rate = 5.0
	_cam_rel(Vector3(-1.7, 1.45, -2.4), Vector3(0.1, 1.45, 0.0), 38.0, 4.0)
	await _roll("", "", "", 40)
	await _sec(0.6)
	_mark_fire()
	_press_ev(&"fire")
	await _sec(1.5)
	_release_ev(&"fire")
	await _sec(3.5)


## The tomahawk into the range's dummy: from behind the dummy, it comes at the lens and bites.
func seg_throw() -> void:
	_clock(9.4, "fair", 0.2)
	for k in ["tomahawk", "spear"]:
		if not player.is_carried(k):
			player.set_carried(k, true)
	var dm := _on(Vector3(-2.5, 0.0, -30.0))
	_place(-2.2, FrontierStructures.FIRING_LINE_Z - 1.5, dm + Vector3.UP)
	var tw := player.weapons.get("tomahawk") as Throwable
	if tw:
		for f in ["spread_base", "spread_move", "spread_undercharge", "fire_bloom", "spread_air", "spread_fatigue", "spread"]:
			tw.set(f, 0.0)
	await _equip("tomahawk")
	aim_target = dm + Vector3.UP * 1.35
	aim_rate = 5.0
	hide_arc = true
	_cam_at(dm + Vector3(-0.8, 1.35, -1.8), func() -> Vector3: return player.global_position + Vector3.UP * 1.3, 36.0, 8.0)
	await _roll("", "", "", 40)
	await _sec(0.5)
	if tw:
		var on_hit := func(_c: Object, _p: Vector3, _s: bool) -> void: mark("hit")
		var on_throw := func(pr: ThrownProjectile) -> void:
			mark("release")
			pr.hit.connect(on_hit, CONNECT_ONE_SHOT)
		tw.thrown.connect(on_throw, CONNECT_ONE_SHOT)
	_press(&"fire")
	await _sec(1.1)
	_release(&"fire")
	await _sec(2.2)


## Hold... tap G at a trunk, W up to the crown: from the foot of the tree, looking up.
func seg_climb_tree() -> void:
	_clock(10.6, "fair", 0.2)
	var t := _lone_tree(true)
	if t.is_empty():
		print("TRAILER: no tree to climb")
		return
	var axis: Vector3 = t[1]
	var radius: float = clampf(float(t[2]) * 0.92, 0.1, 0.75)
	var to_open := Vector3(-axis.x, 0.0, -axis.z).normalized()
	var at := axis + to_open * (radius + 0.55)
	_place(at.x, at.z, axis)
	player.pitch = deg_to_rad(8.0)
	var sd := to_open.cross(Vector3.UP).normalized()
	_cam_at(_on(axis + to_open * (radius + 3.4) + sd * 1.8, 0.45), func() -> Vector3: return player.global_position + Vector3.UP * 1.0, 52.0, 3.0)
	await _roll("", "", "", 40)
	await _sec(0.5)
	var g: PlayerGrip = player.grip
	await _tap(&"grip", 0.15)
	await _until(func() -> bool: return g.state == PlayerGrip.HOLD, 3.0)
	mark("grip")
	_press(&"move_forward")
	await _until(func() -> bool: return g.perched, 16.0)
	_release(&"move_forward")
	mark("perched")
	await _sec(2.0)
	# from the branch, the game's own camera looking down: the crown round him fades, the ground shows
	_cam_game()
	player.pitch = deg_to_rad(-38.0)
	mark("perch_view")
	await _sec(3.0)


## A wolf pack at its kill in the evening, low in the grass.
func seg_wolves() -> void:
	# (on the snow, a January afternoon: the season's wolves on their trails, in the low sun)
	season = "jan_mid"
	_clock(15.0, "fair", 0.2)
	var w := WildlifeSpawner.find(self)
	var pk := _herd("wolf_pack")
	if w == null or pk == null:
		print("TRAILER: no wolves (wildlife=on)")
		return
	var cpos := _on(Vector3(34.0, 0.0, -70.0))
	var prey := WildAnimal.new()
	prey.setup("deer", w, null, 31)
	level.add_child(prey)
	spawned.append(prey)
	prey.global_position = cpos
	prey.set_active(true)
	await _warm(2)
	prey.apply_hit(500.0, prey.global_position + Vector3.UP * 0.6, Vector3(1, 0, 0), null, "body")
	var i := 0
	for m in pk.alive():
		var q := cpos + Vector3(cos(i * 1.7), 0.0, sin(i * 1.7)) * 1.6
		m.global_position = _on(q, 0.02)
		m.hunger = 1.0
		m.set_active(true)
		i += 1
	pk.carcass = prey
	pk.activity = WildGroup.Activity.EAT
	pk.dest = cpos
	pk.dest_set = true
	prey.set_meta("died_at", w.now - 60.0)
	_place(cpos.x - 40.0, cpos.z + 40.0, cpos)
	await _skip(22.0)
	_cam_at(_on(cpos + Vector3(6.0, 0.0, 4.5), 0.9), func() -> Vector3: return cpos + Vector3.UP * 0.45, 38.0, 2.0)
	await _roll("", "", "", 40)
	await _sec(7.0)


## A storm front brewing on the horizon and breaking over the range: the gust, rain and lightning.
func seg_storm() -> void:
	_clock(14.2, "fair", 0.3)
	var w := dn.weather
	dn.force_weather("storm")
	w.field.front.w = 1.0
	w.set("_front_strength", 1.0)
	w.kind_duration = 1.0e6
	_place(10.0, -44.0, Vector3(-40.0, 0.0, -100.0))
	var pos := player.global_position
	_storm_at(16.0, pos)
	var d2 := Vector2(w.field.front.x, w.field.front.y).normalized()
	_place(pos.x, pos.z, pos + Vector3(-d2.x, 0.0, -d2.y) * 100.0)
	await _equip("musket")
	await _skip(1.0)
	cine_takes_over = true
	_cam_rel(Vector3(1.4, 1.0, 6.0), Vector3(-0.6, 7.0, -24.0), 64.0, 3.0)
	await _warm(40)
	await _roll("", "", "", 10)
	var dur := 13.0
	var strikes := [4.5, 6.4, 7.6, 8.9, 10.1, 11.3, 12.4]
	for fi in int(dur * fps):
		var t := float(fi) / fps
		var km := lerpf(12.0, -4.0, pow(t / dur, 1.2))
		var strike := false
		for sx: float in strikes:
			if t >= sx and t - 1.0 / fps < sx:
				strike = true
		if strike:
			mark("strike")
		_storm_at(km, pos, strike)
		await _frame()
	dn.force_weather("fair")


## A campfire in the meadow at dusk, fireflies over the grass; he sits by it. Across the flames, low.
func seg_camp() -> void:
	_clock(20.0, "clear", 0.05)
	var mode := player.get_node_or_null("BuildMode") as BuildMode
	var inv := InventoryState.from_player(player)
	inv.add("stone", 12)
	inv.add("firewood", 20)
	player.inventory_pack = inv.pack.duplicate(true)
	if not player.hands_free:
		player.toggle_hands_free()
	var cf: Campfire = null
	var fire_at := Vector3.ZERO
	for spot: Vector3 in [Vector3(24.0, 0.0, -112.0), Vector3(21.0, 0.0, 6.0)]:
		fire_at = _on(spot)
		_place(fire_at.x + 1.7, fire_at.z + 0.6, fire_at)
		await _warm(40)
		if mode == null:
			break
		mode.set_active(true)
		mode.select_type("campfire")
		mode.aim_at = fire_at
		await _warm(6)
		mode.refresh_placement()
		var fp := mode.place()
		mode.set_active(false)
		mode.aim_at = Vector3.INF
		cf = fp.get_node_or_null("Campfire") as Campfire if fp else null
		if cf:
			spawned.append(fp)
			cf.light()
			for k in 6:
				cf.add_wood(player)
			break
	print("TRAILER camp fire at %s: %s" % [fire_at, cf])
	_place(fire_at.x + 1.7, fire_at.z + 0.6, fire_at)
	if not player.hands_free:
		player.toggle_hands_free()
	var me := player.global_position
	var across := (fire_at - me)
	across.y = 0.0
	across = across.normalized()
	_cam_at(_on(fire_at + across * 2.5 + across.cross(Vector3.UP) * 0.5, 0.55), func() -> Vector3: return (me + fire_at) * 0.5 + Vector3.UP * 0.55, 42.0, 3.0)
	await _warm(40)
	await _roll("", "", "", 10)
	await _sec(0.6)
	await _tap(&"sleep")
	await _sec(7.0)


## Through the dark wood with a raised torch, walking at the lens.
func seg_torch() -> void:
	_clock(21.4, "clear", 0.0)
	await _equip("musket")
	var dir := Vector3(0, 0, 1)
	var a := _lane(Vector3(-50.0, 0.0, -64.0), dir, 30.0, -1.4, 1.4)
	_place(a.x, a.z, a + dir * 40.0)
	player.traversal.controller.teleported()
	if player.torch.count() < 3:
		player.torch.add_torches(3)
	await _tap(&"torch")
	await _torch_in_hand()
	await _sec(0.6)
	await _tap(&"torch")
	await _sec(1.2)
	_cam_rel(Vector3(0.45, 1.45, -3.9), Vector3(0.0, 1.6, 0.0), 42.0, 3.0)
	await _roll("", "", "", 50)
	_press(&"walk")
	_press(&"move_forward")
	await _sec(8.0)


## A great horned owl in a tree at night, its eyes shining.
func seg_owl() -> void:
	_clock(20.15, "clear", 0.0)
	var birds := level.get_node_or_null("BirdLife") as BirdLife
	if birds == null:
		print("TRAILER: no owls (birdlife=on)")
		return
	_place(20.0, -110.0, Vector3(24.0, 0.0, -125.0))
	dn.clock.set_time(19.4)
	birds.sun_override = -8.0
	await _skip(2.0)
	var owls := birds.owls()
	if owls.is_empty():
		birds.sun_override = INF
		print("TRAILER: no owl out")
		return
	var o := owls[0]
	var to := o.global_position - player.global_position
	to.y = 0.0
	var oc := o.global_position - to.normalized() * 1.7
	oc.y = o.global_position.y + 0.35
	var far := o.global_position - to.normalized() * 30.0
	_place(far.x, far.z, o.global_position)
	birds.sun_override = -16.0
	_cam_path([[oc, o.global_position + Vector3.UP * 0.32], [oc + Vector3(0, 0.05, 0) - to.normalized() * 0.4, o.global_position + Vector3.UP * 0.32]], 5.0, 40.0)
	await _roll("", "", "", 30)
	await _sec(5.0)
	birds.sun_override = INF


## Up on the fort's firing step at dusk, firing out over the palisade: from inside, low under the boards, against the
## sky.
func seg_wall() -> void:
	_clock(19.3, "fair", 0.3)
	await _equip("musket")
	_place(8.0, -10.8, Vector3(8.0, 0, -40))
	player.traversal.controller.teleported()
	_press(&"move_forward")
	await _until(func() -> bool: return player.global_position.z <= -13.55, 3.0)
	await _tap(&"jump", 0.15)
	await _sec(3.4)
	_release(&"move_forward")
	await _sec(0.8)
	print("TRAILER wall: up at %s" % player.global_position)
	aim_target = Vector3(15.0, 1.5, -80.0)
	aim_rate = 5.0
	_cam_at(_on(Vector3(11.2, 0.0, -9.6), 1.1), func() -> Vector3: return player.global_position + Vector3.UP * 1.3, 44.0, 4.0)
	await _roll("", "", "", 50)
	await _sec(0.5)
	_mark_fire()
	_press_ev(&"fire")
	await _sec(1.5)
	_release_ev(&"fire")
	await _sec(3.5)


## Night in the meadow: a torch in his hand, the musket shouldered (the torch tossed down, burning, lighting him), a
## shot that lights the dark; from ahead of him to his left, low.
func seg_night_shot() -> void:
	_clock(22.2, "clear", 0.0)
	await _equip("musket")
	var p0 := _on(Vector3(18.0, 0.0, -104.0))
	var tgt := p0 + Vector3(-32.0, 1.4, -8.0)
	_place(p0.x, p0.z, tgt)
	player.traversal.controller.teleported()
	if player.torch.count() < 3:
		player.torch.add_torches(3)
	await _tap(&"torch")
	await _torch_in_hand()
	aim_target = tgt
	aim_rate = 5.0
	var f := Vector3(tgt.x - p0.x, 0.0, tgt.z - p0.z).normalized()
	var left := Vector3.UP.cross(f).normalized()
	_cam_at(_on(p0 + f * 2.8 + left * 2.1, 1.15), func() -> Vector3: return player.global_position + Vector3.UP * 1.35, 40.0, 4.0)
	await _roll("", "", "", 50)
	await _sec(0.8)
	_mark_fire()
	_press_ev(&"fire")
	mark("toss")
	await _sec(2.4)
	print("TRAILER night_shot: before the release, state %s aim %.2f torch held %s" % [player.weapon.get("state"),
			float(player.weapon.get("aim")), player.torch.holding()])
	_release_ev(&"fire")
	await _sec(3.5)


## Sunset over the treeline: he stands looking west, the camera low behind him, drifting in (the title's ground).
func seg_dusk() -> void:
	_clock(18.45, "fair", 0.3)
	await _equip("musket")
	var p0 := _on(Vector3(26.0, 0.0, -120.0))
	_place(p0.x, p0.z, p0 + Vector3(-60.0, 0.0, 6.0))
	player.traversal.controller.teleported()
	player.pitch = deg_to_rad(2.0)
	_cam_path([[_on(p0 + Vector3(5.5, 0.0, 2.8), 0.9), p0 + Vector3(-24.0, 3.2, 1.0)],
			[_on(p0 + Vector3(3.4, 0.0, 1.6), 1.05), p0 + Vector3(-24.0, 3.0, 1.0)]], 10.0, 44.0)
	await _roll("", "", "", 60)
	await _sec(10.0)


# --- the plains ----------------------------------------------------------------------------------------------------------

## A bison herd grazing on the open land, from the grass beside it.
func seg_bison() -> void:
	_clock(8.8, "fair", 0.2)
	var hs := _bison_herds()
	if hs.is_empty():
		print("TRAILER: no bison (wildlife=on)")
		return
	var g := hs[0]
	await _to_plains(g, Vector3(-130.0, 0.0, 30.0))
	player.set_crouched(true)
	cine_takes_over = true
	_cam_fn(func(_dt: float) -> Array:
		var c := g.centroid()
		var k := clampf(seg_t / 7.0, 0.0, 1.0)
		return [_on(c + Vector3(lerpf(-10.0, 5.0, k), 0.0, 24.0), 1.3), c + Vector3.UP * 1.1, 38.0])
	await _roll("", "", "", 60)
	await _sec(7.0)


## The stampede: a musket shot off to the west and the herd runs together; the camera alongside.
func seg_stampede() -> void:
	_clock(9.0, "fair", 0.2)
	var hs := _bison_herds()
	if hs.is_empty():
		print("TRAILER: no bison (wildlife=on)")
		return
	var g := hs[0]
	var w := WildlifeSpawner.find(self)
	await _equip("musket")
	await _to_plains(g, Vector3(-75.0, 0.0, 0.0))
	aim_target = player.global_position + Vector3(0.0, 40.0, -30.0)
	aim_rate = 5.0
	cine_takes_over = true
	var st := {"p": Vector3.INF, "run": Vector3.RIGHT}
	_cam_fn(func(dt: float) -> Array:
		var c := g.centroid()
		var v := Vector3.ZERO
		for a in g.alive():
			v += Vector3(a.velocity.x, 0.0, a.velocity.z)
		var run: Vector3 = v.normalized() if v.length() > 0.5 * g.alive().size() else st.run
		st.run = (st.run as Vector3).slerp(run, 1.0 - exp(-1.5 * dt)).normalized()
		var r: Vector3 = st.run
		var aside := r.cross(Vector3.UP).normalized()
		var want := _on(c + aside * 30.0 - r * 8.0, 3.2)
		st.p = want if st.p == Vector3.INF else (st.p as Vector3).lerp(want, 1.0 - exp(-3.6 * dt))
		return [st.p, c + Vector3.UP * 1.0, 48.0])
	await _roll("", "", "", 60)
	await _sec(0.8)
	var shot_at := player.global_position + Vector3.UP * 1.5
	_mark_fire("shot", func() -> void: w.shot(shot_at, WildlifeSpawner.SHOT_LOUD_M))
	_press_ev(&"fire")
	await _sec(1.4)
	_release_ev(&"fire")
	await _sec(9.0)


## One bull shot through the body turns on the hunter and throws him down; side on.
func seg_charge() -> void:
	_clock(9.3, "fair", 0.2)
	var hs := _bison_herds()
	if hs.is_empty():
		print("TRAILER: no bison (wildlife=on)")
		return
	var g2 := hs[hs.size() - 1]
	await _equip("musket")
	await _to_plains(g2, Vector3(-40.0, 0.0, 40.0))
	var bull: WildAnimal = g2.alive()[0]
	for b in g2.alive():
		if b != bull:
			b.set_active(false)
	bull.awareness = 0.0
	bull._enter(WildAnimal.State.IDLE, 5.0)
	await _warm(20)
	var fwd := -bull.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := bull.global_position + fwd * 13.0
	_place(at.x, at.z, bull.global_position)
	player.traversal.controller.teleported()
	aim_target = bull.global_position + Vector3.UP * 1.1
	aim_rate = 6.0
	var sd := fwd.cross(Vector3.UP).normalized()
	var mid := (bull.global_position + at) * 0.5
	_cam_at(_on(mid + sd * 10.0 - fwd * 1.0, 1.3), func() -> Vector3: return (bull.global_position + player.global_position) * 0.5 + Vector3.UP * 1.0, 48.0, 4.0)
	await _warm(30)
	await _roll("", "", "", 20)
	await _sec(0.5)
	var hit := func() -> void:
		bull.apply_hit(160.0, bull.global_position + Vector3.UP * 1.1 - fwd * 0.9, (bull.global_position - player.global_position).normalized(), player, "body")
	_mark_fire("shot", hit)
	_press_ev(&"fire")
	await _sec(1.3)
	_release_ev(&"fire")
	var rd := PlayerRagdoll.of(player)
	var down: bool = await _until(func() -> bool: return rd != null and rd.is_down(), 6.0)
	if down:
		mark("down")
	await _sec(2.5)
	for b in g2.alive():
		b.set_active(true)


# --- the musket's reload (MusketReload) -------------------------------------------------------------------------------

## Fired, then loaded standing at dusk behind the palisade (MusketReload's drill); from ahead of him to his left.
func seg_reload() -> void:
	# (the evening's last light: the cut has it before the night shot, loading behind the palisade)
	_clock(18.1, "fair", 0.2)
	var tgt := Vector3(2.5, 1.25, -70.0)
	_place(1.0, FrontierStructures.FIRING_LINE_Z - 1.3, tgt)
	await _equip("musket")
	var m := player.weapon as Firearm
	m.loaded = true
	m.state = Firearm.State.READY
	aim_target = tgt
	aim_rate = 5.0
	_cam_rel(Vector3(-1.9, 1.3, -2.7), Vector3(0.15, 1.15, 0.0), 45.0, 4.0)
	await _roll("", "", "", 40)
	await _sec(0.4)
	_mark_fire()
	_press_ev(&"fire")
	await _sec(1.3)
	_release_ev(&"fire")
	await _sec(1.0)
	aim_target = Vector3.INF
	await _tap(&"reload")
	mark("reload")
	# the ball rammed: the first stroke (MusketReload's clips: 4.22 s into the reload)
	await _sec(4.22)
	mark("ram")
	await _until(func() -> bool: return m.loaded, 9.0)
	mark("loaded")
	await _sec(1.2)


## Loaded on the move: walking, the gun held up off the ground; the camera walking beside him.
func seg_reload_walk() -> void:
	_clock(10.5, "fair", 0.2)
	await _equip("musket")
	var dir := Vector3(1, 0, 0)
	var a := _lane(Vector3(30.0, 0.0, -95.0), dir, 30.0, -3.0, 3.0)
	_place(a.x, a.z, a + dir * 60.0)
	player.traversal.controller.teleported()
	var m := player.weapon as Firearm
	m.loaded = false
	m.state = Firearm.State.EMPTY
	_cam_rel(Vector3(-2.3, 1.3, -2.2), Vector3(0.0, 1.2, 0.3), 45.0, 3.0)
	await _roll("", "", "", 40)
	_press(&"move_forward")
	await _sec(0.8)
	await _tap(&"reload")
	mark("reload")
	await _until(func() -> bool: return m.loaded, 9.0)
	mark("loaded")
	await _sec(1.0)
	_release(&"move_forward")
	await _sec(0.5)


## Loaded crouched: down on a knee behind the firing line, the gun's butt kept off the ground.
func seg_reload_crouch() -> void:
	_clock(10.5, "fair", 0.2)
	_place(1.0, FrontierStructures.FIRING_LINE_Z - 1.3, Vector3(2.5, 1.25, -70.0))
	await _equip("musket")
	player.set_crouched(true)
	var m := player.weapon as Firearm
	m.loaded = false
	m.state = Firearm.State.EMPTY
	_cam_rel(Vector3(-1.7, 0.8, -2.3), Vector3(0.1, 0.65, 0.0), 45.0, 4.0)
	await _roll("", "", "", 40)
	await _sec(0.8)
	await _reload_watched(m, "reload_crouch")
	await _sec(1.2)
	player.set_crouched(false)


## Loaded crouched on the move: creeping forward while he loads.
func seg_reload_crouch_walk() -> void:
	_clock(10.5, "fair", 0.2)
	await _equip("musket")
	var dir := Vector3(1, 0, 0)
	var a := _lane(Vector3(30.0, 0.0, -95.0), dir, 20.0, -3.0, 3.0)
	_place(a.x, a.z, a + dir * 60.0)
	player.traversal.controller.teleported()
	player.set_crouched(true)
	var m := player.weapon as Firearm
	m.loaded = false
	m.state = Firearm.State.EMPTY
	_cam_rel(Vector3(-2.0, 0.9, -2.0), Vector3(0.0, 0.7, 0.3), 45.0, 3.0)
	await _roll("", "", "", 40)
	_press(&"move_forward")
	await _sec(0.8)
	await _reload_watched(m, "reload_crouch_walk")
	await _sec(1.0)
	_release(&"move_forward")
	await _sec(0.5)
	player.set_crouched(false)


## A reload from the tap to loaded, marked, the gun's lowest point over the ground under the player logged.
func _reload_watched(m: Firearm, shot: String) -> void:
	await _tap(&"reload")
	mark("reload")
	var low := [INF]
	await _until(func() -> bool:
		low[0] = minf(low[0], _gun_low(m))
		return m.loaded, 9.0)
	mark("loaded")
	print("TRAILER %s: the gun's lowest point %.2f m over the player's feet" % [shot, low[0]])


func _gun_low(m: Firearm) -> float:
	var n := m.model as Node3D
	if n == null:
		return INF
	var y := INF
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var box := mi.get_aabb()
		for i in 8:
			y = minf(y, (mi.global_transform * box.get_endpoint(i)).y)
	return y - player.global_position.y


# --- the climbing yard ---------------------------------------------------------------------------------------------------

## The mammoth: a ball behind a knee and it goes down (scene=res://scenes/climb_yard.tscn).
func seg_mammoth() -> void:
	_clock(17.4, "fair", 0.2)
	var yard = level.get("yard")
	var gi: StandInGiant = yard.giant if yard != null and yard.get("giant") != null else null
	if gi == null:
		# on the great plains (user 2026-09-29: "the mammoth needs to be in the great plains"): the climbing yard's
		# mammoth set down in the open grass beyond the bison, the herd behind it
		var hs := _bison_herds()
		var at := _on(hs[0].centroid() + Vector3(26.0, 0.0, 8.0)) if not hs.is_empty() else _on(Vector3(-130.0, 0.0, 30.0))
		gi = StandInGiant.new()
		gi.name = "Mammoth"
		gi.player = player
		level.add_child(gi)
		gi.build(Transform3D(Basis(Vector3.UP, deg_to_rad(-70.0)), at))
		spawned.append(gi)
		print("TRAILER mammoth: on the plains at %s" % at)
	var plains := yard == null
	gi.paces = false
	await _equip("musket")
	await _warm(30)
	var wk: Node3D = null
	var best := -INF
	# (the beast's body, a child set where build() put it: the node itself stays at its parent's origin)
	var body: Vector3 = (gi.get("body") as Node3D).global_position if gi.get("body") is Node3D else gi.global_position
	var fwd: Vector3 = -(gi.get("body") as Node3D).global_basis.z if gi.get("body") is Node3D else -gi.global_basis.z
	for z: Node3D in gi.weak:
		var back := -(z.global_position - body).dot(fwd)
		if back > best:
			best = back
			wk = z
	var aim_pt := wk.global_position if wk else body + Vector3.UP * 1.5
	var from_dir := (-fwd * 0.8 + fwd.cross(Vector3.UP).normalized() * 0.6).normalized()
	var stand := aim_pt + from_dir * 11.0
	_place(stand.x, stand.z, aim_pt)
	aim_target = aim_pt
	aim_rate = 5.0
	if plains:
		# (over his shoulder, above the flowers: the hunter and the beast ahead of him; user 2026-09-29 "the user isnt
		# in it i want the shot and then climbing the mammoth")
		_cam_rel(Vector3(1.6, 1.8, 3.2), Vector3(-0.6, 1.2, -6.0), 55.0, 3.0)
	else:
		_cam_rel(Vector3(-2.4, 0.8, 3.8), Vector3(0.8, 2.6, -9.0), 50.0, 3.0)
	await _warm(40)
	await _roll("", "", "", 10)
	await _sec(0.6)
	_mark_fire()
	_press_ev(&"fire")
	await _sec(1.6)
	_release_ev(&"fire")
	await _sec(1.6)
	if String(gi.down_leg) == "" and wk:
		gi.apply_hit(60.0, aim_pt, -from_dir, player, "knee_" + String(wk.name).trim_prefix("Weak_").trim_prefix("knee_"))
	aim_target = Vector3.INF
	mark("buckle")
	if not plains:
		await _sec(3.5)
		return
	# while it is down: at its flank, G takes hold, W climbs onto its back (as the climbing yard's clip)
	await _sec(1.2)
	var bb: Basis = (gi.get("body") as Node3D).global_basis if gi.get("body") is Node3D else Basis()
	var flank := (bb * Vector3(-1.0, 0.0, 0.0)).normalized()
	var st2 := body + flank * 1.65
	_place(st2.x, st2.z, body + Vector3.UP * 2.6)
	player.pitch = 0.15
	_cam_at(_on(body + flank * 9.0 - fwd * 2.5, 2.8), func() -> Vector3: return player.global_position + Vector3.UP * 1.3, 50.0, 4.0)
	await _warm(6)
	mark("grab")
	_press(&"grip")
	await _sec(0.8)
	_press(&"move_forward")
	await _until(func() -> bool: return player.grip.state == PlayerGrip.OFF \
			or (player.grip.anchor != null and player.grip.anchor.global_basis.y.y > 0.93), 12.0)
	_release(&"move_forward")
	_release(&"grip")
	mark("top")
	print("TRAILER mammoth: climbed (grip %s)" % player.grip.state)
	await _sec(1.6)


# --- the seasons (the take's date: SeasonLeaves turns the broadleaves, SnowCover lays the winter) ----------------------

## The valley in the fall: over the woods toward the fort, mid-October, the maples and oaks turned (the pines green).
func seg_autumn() -> void:
	season = "oct_mid"
	_clock(10.0, "fair", 0.25)
	_place(0.0, 6.0, Vector3(0, 0, -40))
	cine_takes_over = true
	_cam_path([[Vector3(-120.0, 58.0, 105.0), Vector3(0.0, 0.0, -10.0)],
			[Vector3(-74.0, 36.0, 62.0), Vector3(0.0, 1.0, -8.0)],
			[Vector3(-38.0, 19.0, 30.0), Vector3(0.0, 2.0, -6.0)]], 8.0, 50.0)
	await _roll("", "", "", 150)
	await _sec(8.0)


## A snowing January morning in the woods: he walks through it, his prints behind him.
func seg_winter_walk() -> void:
	season = "jan_mid"
	_clock(10.0, "overcast", 0.85)
	_snowing()
	await _equip("musket")
	var dir := Vector3(1, 0, 0)
	var a := _lane(Vector3(30.0, 0.0, -95.0), dir, 36.0, -3.0, 3.0)
	_place(a.x, a.z, a + dir * 60.0)
	player.traversal.controller.teleported()
	_cam_rel(Vector3(-1.4, 1.2, -3.6), Vector3(0.2, 1.1, 0.8), 42.0, 3.0)
	await _roll("", "", "", 90)
	_press(&"walk")
	_press(&"move_forward")
	await _sec(8.0)
	_release(&"move_forward")
	_release(&"walk")


## The river frozen across in deep winter, a clear cold morning: he walks out onto the ice from the bank.
func seg_river_ice() -> void:
	season = "jan_late"
	_clock(9.5, "clear", 0.05)
	await _equip("musket")
	var z := 20.0
	var rx := WorldRiver.x_at(z)
	_place(rx - 14.0, z, Vector3(rx + 20.0, 0.0, z))
	player.traversal.controller.teleported()
	_cam_rel(Vector3(2.2, 1.1, -4.2), Vector3(0.0, 1.0, 0.5), 44.0, 3.0)
	await _roll("", "", "", 90)
	_press(&"walk")
	_press(&"move_forward")
	await _sec(8.0)
	_release(&"move_forward")
	_release(&"walk")


# --- home ----------------------------------------------------------------------------------------------------------------

## Yoga together in the woods (the household's tandem pose, the crawl: the woman leads, her husband joins, kneeling
## behind), held, from down the open lane (user 2026-09-29: "have it in the woods use crawl"); the cut puts a newborn's
## cry on the next shot. The player is the man here: his wife's stand-in body (TandemProxy, as Household's TandemLink
## does) is set down 2.5 m ahead of him on the lane, lands, and starts the pose alone; then he joins by the game's own
## join, which puts him in his place behind her. A pair found on top of each other is not filmed.
func seg_yoga() -> void:
	_clock(11.0, "fair", 0.25)
	var house := level.find_child("Household", true, false) as Household
	var pt := TandemProxy.controller_of(player)
	if pt == null or pt.is_woman(player):
		print("TRAILER: no yoga (the player leads only as a man's partner here)")
		return
	var dir := Vector3(1, 0, 0)
	var a := _lane(Vector3(30.0, 0.0, -95.0), dir, 24.0, -3.0, 3.0)
	var back := a - dir * 2.5
	_place(back.x, back.z, a + dir * 20.0)
	player.traversal.controller.teleported()
	var look: Dictionary = house.sc.look if house and house.sc else {}
	var wife := TandemProxy.make(player.get_parent(), look, _on(a), player.rotation.y)
	spawned.append(wife)
	await _warm(30)
	var lead := TandemProxy.add_lead(wife, pt)
	await _warm(4)
	if not lead.start_pose("crawl"):
		print("TRAILER: yoga did not start (the wife's stand-in: on the floor %s)" % wife.is_on_floor())
		return
	await _sec(1.5)
	var t1 := seg_t
	while not pt.join_nearby() and seg_t - t1 < 4.0:
		await _sec(0.25)
	await _until(func() -> bool: return bool(lead.joined), 6.0)
	await _sec(1.0)
	var gap := Vector2(wife.global_position.x - player.global_position.x, wife.global_position.z - player.global_position.z).length()
	print("TRAILER yoga: paired %s, %.2f m apart (at %.2f / %.2f m up)" % [lead.joined, gap,
			wife.global_position.y, player.global_position.y])
	# (joined, he kneels close behind her: 0.3 m between their feet is his place; less than 0.15 is one on the other)
	if not lead.joined or gap < 0.15:
		print("TRAILER: no yoga (not paired, or on top of each other)")
		lead.stop_pose()
		return
	mark("paired")
	var c: Vector3 = wife.global_position
	var side := dir.cross(Vector3.UP).normalized()
	_cam_at(_on(c + dir * 3.6 + side * 1.9, 0.95), func() -> Vector3: return c + Vector3.UP * 0.45 - dir * 0.4, 42.0, 3.0)
	await _roll("", "", "", 30)
	await _sec(4.0)
	lead.stop_pose()
