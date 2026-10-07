extends SceneTree
## Round 4 IMPACT's review strips for the owner's eye (hit-stop, the jolt, the perfect guard's beat, the KO splash, the slow
## beat on the last fall), the % ring (stock rules), earth against a water bot held where it stands, 1280 x 720. Windowed (it
## draws), at 50 ticks a second so a frame is 20 ms of game time:
##   Godot --path . --fixed-fps 50 --resolution 1280x720 -s tools/ring/feel_shots.gd -- out=<dir> tag=before|after
##         [light=noon|night] [part=all|ko]
## Each strip frame is one physics step and then the tree paused while it is drawn (from the player's camera, then from the
## high side camera over the gate end), so every column is exactly 20 ms after the last whatever the drawing costs. It runs
## on the base too (it names nothing of round 4's): "before" is the base at the same frozen moments.
## part=all writes r4_impact_knock_strip_<tag>.png (an earth Spike from 10 m landing on the bot: 8 frames from the hit),
## r4_impact_jab_pop_strip_<tag>.png (the jab string's Pop at 2 m: the hitter's hold), r4_impact_perfect_strip_<tag>.png (a
## perfect Catch: 8 frames from the catch), r4_impact_ko_splash_<tag or light>.png (a fall into the water: 0.16, 0.44, 0.9 s
## after it, from the deck behind the lip), and with tag=after r4_impact_final_moment_strip.png (a game's last fall: 8 frames
## over the slow beat, unpaused, each with the time scale printed). part=ko the KO splash only (the night run). Prints
## FEEL_SHOT lines (what each frame shows) and ends with FEEL SHOTS DONE.

const OWN_CFG := "user://feel_shots.cfg"
const STONE := {"kind": "stone", "mps": 40.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.25,
		"range_m": 30.0}

var out := ""
var tag := "after"
var part := "all"
var light := "noon"
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var mode: RingMode
var rules: RingRules
var foe: NpcFighter
var ring: RingArena
var _hi_cam: Camera3D
var _kos: Array = []
var dbg := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
		elif a.begins_with("part="):
			part = a.substr(5)
		elif a.begins_with("light="):
			light = a.substr(6)
		elif a == "dbg":
			dbg = true
	Engine.physics_ticks_per_second = 50
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


## One frame run (one physics step at --fixed-fps 50), then the tree paused: its picture is the viewport's now.
func _step() -> void:
	paused = false
	if dbg:
		print("  dbg step in %d" % Time.get_ticks_msec())
	await RenderingServer.frame_post_draw
	paused = true
	if dbg:
		print("  dbg step out %d" % Time.get_ticks_msec())


func _now_img() -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## The paused frame drawn again from `cam`.
func _draw_from(cam: Camera3D) -> Image:
	cam.make_current()
	if dbg:
		print("  dbg draw in %d" % Time.get_ticks_msec())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if dbg:
		print("  dbg draw out %d" % Time.get_ticks_msec())
	return _now_img()


## Rows of images (each scaled to a quarter: 320 x 180), one file.
func _sheet(rows: Array, name: String, scale := 0.25) -> void:
	var cw := 0
	var ch := 0
	var small: Array = []
	for row: Array in rows:
		var r: Array = []
		for im: Image in row:
			var s := im.duplicate() as Image
			s.resize(int(s.get_width() * scale), int(s.get_height() * scale), Image.INTERPOLATE_BILINEAR)
			r.append(s)
			cw = s.get_width()
			ch = s.get_height()
		small.append(r)
	var cols := 0
	for r: Array in small:
		cols = maxi(cols, r.size())
	var sheet := Image.create(cols * (cw + 4) - 4, small.size() * (ch + 4) - 4, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.09))
	for j in small.size():
		var r: Array = small[j]
		for i in r.size():
			var s: Image = r[i]
			sheet.blit_rect(s, Rect2i(0, 0, s.get_width(), s.get_height()), Vector2i(i * (cw + 4), j * (ch + 4)))
	sheet.save_png(out.path_join(name + ".png"))
	print("  wrote %s.png" % name)


func _hi(at: Vector3, look: Vector3) -> Camera3D:
	if _hi_cam == null:
		_hi_cam = Camera3D.new()
		_hi_cam.fov = 50.0
		current_scene.add_child(_hi_cam)
	_hi_cam.global_position = at
	_hi_cam.look_at(look, Vector3.UP)
	return _hi_cam


## 8 strip frames: each one step, drawn from his camera and from `side`: [own row, side row].
func _strip8(side: Camera3D, label: String) -> Array:
	var own: Array = []
	var hi: Array = []
	for i in 8:
		await _step()
		own.append(_now_img())
		hi.append(await _draw_from(side))
		p.camera.make_current()
		var kn := BendKnock.peek(foe)
		var pend: Variant = kn.get(&"_pend_until") if kn != null else null
		print("FEEL_SHOT %s frame %d t=%d ms foe_pos=%s foe_vel=%.2f foe_anim=%.3f held_launch=%s" % [label, i, i * 20,
				foe.global_position.snapped(Vector3.ONE * 0.01), foe.velocity.length(),
				foe.body.ap.current_animation_position if foe.body != null and foe.body.ap != null else -1.0,
				"n/a" if pend == null else str(float(pend) > BendStatus.now())])
	paused = false
	return [own, hi]


## A deck place `s` m in from end `e`'s lip, `z` across, `y` over the deck's top.
func at_s(e: int, s: float, z := 0.0, y := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * (ring.half_l() - s), ring.top() + y, z))


func _place(pos: Vector3, look: Vector3) -> void:
	var f := look - pos
	f.y = 0.0
	RingLevel.place(p, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), pos))
	p.yaw = atan2(-f.x, -f.z)
	p.pitch = -0.08


func _place_foe(pos: Vector3, look: Vector3) -> void:
	var f := look - pos
	f.y = 0.0
	RingLevel.place(foe, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), pos))
	foe.velocity = Vector3.ZERO


func _calm() -> void:
	paused = false
	c.held_override = false
	c.quick_override = false
	c.guard_override = false
	c._wait_release = false
	c.drop_all()
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormStone.GROUP, GustLift.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	for b: Node in [p, foe]:
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	mode._respawns.clear()
	mode._hide(p, false)
	mode._hide(foe, false)
	rules.reset_game()
	rules._stale.clear()
	BendR3._reset(BendCaster.of(p))
	BendR3.hits_log.clear()


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
	foe.held = true
	# (where he went in: the rules' record of the fall; RingMode hides him at his spout as it hears of it)
	rules.ko.connect(func(b: Node3D, _by: Node, _pc: float, _tg: String, _l: int) -> void:
		var at := b.global_position
		if not rules.falls.is_empty():
			at = (rules.falls.back() as Dictionary).get("pos", at)
		_kos.append([b, at]))
	var fs: Variant = load("res://data/ring/feel.json") if FileAccess.file_exists("res://data/ring/feel.json") else null
	print("  stock %s, tag %s, light %s, ticks %d, feel.json %s" % [RingRules.stock_on(), tag, light,
			Engine.physics_ticks_per_second, "present" if fs != null else "none"])
	if part == "ko":
		await _ko_splash()
	elif part == "knock":
		await _knock()
	else:
		await _knock()
		await _jab_pop()
		await _perfect()
		await _ko_splash()
		if tag == "after":
			await _final_moment()
	paused = false
	Engine.time_scale = 1.0
	RingRules.rule_set_override = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	print("FEEL SHOTS DONE")
	quit(0)


# ---------------------------------------------------------------- an earth Spike landing on the bot at 10 m
func _knock() -> void:
	await _calm()
	var e := mode.player_end
	_place(at_s(e, 8.0, 0.0), at_s(e, 18.0, 0.0))
	_place_foe(at_s(e, 18.0, 0.0), p.global_position)
	rules.reset_pct(foe, 90.0)
	p.hotbar.select(0)
	await _secs(0.8)
	var kn := BendKnock.of(foe)
	var k0 := kn.knocks
	c.held_override = true
	for i in 240:
		if c.state == SwayCaster.State.FULL:
			break
		await physics_frame
	c.held_override = false
	var hit := false
	paused = true
	for i in 120:
		await _step()
		if kn.knocks > k0:
			hit = true
			break
	if not hit:
		# (the cast missed: the same hit given by hand, its stone's look at the body)
		paused = false
		var way := (foe.global_position - p.global_position)
		way.y = 0.0
		way = way.normalized()
		BendStatus.hurt(foe, 20.0, foe.global_position + Vector3.UP, way, p, -1.0, {"tag": "stone_form/spike", "from": p.global_position})
		BendLooks.burst(foe.global_position + Vector3.UP, "stone", 30, way, 50.0, 6.0, 0.4)
		print("  (knock: the cast missed; the hit given by hand)")
		paused = true
	var side := _hi(at_s(e, 13.0, 9.5, 5.5), foe.global_position + Vector3.UP * 1.0)
	var rows := await _strip8(side, "knock")
	_sheet(rows, "r4_impact_knock_strip_" + tag)
	await _secs(2.0)


# ---------------------------------------------------------------- the jab string into the Pop at 2 m
func _jab_pop() -> void:
	await _calm()
	var e := mode.player_end
	_place(at_s(e, 10.0, 0.0), at_s(e, 12.0, 0.0))
	_place_foe(at_s(e, 12.0, 0.0), p.global_position)
	rules.reset_pct(foe, 30.0)
	await _secs(0.5)
	for j in 2:
		c.quick_override = true
		for i in 120:
			if c.state == SwayCaster.State.FULL:
				break
			await physics_frame
		c.quick_override = false
		await _secs(0.2)
		_place_foe(at_s(e, 12.0, 0.0), p.global_position)
		var kn0 := BendKnock.peek(foe)
		if kn0 != null:
			kn0.reset()
	var n0 := BendR3.hits_log.size()
	c.quick_override = true
	for i in 120:
		if c.state == SwayCaster.State.FULL:
			break
		await physics_frame
	c.quick_override = false
	paused = true
	var hit := false
	for i in 60:
		await _step()
		if BendR3.hits_log.size() > n0:
			hit = true
			break
	print("  jab string: %d hits logged, the Pop landed %s" % [BendR3.hits_log.size(), hit])
	var side := _hi(at_s(e, 11.0, 5.5, 2.2), at_s(e, 11.0, 0.0, 1.0))
	var rows := await _strip8(side, "jab_pop")
	_sheet(rows, "r4_impact_jab_pop_strip_" + tag)
	await _secs(2.0)


# ---------------------------------------------------------------- a perfect Catch
func _perfect() -> void:
	await _calm()
	var e := mode.player_end
	_place(at_s(e, 8.0, 0.0), at_s(e, 13.0, 0.0))
	_place_foe(at_s(e, 13.0, 0.0), p.global_position)
	await _secs(0.6)
	var cspec: Dictionary = (SwayMoves.move("stone_catch").bend as Dictionary).catch
	var z := BendZone.make(p, "catch", p.global_position, cspec, BendCaster.of(p).facing())
	var res: Array[String] = z.results
	await _secs(0.1)
	var chest := p.global_position + Vector3.UP * 1.2
	var dir := (chest - NpcSenses.chest_of(foe)).normalized()
	BendBolt.launch(foe, chest - dir * 4.1, dir, STONE)
	paused = true
	for i in 60:
		await _step()
		if BendZone.held_stone(p) != null:
			break
	print("  the catch: %s" % [res])
	var side := _hi(at_s(e, 10.5, 5.0, 2.4), at_s(e, 10.0, 0.0, 1.2))
	var rows := await _strip8(side, "perfect")
	_sheet(rows, "r4_impact_perfect_strip_" + tag)
	await _secs(1.5)


# ---------------------------------------------------------------- a fall into the water
## A camera high over the lip nearest the fall (`lp`), to one side, looking at where he went in (kept inside the tank, as
## RingWater.ko_splash keeps it), 2.5 m over the water.
func _splash_cam(kp: Vector3, n: Vector3, lp: Vector3) -> Camera3D:
	var w := ring.water
	var l := w.to_local(kp)
	l.x = clampf(l.x, -w.tank_half.x + 0.8, w.tank_half.x - 0.8)
	l.z = clampf(l.z, -w.tank_half.y + 0.8, w.tank_half.y - 0.8)
	l.y = w.level_y
	var at := w.to_global(l)
	var side := n.cross(Vector3.UP).normalized()
	return _hi(lp + side * 7.0 - n * 1.0 + Vector3.UP * 4.5, at + Vector3.UP * 2.5)


## The foe thrown off the side lip from 3 m in by a Boulder at a high %: [the KO's place, the lip's outward normal, the lip's
## point], or [] when no fall came.
func _throw_out(pct: float, last := false) -> Array:
	await _calm()
	if last:
		(rules._sk(foe) as Dictionary)["stocks"] = 1
	var e := mode.player_end
	var spot := at_s(1 - e, 9.0, -4.0)
	var lip := ring.nearest_lip(spot + ring.global_basis.z * -10.0)
	var n: Vector3 = lip.normal
	var foe_at := Vector3(lip.point) - n * 3.0
	foe_at.y = ring.top() + 0.05
	_place_foe(foe_at, foe_at - n)
	_place(foe_at - n * 5.0, foe_at)
	await _secs(0.6)
	rules.reset_pct(foe, pct)
	_kos.clear()
	BendStatus.hurt(foe, 20.0, foe.global_position + Vector3.UP, n, p, -1.0, {"tag": "stone_form/cannonball", "from": p.global_position})
	BendStatus.knock(foe, n * 6.0, p, {"tag": "stone_form/cannonball", "from": p.global_position})
	for i in 300:
		if not _kos.is_empty():
			break
		await physics_frame
	if _kos.is_empty():
		return []
	return [_kos[0][1], n, Vector3(lip.point)]


func _ko_splash() -> void:
	var r := await _throw_out(260.0)
	if r.is_empty():
		print("  (no fall came)")
		return
	var kp: Vector3 = r[0]
	var n: Vector3 = r[1]
	var lp: Vector3 = r[2]
	var cam := _splash_cam(kp, n, lp)
	paused = true
	var imgs: Array = []
	var at := 0
	for want: int in [8, 22, 45]:
		while at < want:
			await _step()
			at += 1
		imgs.append(await _draw_from(cam))
	p.camera.make_current()
	paused = false
	var name := "r4_impact_ko_splash_" + (tag if tag == "before" else light)
	print("FEEL_SHOT ko_splash at %s, frames 8/22/45 (0.16/0.44/0.90 s)" % kp.snapped(Vector3.ONE * 0.1))
	_sheet([imgs], name, 0.5)
	await _secs(2.5)


# ---------------------------------------------------------------- the last fall's slow beat
func _final_moment() -> void:
	var r := await _throw_out(260.0, true)
	if r.is_empty():
		print("  (no last fall came)")
		return
	var kp: Vector3 = r[0]
	var n: Vector3 = r[1]
	var lp: Vector3 = r[2]
	var cam := _splash_cam(kp, n, lp)
	cam.make_current()
	var imgs: Array = []
	var f := 0
	while imgs.size() < 8 and f < 120:
		await RenderingServer.frame_post_draw
		f += 1
		if f % 4 == 0:
			imgs.append(_now_img())
			print("FEEL_SHOT final frame %d real %.2f s time_scale %.3f" % [imgs.size() - 1, f / 50.0, Engine.time_scale])
	p.camera.make_current()
	_sheet([imgs.slice(0, 4), imgs.slice(4, 8)], "r4_impact_final_moment_strip")
	await _secs(1.0)
