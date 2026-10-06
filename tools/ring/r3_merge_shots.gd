extends SceneTree
## Round 3's merged review images for the owner's eye (the Smash layer merged: PERCENT, MOVE, AIR, BOTS and the animation
## lane's committed clips), the % ring itself (rules.json's stock rules, no stand-ins), earth against a water bot held where
## it stands, 1280 x 720. Windowed (it draws):
##   Godot --path . --resolution 1280x720 -s tools/ring/r3_merge_shots.gd -- out=<dir> [light=noon|night] [part=all|arena]
## part=all writes <dir>/r3_merge_plates_low.png, r3_merge_plates_high.png (the plates at low and high %),
## r3_merge_launch_high.png (a Spike at 140%: the moment after, and 0.35 s on), r3_merge_edge_hang.png (the player hanging on
## the edge: his own camera | from the side), r3_merge_rise_<element>.png (each Rise: its start and 0.3 s in, from the side),
## r3_merge_slam_spike.png (earth's Slam on a foe just off the lip: the strike, and 0.35 s on) and r3_merge_air_hit.png (an
## air close hit: the strike). part=arena writes r3_merge_arena_<light>.png (the tank, the water 6 m down, the curtain) and
## r3_merge_arena_<light>_lip.png (the deck's edge from the player's place 3 m in). Ends with R3 MERGE SHOTS DONE.

const OWN_CFG := "user://r3_merge_shots.cfg"

var out := ""
var part := "all"
var light := "noon"
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var mode: RingMode
var rules: RingRules
var foe: NpcFighter
var ring: RingArena
var _hold := {}
var _side_cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("part="):
			part = a.substr(5)
		elif a.begins_with("light="):
			light = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup._aim_help = "strong"
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "easy"
	MatchSetup.light = light
	RingRules.rule_set_override = "stock"
	physics_frame.connect(_holds)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


## Bodies held in the air or in place (body -> world point) until let go.
func _holds() -> void:
	for b: Variant in _hold.keys():
		if not is_instance_valid(b):
			_hold.erase(b)
			continue
		var n := b as CharacterBody3D
		n.global_position = _hold[b]
		n.velocity = Vector3.ZERO


func _grab() -> Image:
	for i in 3:
		RenderingServer.force_draw(true)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(out.path_join(name + ".png"))
	print("  wrote %s.png" % name)


func _shot(name: String) -> void:
	await _frames(3)
	_save(await _grab(), name)


## Images side by side (each scaled to half width), one file.
func _strip(imgs: Array, name: String) -> void:
	var w := 0
	var h := 0
	var small: Array = []
	for im: Image in imgs:
		var s := im.duplicate() as Image
		s.resize(s.get_width() / 2, s.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		small.append(s)
		w += s.get_width() + 6
		h = maxi(h, s.get_height())
	var sheet := Image.create(w - 6, h, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.09))
	var x := 0
	for s: Image in small:
		sheet.blit_rect(s, Rect2i(0, 0, s.get_width(), s.get_height()), Vector2i(x, 0))
		x += s.get_width() + 6
	_save(sheet, name)


func _side(at: Vector3, look: Vector3) -> void:
	if _side_cam == null:
		_side_cam = Camera3D.new()
		_side_cam.fov = 55.0
		current_scene.add_child(_side_cam)
	_side_cam.global_position = at
	_side_cam.look_at(look, Vector3.UP)
	_side_cam.make_current()


func _own_cam() -> void:
	if p.camera != null:
		p.camera.make_current()


## A deck place `s` m in from end `e`'s lip (negative: out past it), `z` across, `y` over the deck's top.
func at_s(e: int, s: float, z := 0.0, y := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * (ring.half_l() - s), ring.top() + y, z))


func _run() -> void:
	await _frames(20)
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	p = lvl.player
	ring = lvl.ring
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	for i in 900:
		if mode.phase == "FIGHT" and not LoadingScreen.covering():
			break
		await physics_frame
	await _secs(0.5)
	rules = RingRules.current()
	foe = mode.foe
	print("  stock %s, RingMoves on the player %s and the foe %s" % [RingRules.stock_on(), RingMoves.of(p) != null, RingMoves.of(foe) != null])
	foe.held = true
	if part == "arena":
		await _arena()
	else:
		await _plates()
		await _launch()
		await _hang()
		await _rises()
		await _air_hit()
		await _slam()
	RingRules.rule_set_override = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	print("R3 MERGE SHOTS DONE")
	quit(0)


## The player at `pos` facing `look` (flat), still.
func _place(pos: Vector3, look: Vector3) -> void:
	var f := look - pos
	f.y = 0.0
	RingLevel.place(p, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), pos))
	p.pitch = -0.15


func _place_foe(pos: Vector3, look: Vector3) -> void:
	var f := look - pos
	f.y = 0.0
	RingLevel.place(foe, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), pos))


# ---------------------------------------------------------------- the plates
func _plates() -> void:
	var e := mode.player_end
	_place(at_s(e, 10.0, 1.5), at_s(1 - e, 12.0))
	_place_foe(at_s(1 - e, 12.0, -1.0), p.global_position)
	await _secs(0.4)
	rules.reset_pct(p, 0.0)
	rules.reset_pct(foe, 0.0)
	await _secs(0.3)
	rules.add_pct(p, 12.0, foe, "water_whip/whip")
	rules.add_pct(foe, 34.0, p, "stone_form/spike")
	await _secs(1.2)
	await _shot("r3_merge_plates_low")
	rules.add_pct(p, 76.0, foe, "wave/push")
	rules.add_pct(foe, 131.0, p, "stone_form/cannonball")
	await _secs(1.2)
	await _shot("r3_merge_plates_high")


# ---------------------------------------------------------------- a high-% launch
func _launch() -> void:
	var e := mode.player_end
	rules.reset_pct(p, 20.0)
	_place(at_s(1 - e, 14.0, 0.0), at_s(1 - e, 6.0))
	_place_foe(at_s(1 - e, 7.0, 0.0), p.global_position)
	await _secs(0.5)
	rules.reset_pct(foe, 140.0)
	var way := (foe.global_position - p.global_position)
	way.y = 0.0
	way = way.normalized()
	BendStatus.hurt(foe, 30.0, foe.global_position + Vector3.UP, way, p, -1.0, {"tag": "stone_form/spike", "from": p.global_position})
	BendLooks.burst(foe.global_position + Vector3.UP, "stone", 30, way, 50.0, 6.0, 0.4)
	await _secs(0.12)
	var a := await _grab()
	await _secs(0.35)
	var b := await _grab()
	_strip([a, b], "r3_merge_launch_high")
	await _secs(2.5)


# ---------------------------------------------------------------- hanging on the edge
func _hang() -> void:
	var e := mode.player_end
	var rm := RingMoves.of(p)
	var lip := ring.nearest_lip(at_s(e, 0.0))
	var n: Vector3 = lip.normal
	var feet := Vector3(lip.point) + n * 0.45 + Vector3.DOWN * 1.9
	RingLevel.place(p, Transform3D(Basis.looking_at(-n, Vector3.UP), feet))
	p.velocity = Vector3.DOWN * 1.0
	rm.set(&"_air", true)
	for i in 120:
		if rm.on_ledge():
			break
		await physics_frame
	await _secs(0.8)
	var own := await _grab()
	_side(Vector3(lip.point) + n * 2.6 + ring.global_basis.z * 4.5 + Vector3.UP * 0.6, Vector3(lip.point) + n * 0.3 + Vector3.DOWN * 0.8)
	var side := await _grab()
	_own_cam()
	print("  hanging: %s (%s)" % [rm.on_ledge(), rm.clip_state()])
	_strip([own, side], "r3_merge_edge_hang")
	_hold.clear()
	_place(at_s(e, 6.0), at_s(1 - e, 6.0))
	await _secs(1.0)


# ---------------------------------------------------------------- each element's Rise
func _rises() -> void:
	var e := mode.player_end
	for el: String in ["earth", "water", "fire", "air"]:
		if p.arena_element != el:
			Bending.of(p).element = el
			for i in 240:
				if p.arena_element == el:
					break
				await physics_frame
		await _secs(0.3)
		var rm := RingMoves.of(p)
		var lip := ring.nearest_lip(at_s(e, 0.0))
		var n: Vector3 = lip.normal
		var start := Vector3(lip.point) + n * 3.5 + Vector3.DOWN * 1.2
		RingLevel.place(p, Transform3D(Basis.looking_at(-n, Vector3.UP), start))
		p.pitch = 0.25
		rm.set(&"_air", true)
		rm.jumps_left = 0
		rm.rise_ready = true
		_hold[p] = start
		_side(start + ring.global_basis.z * 9.0 + n * 1.0 + Vector3.UP * 1.5, start + Vector3.UP * 2.5 - n * 1.0)
		await _secs(0.4)
		_hold.erase(p)
		Input.action_press(&"jump")
		await _ticks(2)
		Input.action_release(&"jump")
		await _secs(0.12)
		var a := await _grab()
		await _secs(0.3)
		var b := await _grab()
		print("  %s's Rise: mode %s, helpless %s" % [el, rm.mode, rm.helpless()])
		_strip([a, b], "r3_merge_rise_" + el)
		_own_cam()
		await _secs(1.6)
		_place(at_s(e, 6.0), at_s(1 - e, 6.0))
		await _secs(0.8)
	Bending.of(p).element = "earth"
	for i in 240:
		if p.arena_element == "earth":
			break
		await physics_frame


# ---------------------------------------------------------------- a Slam spiking him off the edge
func _slam() -> void:
	var e := 1 - mode.player_end
	rules.reset_pct(foe, 110.0)
	var lip := ring.nearest_lip(at_s(e, 0.0, 2.0))
	var n: Vector3 = lip.normal
	var foe_at := Vector3(lip.point) + n * 0.5 + Vector3.DOWN * 0.6
	_place_foe(foe_at, foe_at - n)
	_hold[foe] = foe_at
	(rules._sk(foe) as Dictionary)["safe_until"] = -INF
	var me_at := Vector3(lip.point) - n * 0.2 + Vector3.UP * 2.2
	_place(me_at, foe_at + n * 3.0)
	RingMoves.of(p).set(&"_air", true)
	_hold[p] = me_at
	p.pitch = -0.6
	_side(Vector3(lip.point) + n * 3.0 + ring.global_basis.z * 7.0 + Vector3.UP * 0.5, Vector3(lip.point) + n * 0.6 + Vector3.DOWN * 0.8)
	await _secs(0.3)
	p.hotbar.select(1)
	await _ticks(2)
	c.held_override = true
	for i in 240:
		if c.state == SwayCaster.State.FULL:
			break
		await physics_frame
	BendR3.hits_log.clear()
	c.held_override = false
	for i in 90:
		if not BendR3.hits_log.is_empty():
			break
		await physics_frame
	_hold.erase(foe)
	_hold.erase(p)
	print("  the Slam: form %s, hits %s" % [c.mode_of("earth_shove"), BendR3.hits_log.map(func(h: Dictionary) -> String: return String(h.tag))])
	await _ticks(2)
	var a := await _grab()
	await _secs(0.35)
	var b := await _grab()
	_strip([a, b], "r3_merge_slam_spike")
	_own_cam()
	await _secs(2.5)


# ---------------------------------------------------------------- an air close hit
func _air_hit() -> void:
	var e := mode.player_end
	rules.reset_pct(foe, 30.0)
	var foe_at := at_s(e, 8.0, 0.0, 1.6)
	_place_foe(foe_at, foe_at + ring.global_basis.z)
	_hold[foe] = foe_at
	for i in 300:
		if not rules.is_away(foe):
			break
		await physics_frame
	(rules._sk(foe) as Dictionary)["safe_until"] = -INF      # (not just back from the water: no spawn safety)
	var me_at := foe_at + ring.global_basis.z * 1.4 + Vector3.UP * 0.2
	_place(me_at, foe_at)
	RingMoves.of(p).set(&"_air", true)
	_hold[p] = me_at
	p.pitch = -0.1
	_side(foe_at + ring.global_basis.z * 0.7 + ring.axis() * 6.0 + Vector3.UP * 0.6, foe_at + ring.global_basis.z * 0.7)
	await _secs(0.3)
	BendR3.hits_log.clear()
	c.quick_override = true
	for i in 240:
		if c.state == SwayCaster.State.FULL:
			break
		await physics_frame
	c.quick_override = false
	for i in 60:
		if not BendR3.hits_log.is_empty():
			break
		await physics_frame
	_hold.erase(foe)
	print("  the air hit: %s" % [BendR3.hits_log.map(func(h: Dictionary) -> String: return String(h.tag))])
	var a := await _grab()
	await _secs(0.25)
	var b := await _grab()
	_strip([a, b], "r3_merge_air_hit")
	_hold.erase(p)
	_own_cam()
	await _secs(1.0)


# ---------------------------------------------------------------- the arena
func _arena() -> void:
	var e := mode.player_end
	_place(at_s(e, 3.0, 2.0), at_s(e, -6.0, 2.0))
	_place_foe(at_s(1 - e, 10.0), at_s(e, 10.0))
	await _secs(1.0)
	await _shot("r3_merge_arena_%s_lip" % light)
	var corner := ring.to_global(Vector3(RingArena.side_sign(e) * (ring.half_l() + 8.0), ring.top() + 6.0, ring.half_w() + 8.0))
	_side(corner, ring.to_global(Vector3(0.0, ring.top() - 3.0, 0.0)))
	await _secs(0.5)
	await _shot("r3_merge_arena_%s" % light)
	_own_cam()
