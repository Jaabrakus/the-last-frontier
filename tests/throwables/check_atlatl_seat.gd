extends SceneTree
## Headless check that the atlatl's dart stays seated on the board in every held pose
## (ThrowableAtlatl._place_held): the seated gap between the dart and the grip wrap,
## lashings and bannerstone is only ~3 mm (tools/models/atlatl.py verify: "seated dart
## shaft clears ..."), so any rotation of the dart relative to the board would cut through
## them.
##   Godot --headless --path . -s tests/throwables/check_atlatl_seat.gd
## Loads the level, installs the throwables with ThrowableKit (player.gd untouched) and
## drives the atlatl with scripted input through: carry, raising (aim 0..1), holding,
## lowering with RMB (aim 1..0), raising again and the cast. Checks every tick:
##   seated  (carry, raise, hold, lower)  dart rotation relative to the board < 0.05 deg
##                                        and the Nock on the Spur (< 1 mm)
##   flick   (RELEASING)                  Nock still on the Spur; the only relative rotation
##                                        is about the board's X axis and it lifts the dart's
##                                        point away from the board (never into it); at the
##                                        release the dart lies on the throw line
## Prints ATLATL SEAT CHECK PASSED or FAILED (exit code 1).

const DT := 1.0 / 120.0

var player: FrontierPlayer
var w: ThrowableAtlatl
var fails := 0
var stats := {"seated_n": 0, "seated_max_deg": 0.0, "seated_max_mm": 0.0, "mid_raise_n": 0,
		"flick_n": 0, "flick_max_deg": 0.0, "flick_min_lift_deg": 1e9, "flick_off_axis_deg": 0.0,
		"flick_max_mm": 0.0, "release_line_deg": -1.0}


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	if player == null:
		print("ATLATL SEAT CHECK FAILED (level or player failed to load)")
		quit(1)
		return
	player.ignore_mouse_capture = true
	var keys: Array[String] = ["atlatl"]
	var kit := ThrowableKit.install(player, keys)
	w = kit["atlatl"]
	w.use_scripted_input = true
	w.scripted_input = {"fire": false, "cancel": false}
	await _frames(30)
	player.switch_weapon("pistol")
	await _frames(20)
	if player.weapon and player.weapon.model:
		player.weapon.model.visible = false
	w.equip()
	await _frames(int(w.equip_time * 120) + 10)
	# Stand in the lane and look at the 25 m dummy.
	player.global_position = Vector3(0.0, 0.3, -21.0)
	player.velocity = Vector3.ZERO
	await _frames(20)
	for i in 5:
		var d := Vector3(0.0, 1.3, -45.0) - player.camera.global_position
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _frames(3)

	await _sample(20)                       # carry
	w.scripted_input["fire"] = true
	await _sample(60)                       # raise and hold (aim 0 -> 1 in aim_in_time)
	w.scripted_input["cancel"] = true
	await _sample(2)
	w.scripted_input["fire"] = false
	await _sample(50)                       # lowered with RMB (aim 1 -> 0)
	w.scripted_input["fire"] = true
	await _sample(110)                      # raise again to full wind-up
	var thrown_before := w.last_thrown
	w.scripted_input["fire"] = false
	for i in 80:                            # the cast: flick, then the dart leaves
		await _sample(1)
		if w.last_thrown != thrown_before:
			break

	print("    seated ticks %d (%d mid-raise/lower, 0 < aim < 1): max relative rotation %.4f deg, nock-spur %.3f mm"
			% [stats.seated_n, stats.mid_raise_n, stats.seated_max_deg, stats.seated_max_mm])
	print("    flick ticks %d: relative rotation up to %.1f deg, min lift %.3f deg, off-axis %.4f deg, nock-spur %.3f mm"
			% [stats.flick_n, stats.flick_max_deg, stats.flick_min_lift_deg if stats.flick_n > 0 else 0.0,
			stats.flick_off_axis_deg, stats.flick_max_mm])
	_expect(stats.seated_n > 100 and stats.mid_raise_n >= 20, "sampled carry, raise, hold and lower (%d ticks, %d mid-way)"
			% [stats.seated_n, stats.mid_raise_n])
	_expect(stats.seated_max_deg < 0.05, "dart rigid on the board while seated (max %.4f deg)" % stats.seated_max_deg)
	_expect(stats.seated_max_mm < 1.0, "nock on the spur while seated (max %.3f mm)" % stats.seated_max_mm)
	_expect(stats.flick_n > 5, "sampled the release flick (%d ticks)" % stats.flick_n)
	_expect(stats.flick_off_axis_deg < 0.05, "flick rotates the dart only about the board's X axis (%.4f deg off)" % stats.flick_off_axis_deg)
	_expect(stats.flick_min_lift_deg > -0.05, "flick lifts the dart's point away from the board, never into it (min %.3f deg)"
			% stats.flick_min_lift_deg)
	_expect(stats.flick_max_mm < 1.0, "nock on the spur through the flick (max %.3f mm)" % stats.flick_max_mm)
	_expect(w.last_thrown != thrown_before, "the dart was cast")
	_expect(stats.release_line_deg >= 0.0 and stats.release_line_deg < 1.0,
			"at the release the dart lies on the throw line (%.3f deg)" % stats.release_line_deg)
	print("ATLATL SEAT CHECK %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(0 if fails == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		if w.active:
			w.tick(DT)


## Ticks n times and measures the dart against the board after each tick.
func _sample(n: int) -> void:
	for i in n:
		await _frames(1)
		if not w.dart.visible:
			continue
		var bm := w.model.global_basis.orthonormalized()
		var bd := w.dart.global_basis.orthonormalized()
		var spur := w.model.global_transform * ThrowableModels.marker_pos(w.model, "Spur")
		var nock := w.dart.global_transform * ThrowableModels.marker_pos(w.dart, "Nock")
		var mm := spur.distance_to(nock) * 1000.0
		# Dart axes in board space.
		var rel := (bm.inverse() * bd).orthonormalized()
		var deg := rad_to_deg(rel.get_rotation_quaternion().get_angle())
		if w.state == Throwable.State.RELEASING:
			stats.flick_n += 1
			stats.flick_max_deg = maxf(stats.flick_max_deg, deg)
			stats.flick_max_mm = maxf(stats.flick_max_mm, mm)
			var fwd := -rel.z                       # dart forward in board space
			stats.flick_min_lift_deg = minf(stats.flick_min_lift_deg, rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0))))
			stats.flick_off_axis_deg = maxf(stats.flick_off_axis_deg, rad_to_deg(asin(clampf(absf(fwd.x), 0.0, 1.0))))
			stats.flick_off_axis_deg = maxf(stats.flick_off_axis_deg, rad_to_deg(asin(clampf(absf(rel.x.y), 0.0, 1.0))))
			if w._phase_left <= DT * 1.5:
				stats.release_line_deg = rad_to_deg((-bd.z).angle_to(w._aim_dir))
		else:
			stats.seated_n += 1
			if w.aim > 0.02 and w.aim < 0.98:
				stats.mid_raise_n += 1
			stats.seated_max_deg = maxf(stats.seated_max_deg, deg)
			stats.seated_max_mm = maxf(stats.seated_max_mm, mm)
