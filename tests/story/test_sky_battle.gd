extends SceneTree
## The sky battle (SkyBattle, scripts/story/sky_battle.gd; docs/main_story.md mission 11, Two Fires; the owner,
## 2026-10-02: "two air ships fighting, they break the sky and one crashes down") on the real level, headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_sky_battle.gd -- [speed=4]
##   stage    begin(level, camp, crash_at, {heading, sky_mark}) puts two ships under it: the cutter (sky_galleon.glb) and
##            the hunter (sky_hunter.glb, or the galleon tinted dark until it exists); coming in high (250-400 m over the
##            ground), 220-420 m up through the fight, in the camp's north-north-east sky (bearings -20..90 deg),
##            0.25-1.3 km off; never faster than 80 m/s. sky_mark: the wonder's giant on the scene's night (12 Nov 1757,
##            21 h: WorldClock.celestial_basis x the sky's wonder_planet_eq)
##   fight    the circling lasts 14-20 s and the hand-over comes 25-38 s in, the cutter down by 45 s, the hunter gone by
##            48 s; volleys of glowing shot (a core and a trail each), both ships struck a few times, most shots passing
##   reveal   the great shot strikes the sky beside the giant (8-20 deg off it, never on it), where the hunter goes
##   flashes  sky_flash(amount, dir) at the hits (amount 0..1, dir a unit direction up from the camp), the sky struck at 1
##            (toward tear_point's dir); no ring of light stamped there (the first crack, SkyTear's, is the shock); the
##            cutter's landing flashes the one light over the pines
##   order    opened_fire, tear_point (a unit direction up in the sky, toward where the great shot burst), cutter_hit
##            (the cutter burns: a FireFx on it), cutter_falling (a WreckFall that has the very same ship, from where it
##            was), hunter_gone, finished: each once, in that order
##   fall     the cutter only comes down from the hand-over, and lands at crash_at (`landed`)
##   hunter   it climbs to where the sky was struck and is gone there (freed)
##   budget   never more than 40 shot nodes nor MAX_FX effects; at most one light of the battle's own, none once it is
##            over (the wreck's own one is WreckFall's); the battle frees itself after `finished`
##   pools    (the owner: "the sky galleon fighting is laggy") its shots' cores and trails, rings, spark and splinter
##            systems made once as it is made and reused: no node, process material or colour ramp made during the fight
##            (the cutter's struck fire apart); the ships draw only their far mesh (Galleon_LOD1) past LOD_M from the
##            camera, and cast no shadows; the wreck's two people (Rook, Ithel) built hidden while the ships come in, and
##            the very same ones lie in the wreck once it is down (not built on the landing's frame)
##   control  the player is never held: still processing, the camera still the player's, no time scale
##   skip     a second battle skipped at once: every signal in order, the wreck down, the hunter gone
## Ends with "SKY BATTLE TEST PASSED (<n> checks)" or "SKY BATTLE TEST FAILED (<f> of <n>)".

const ORDER := ["opened_fire", "tear_point", "cutter_hit", "cutter_falling", "hunter_gone", "finished"]

var checks := 0
var fails: Array[String] = []
## The raiders' camp and the wreck (two_fires.json places raiders_camp, wreck; the 1757 layer's wreck_yaw 60).
var camp := Vector3(835.0, 0.0, -265.0)
var crash := Vector3(1100.0, 0.0, -380.0)
var heading := deg_to_rad(60.0 + 90.0)
var got: Array[String] = []
var got_at := {}
var tear := Vector3.ZERO
var fell: WreckFall
var landed_n := 0
var flashes: Array = []          ## [amount, dir, battle clock]
var landed_at := -1.0
## The wonder's giant from the valley on Two Fires' night (12 Nov 1757, 21 h).
var giant := Vector3.ZERO


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


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.get_slice("=", 1)
	return d


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	paused = false
	var level := current_scene
	var player := level.get_node_or_null("Player") as FrontierPlayer if level else null
	_expect(level != null and player != null, "the level is up with the player")
	if level == null:
		_end()
		return
	if player:
		player.ignore_mouse_capture = true
	camp.y = FrontierTerrain.height_at(camp.x, camp.z)
	crash.y = FrontierTerrain.height_at(crash.x, crash.z)
	await _test_battle(level, player, float(_arg("speed", "4")))
	await _test_skip(level)
	_end()


func _record(sig: String, arg: Variant = null) -> void:
	got.append(sig)
	var sb := SkyBattle.find(self)
	got_at[sig] = sb.clock if sb else -1.0
	if sig == "tear_point":
		tear = arg
	if sig == "cutter_falling":
		fell = arg


func _connect(sb: SkyBattle) -> void:
	got.clear()
	got_at.clear()
	sb.opened_fire.connect(_record.bind("opened_fire"))
	sb.tear_point.connect(func(d: Vector3) -> void: _record("tear_point", d))
	sb.cutter_hit.connect(_record.bind("cutter_hit"))
	sb.cutter_falling.connect(func(wf: WreckFall) -> void: _record("cutter_falling", wf))
	sb.hunter_gone.connect(_record.bind("hunter_gone"))
	sb.finished.connect(_record.bind("finished"))
	flashes.clear()
	sb.sky_flash.connect(func(a: float, d: Vector3) -> void: flashes.append([a, d, sb.clock]))


static func _bearing(from: Vector3, to: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(to.x - from.x, -(to.z - from.z))), 360.0)    # (0 north, 90 east)


## The bearing as -180..180 (west of north negative).
static func _bearing_s(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(atan2(to.x - from.x, -(to.z - from.z)))


## The giant's way from the valley on the scene's night, as the sky draws it (transpose(celestial) * wonder_planet_eq).
static func _giant_on_the_night() -> Vector3:
	var c := WorldClock.new()
	c.set_date(316.0, 1757)
	c.set_time(21.0)
	var g := (c.celestial_basis().transposed() * WonderLook.GIANT_EQ.normalized()).normalized()
	c.free()
	return g


func _test_battle(level: Node, player: FrontierPlayer, spd: float) -> void:
	print("-- stage")
	giant = _giant_on_the_night()
	print("   the giant on the night: bearing %.0f, %.0f deg up" % [_bearing(Vector3.ZERO, giant), rad_to_deg(asin(giant.y))])
	var sb := SkyBattle.begin(level, camp, crash, {"heading": heading, "speed": spd, "sky_mark": giant})
	_expect(sb != null and SkyBattle.find(self) == sb, "begin() makes the battle (found by its group)")
	if sb == null:
		return
	_connect(sb)
	await _frames(2)
	var cutter := sb.cutter
	var hunter := sb.hunter
	_expect(cutter != null and hunter != null and cutter.get_parent() == sb and hunter.get_parent() == sb,
			"two ships under it: the cutter and the hunter")
	if cutter == null or hunter == null:
		return
	_expect(sb.hunter_model == SkyBattle.HUNTER_MODEL or not ResourceLoader.exists(SkyBattle.HUNTER_MODEL),
			"the hunter is %s" % sb.hunter_model.get_file())
	if sb.hunter_model != SkyBattle.HUNTER_MODEL:
		var dark := false
		for m in hunter.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			for si in mi.get_surface_override_material_count():
				var o := mi.get_surface_override_material(si) as StandardMaterial3D
				if o and not String(o.resource_name).begins_with("EtheriumGlow") and o.albedo_color.v < 0.4:
					dark = true
		_expect(dark, "the stand-in hunter (the galleon) is tinted dark")
	var cam0 := root.get_viewport().get_camera_3d()
	print("-- pools")
	var ps := sb.pool_sizes()
	print("   ", ps)
	_expect(int(ps.sparks) == SkyBattle.SPARK_POOL and int(ps.splinters) == SkyBattle.SPLINTER_POOL
			and int(ps.rings) == SkyBattle.RING_POOL and int(ps.cores) == SkyBattle.MAX_SHOTS and int(ps.trails) == SkyBattle.MAX_SHOTS,
			"its effects made once as it is made: %d spark and %d splinter systems, %d rings, %d cores and trails" % [int(ps.sparks),
			int(ps.splinters), int(ps.rings), int(ps.cores)])
	var made0 := _made(sb)
	var unshadowed := true
	for shp: Node3D in [cutter, hunter]:
		for g in shp.find_children("*", "GeometryInstance3D", true, false):
			unshadowed = unshadowed and (g as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_expect(unshadowed, "the ships cast no shadows")
	var made_new: Array[String] = []
	var people0 := {}
	var lod_bad := 0
	var lod_seen := 0
	print("   circle %.1f s (sweep %.0f deg, way %+d), hit at %.1f, fall at %.1f, gone at %.1f" % [sb.t_run - sb.t_circle,
			rad_to_deg(sb._omega * (sb.t_run - sb.t_circle)), int(sb._s), sb.t_hit, sb.t_fall, sb.t_gone])
	print("-- fight")
	var alt := Vector2(INF, -INF)
	var off := Vector2(INF, -INF)
	var bear := Vector2(INF, -INF)
	var vmax := 0.0
	var last := [cutter.global_position, hunter.global_position]
	var last_clock := sb.clock
	var max_shots := 0
	var max_fx := 0
	var max_lights := 0
	var held := false
	var before_fall := Vector3.ZERO
	var burning := false
	var heights: Array[float] = []
	var enter_alt := Vector2(cutter.global_position.y - maxf(camp.y, crash.y), hunter.global_position.y - maxf(camp.y, crash.y))
	enter_alt = Vector2(minf(enter_alt.x, enter_alt.y), maxf(enter_alt.x, enter_alt.y))
	var handed := false
	var jump := INF
	var hunter_last := hunter.global_position
	var shock_seen := false
	landed_at = -1.0
	var light_at_land := Vector3.INF
	var lit_at_land := false
	var n := 0
	var y0 := maxf(camp.y, crash.y)
	while is_instance_valid(sb) and not got.has("finished") and n < 6000:
		var was_falling := got.has("cutter_falling")
		if not was_falling and is_instance_valid(cutter):
			before_fall = cutter.global_position
		await process_frame
		n += 1
		if not is_instance_valid(sb):
			break
		max_shots = maxi(max_shots, sb.shot_nodes())
		max_fx = maxi(max_fx, sb.fx_nodes())
		max_lights = maxi(max_lights, sb.find_children("*", "OmniLight3D", true, false).size())   # (the WreckFall's is not under it)
		if people0.is_empty() and sb.clock > 3.0 and sb._people.size() == 2:
			people0 = sb._people.duplicate()
		if n % 4 == 0:
			var now := _made(sb)
			for k: String in now:
				if not made0.has(k) and made_new.size() < 6:
					made_new.append(k)
			var eye := root.get_viewport().get_camera_3d().global_position
			for i in 2:
				var shp: Node3D = sb.cutter if i == 0 else sb.hunter
				if shp == null or not is_instance_valid(shp):
					continue
				var dd := eye.distance_to(shp.global_position)
				if dd < SkyBattle.LOD_M * 1.3 or sb.clock < 0.5:
					continue
				lod_seen += 1
				for mi in shp.find_children("*", "MeshInstance3D", true, false):
					if (mi as MeshInstance3D).visible != String(mi.name).begins_with("Galleon_LOD1"):
						lod_bad += 1
						break
		if player and (not player.can_process() or Engine.time_scale != 1.0 or root.get_viewport().get_camera_3d() != cam0):
			held = true
		var dtc := sb.clock - last_clock
		last_clock = sb.clock
		for i in 2:
			var s: Node3D = cutter if i == 0 else hunter
			if not is_instance_valid(s) or (i == 1 and sb.hunter == null):
				continue
			var p := s.global_position
			var step := p.distance_to(last[i])
			last[i] = p
			if sb.clock > 3.0 and sb.clock < sb.t_fall and dtc > 0.0:
				vmax = maxf(vmax, step / dtc)
				alt = Vector2(minf(alt.x, p.y - y0), maxf(alt.y, p.y - y0))
				off = Vector2(minf(off.x, Vector2(p.x - camp.x, p.z - camp.z).length()), maxf(off.y, Vector2(p.x - camp.x, p.z - camp.z).length()))
				var b := _bearing_s(camp, p)
				bear = Vector2(minf(bear.x, b), maxf(bear.y, b))
		if got.has("cutter_hit") and not was_falling and is_instance_valid(cutter):
			burning = burning or cutter.find_child("StruckFire", true, false) is FireFx
		if not was_falling and got.has("cutter_falling") and fell != null and fell.ship != null:
			handed = fell.ship == cutter
			jump = fell.ship.global_position.distance_to(before_fall)
		if was_falling and fell != null and is_instance_valid(fell) and fell.ship != null and is_instance_valid(fell.ship) and n % 6 == 0:
			heights.append(fell.ship.global_position.y)
		if landed_at < 0.0 and fell != null and is_instance_valid(fell) and fell.is_landed():
			landed_at = sb.clock
		if landed_at >= 0.0 and sb.clock < landed_at + 0.5 and sb.light.visible and not lit_at_land:
			light_at_land = sb.light.global_position
			lit_at_land = true
		if sb.hunter != null and is_instance_valid(sb.hunter):
			hunter_last = sb.hunter.global_position
		shock_seen = shock_seen or sb.find_child("SkyShock", true, false) != null
	_expect(enter_alt.x >= 250.0 and enter_alt.y <= 400.0, "they come in high: %.0f-%.0f m over the ground" % [enter_alt.x, enter_alt.y])
	_expect(alt.x > 220.0 and alt.y < 420.0, "high through the fight: %.0f-%.0f m over the ground" % [alt.x, alt.y])
	_expect(bear.x > -20.0 and bear.y < 90.0, "in the camp's north-north-east sky: bearings %.0f-%.0f deg" % [bear.x, bear.y])
	_expect(off.x > 250.0 and off.y < 1300.0, "%.0f-%.0f m off the camp" % [off.x, off.y])
	print("   the circle's middle %.0f m off the camp, bearing %.0f deg" % [Vector2(sb._c.x - camp.x, sb._c.z - camp.z).length(),
			_bearing(camp, sb._c)])
	_expect(vmax < 80.0, "never faster than 80 m/s (%.0f)" % vmax)
	print("-- order")
	print("   ", got, " at ", got_at)
	_expect(got == ORDER, "the signals once each in order: %s" % ", ".join(got))
	var circle_s := sb.t_run - sb.t_circle if is_instance_valid(sb) else 0.0
	_expect(not is_instance_valid(sb) or (circle_s >= 14.0 and circle_s <= 20.0), "the circling lasts %.1f s" % circle_s)
	var fall_t := float(got_at.get("cutter_falling", -1.0))
	_expect(fall_t > 25.0 and fall_t < 38.0, "the hand-over %.1f s in" % fall_t)
	_expect(landed_at > fall_t and landed_at < 45.0, "the cutter down %.1f s in" % landed_at)
	_expect(float(got_at.get("hunter_gone", 99.0)) < 48.0, "the hunter gone %.1f s in" % float(got_at.get("hunter_gone", -1.0)))
	_expect(tear.is_normalized() and tear.y > 0.25, "tear_point: a unit direction up in the sky (%.0f deg up, bearing %.0f)"
			% [rad_to_deg(asin(clampf(tear.y, -1.0, 1.0))), _bearing(Vector3.ZERO, tear)])
	var off_giant := rad_to_deg(tear.angle_to(giant))
	_expect(off_giant > 8.0 and off_giant < 20.0, "the sky struck beside the giant: %.1f deg off it (8-20)" % off_giant)
	_expect(burning, "struck, the cutter burns (a FireFx on it) before it falls")
	print("-- flashes")
	var sane := flashes.size() >= 6
	var big: Array = []
	for f: Array in flashes:
		var d: Vector3 = f[1]
		sane = sane and float(f[0]) > 0.0 and float(f[0]) <= 1.0 and d.is_normalized() and d.y > 0.1
		if float(f[0]) >= 0.99:
			big = f
	_expect(sane, "sky_flash at the hits: %d, each 0..1 toward a point up in the sky from the camp" % flashes.size())
	var big_off := rad_to_deg((big[1] as Vector3).angle_to(tear)) if not big.is_empty() else 180.0
	_expect(not big.is_empty() and big_off < 1.0 and absf(float(big[2]) - float(got_at.get("tear_point", -9.0))) < 0.1,
			"the sky struck flashes it full, toward the tear (%.1f deg off it)" % big_off)
	_expect(not shock_seen, "no ring stamped where the sky was struck (the first crack is the shock)")
	_expect(lit_at_land and fell != null and Vector2(light_at_land.x - fell.at.x, light_at_land.z - fell.at.z).length() < 1.0
			and light_at_land.y > fell.at.y + 10.0, "the cutter down: the one light flashes over the pines where it lies")
	print("-- fight's count")
	var st: Dictionary = sb.stats if is_instance_valid(sb) else {}
	print("   ", st)
	_expect(int(st.get("volleys", 0)) >= 8 and int(st.get("shots", 0)) >= 24, "volleys (%d) and shots (%d)"
			% [int(st.get("volleys", 0)), int(st.get("shots", 0))])
	_expect(int(st.get("hits_cutter", 0)) >= 4 and int(st.get("hits_hunter", 0)) >= 2, "both struck: the cutter %d times, the hunter %d"
			% [int(st.get("hits_cutter", 0)), int(st.get("hits_hunter", 0))])
	print("-- fall")
	_expect(handed and jump < 3.0, "the WreckFall took the very same ship from where it was (%.2f m on in a frame)" % jump)
	_expect(fell != null and fell.ship == null, "the WreckFall had the cutter and it is down (its ship swapped for the wreck)")
	_expect(fell != null and is_instance_valid(fell) and fell.is_landed(), "the wreck is down")
	if fell != null and is_instance_valid(fell):
		var d := Vector2(fell.frame.origin.x - crash.x, fell.frame.origin.z - crash.z).length()
		_expect(d < 1.0, "at crash_at (%.2f m)" % d)
	var down := heights.size() > 4
	for i in range(1, heights.size()):
		down = down and heights[i] <= heights[i - 1] + 0.5
	_expect(down, "it only came down (%d samples from %.0f m)" % [heights.size(), heights[0] - crash.y if heights.size() > 0 else 0.0])
	print("-- hunter")
	var ang := rad_to_deg((hunter_last - camp).angle_to(tear))
	_expect(not is_instance_valid(hunter), "the hunter is gone (freed)")
	_expect(ang < 4.0, "it went where the sky was struck (%.1f deg off it, seen from the camp)" % ang)
	print("-- budget")
	_expect(max_shots <= 40 and max_shots > 0, "at most 40 shot nodes (%d)" % max_shots)
	_expect(max_fx <= SkyBattle.MAX_FX, "at most %d effects (%d)" % [SkyBattle.MAX_FX, max_fx])
	_expect(max_lights <= 1, "one light of its own at most (%d)" % max_lights)
	_expect(made_new.is_empty(), "nothing made per hit: no new particle system, process material or ramp, mesh node under its shots and effects (%s)"
			% str(made_new))
	var pr: Variant = people0.get("Rook")
	var pi: Variant = people0.get("Ithel")
	var hidden_then := pr is NpcBody and pi is NpcBody
	_expect(hidden_then and fell != null and is_instance_valid(fell) and fell.rook() == pr and fell.ithel() == pi
			and (pr as NpcBody).visible and (pi as NpcBody).visible,
			"the wreck's people built as the ships came in (by %.1f s), and the very same ones in the wreck" % SkyBattle.PEOPLE_AT[1])
	_expect(lod_seen > 50 and lod_bad == 0, "past LOD_M the ships draw only their far mesh (%d of %d frames not)" % [lod_bad, lod_seen])
	var wait := 0
	while is_instance_valid(sb) and wait < 600:          # (its last sounds still on their way: up to ~4 s at 343 m/s)
		await process_frame
		wait += 1
	_expect(not is_instance_valid(sb), "the battle frees itself once it is over (%.1f s after `finished`)" % (wait / 60.0))
	_expect(not held, "the player was never held (processing, its camera, no time scale)")


## Everything under the battle's shots and effects that a hit could make: particle systems with their process materials
## and colour ramps, mesh nodes (the cutter's struck fire, its own FireFx, apart).
static func _made(sb: SkyBattle) -> Dictionary:
	var out := {}
	for root_name: String in ["Shots", "Fx"]:
		var r := sb.get_node_or_null(root_name)
		if r == null:
			continue
		for c in r.find_children("*", "GeometryInstance3D", true, false):
			var fire := false
			var up := c.get_parent()
			while up != null and up != r:
				fire = fire or up is FireFx
				up = up.get_parent()
			if fire or c is FireFx:
				continue
			out["node %s" % c.name] = true
			if c is GPUParticles3D:
				var pm := (c as GPUParticles3D).process_material as ParticleProcessMaterial
				out["process material %d" % pm.get_instance_id()] = true
				if pm.color_ramp != null:
					out["ramp %d" % pm.color_ramp.get_instance_id()] = true
	return out


func _test_skip(level: Node) -> void:
	print("-- skip")
	var sb := SkyBattle.begin(level, camp, crash, {"heading": heading})
	if sb == null:
		_expect(false, "a second battle")
		return
	_connect(sb)
	await _frames(3)
	landed_n = 0
	sb.skip()
	_expect(got == ORDER, "skip(): every signal at once, in order: %s" % ", ".join(got))
	_expect(fell != null and is_instance_valid(fell) and fell.is_landed(), "the wreck down")
	_expect(sb.hunter == null, "the hunter gone")
	await _frames(10)


func _end() -> void:
	if fails.is_empty():
		print("SKY BATTLE TEST PASSED (%d checks)" % checks)
	else:
		print("SKY BATTLE TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("   - ", f)
	quit(0 if fails.is_empty() else 1)
