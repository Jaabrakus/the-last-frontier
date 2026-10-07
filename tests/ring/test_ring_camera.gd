extends SceneTree
## Round 4 READ's ring camera (RingCamera, data/ring/camera.json; RingMoves.cam_bias; FrontierPlayer's camera lines), on
## round 3's test deck (tests/ring/r3_move_rig.gd: the bare ring's player with a RingMoves, a bot held there):
##   numbers   variant A (close) leaves every round-3 number as it was (the deck's arm 5.25 m, the pivot 0.3 m up, centred,
##             level, the field of view 52.5); B, C and D apply theirs (arm, pivot, shoulder, tilt, field of view)
##   default   the default is camera.json's ("high", C), read when the player has chosen none
##   hidden    METRIC hidden_m per variant, measured in the engine: the player aims at a chest 8, 15 and 22 m away; a
##             chest-high shot comes from there straight on and from 20 degrees either side, the player in his idle guard
##             and in a cast pose (Earth Shove's press, SwayPose); on each physics step (eight sub-steps) the line from the
##             camera to the shot's centre is tested against capsules fitted to his skeleton's bones (RingCamera.
##             body_capsules) and the shot's path while hidden summed: the worst and the mean. C's tilt and field of view
##             swept beside it (C_SWEEP); the default must be the best centred variant. deck_behind_m: how far behind his feet the frame's bottom edge meets the deck at the default
##             pitch (level) and aiming at a chest 15 m off; the body's place on a 1280x720 screen aiming at a chest 15 m
##             off (for HUD: feet and head y)
##   launch    a launch (BendStatus.knock) never turns the camera: its basis, the yaw and the pitch unchanged through it
##   lock-on   nothing follows or turns toward the opponent: the bot walked 4 m across, the camera unchanged; the camera's
##             parents the player's own
##   hits      under each variant a bolt (Fire Blast's punch, aim help off) cast at a bot 15 m away with the crosshair on
##             his chest hits him, as under A; the crosshair is the screen's centre (get_aim_point on the camera's line)
##   menu      the Esc rows (RingMenu's Camera and Screen jolt) write GameSettings ring.camera and ring.jolt, read back
##   world     the open world (scenes/main.tscn): the camera today's (arm 4.1 m, centred, level, no ring framing)
## METRIC hidden_m, camera_default, deck_behind_m, body_screen_y, aim_unchanged_ok, open_world_cam_unchanged_ok.
## Last line "RING CAMERA PASSED" or "RING CAMERA FAILED"; exit 0 only on a pass.
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_camera.gd [-- only=hidden,...]

const NAME := "RING CAMERA"
const WATCHDOG_S := 420.0
const OWN_CFG := "user://ring_camera_test.cfg"
const Rig := preload("res://tests/ring/r3_move_rig.gd")
const DISTS := [8.0, 15.0, 22.0]
const ANGLES := [-20.0, 0.0, 20.0]
## The test shot's speed (m/s) and where it ends: this far before the chest toward its source (m).
const SHOT_MPS := 25.0
const END_M := 0.3
const SUBSTEPS := 8
## The cast pose measured: this move's press (SwayPose, as its lock begins on a mark at the aim).
const CAST_MOVE := "earth_shove"
## The chest's height over the feet (m: the rig's shoulders are at 1.28 m).
const CHEST_M := 1.15
## C's tilt and field of view swept beside the variants (the owner's default asked for "a slight built-in downward tilt"
## so the deck shows behind the feet; every degree of it lowers the camera as the player aims, and hides more).
const C_SWEEP := [{"tilt_deg": 0.0, "fov_add": 0.0}, {"tilt_deg": 2.0, "fov_add": 0.0}, {"tilt_deg": 4.0, "fov_add": 0.0},
		{"tilt_deg": 6.0, "fov_add": 0.0}, {"tilt_deg": 2.0, "fov_add": 2.5}, {"tilt_deg": 0.0, "fov_add": 6.0}]
const SCREEN := Vector2(1280.0, 720.0)
const WORDS := ["avatar", "bender", "bending", "korra", "stock", "blast zone", "smash", "meteor", "edge-guard"]

var checks := 0
var fails: Array[String] = []
var only := ""
var rig: Rig
var p: FrontierPlayer
var rm: RingMoves
var foe: NpcFighter
var results := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "off"                # (the camera's own aim: no help onto the bot)
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingCamera.reload()
	SwayCaster.free_override = true
	InputSetup.ensure()
	_run.call_deferred()


func _on(part: String) -> bool:
	return only == "" or part in only.split(",")


func _run() -> void:
	rig = Rig.new(self)
	var ok: bool = await rig.setup("earth")
	_expect(ok, "the rig: the bare ring's player on the test deck with a RingMoves")
	if not ok:
		_end()
		return
	p = rig.p
	rm = rig.pm
	if _on("numbers"):
		await _numbers()
	if _on("default"):
		await _default()
	if _on("hidden"):
		await _hidden()
	if _on("launch"):
		await _launch()
	foe = await rig.bot("fire", rig.at(23.0, 0.0), PI * 0.5)
	_expect(foe != null, "a bot on the test deck 15 m from the player")
	if foe != null and _on("lockon"):
		await _lock_on()
	if foe != null and _on("hits"):
		await _hits()
	if _on("menu"):
		await _menu()
	if _on("world"):
		await _world()
	_end()


func _end() -> void:
	RingCamera.override = ""
	RingMoves.geo_override = {}
	SwayCaster.free_override = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	RingCamera.reload()
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


# ---------------------------------------------------------------- helpers
## The player on the deck 8 m in from the -X lip, facing +X down its length, level, still; variant `k`, settled.
func _stage(k: String) -> void:
	RingCamera.override = k
	rig.release_all()
	rig.place(p, rig.at(8.0, 0.0), -PI * 0.5)
	p.pitch = 0.0
	await rig.secs(0.7)


func _chest() -> Vector3:
	return p.global_position + Vector3.UP * CHEST_M


## The crosshair (the camera's centre) put on `t`: the yaw and the pitch stepped onto it, the camera's place moving with them.
func _aim_at(t: Vector3) -> void:
	for i in 14:
		var cam := p.camera
		var to := t - cam.global_position
		var fwd := -cam.global_basis.z
		p.yaw = wrapf(p.yaw + wrapf(atan2(-to.x, -to.z) - atan2(-fwd.x, -fwd.z), -PI, PI), -PI, PI)
		p.pitch += atan2(to.y, Vector2(to.x, to.z).length()) - atan2(fwd.y, Vector2(fwd.x, fwd.z).length())
		await physics_frame
		await process_frame


## How far the crosshair is off `t` (deg).
func _off_deg(t: Vector3) -> float:
	var cam := p.camera
	return rad_to_deg((t - cam.global_position).angle_to(-cam.global_basis.z))


## How far behind his feet (toward the camera, m) the frame's bottom edge meets the deck now (test_ring_moves' measure).
func _deck_behind() -> float:
	var cam := p.camera
	var fwd := -cam.global_basis.z
	var half := deg_to_rad(cam.fov * 0.5)
	var down := fwd.rotated(cam.global_basis.x.normalized(), -half)
	if down.y >= -1e-4:
		return -INF
	var t := (Rig.D.y - cam.global_position.y) / down.y
	var hit := cam.global_position + down * t
	var back := Vector3(cam.global_position.x - p.global_position.x, 0.0, cam.global_position.z - p.global_position.z).normalized()
	return (hit - p.global_position).dot(back)


## Where world point `w` falls on a SCREEN-sized view of the camera (y px from the top; the field of view is vertical).
func _screen_y(w: Vector3) -> float:
	var cam := p.camera
	var d := w - cam.global_position
	var z := d.dot(-cam.global_basis.z)
	var y := d.dot(cam.global_basis.y) / z
	return SCREEN.y * 0.5 - y / tan(deg_to_rad(cam.fov * 0.5)) * SCREEN.y * 0.5


# ---------------------------------------------------------------- numbers
func _numbers() -> void:
	for k: String in ["close", "shoulder", "high", "high_shoulder"]:
		await _stage(k)
		var v := RingCamera.variant(k)
		var arm := 5.25 + float(v.get("arm_add", 0.0))
		var lift := 0.3 + float(v.get("pivot_add", 0.0))
		var sh := float(v.get("shoulder_m", 0.0))
		var tilt := deg_to_rad(float(v.get("tilt_deg", 0.0)))
		var fov := p.fov + float(v.get("fov_add", 0.0))
		var got := [p.spring_arm.spring_length, p.camera_pivot.position.y - p.eye_height, p.spring_arm.position.x,
				p.camera_tilt.rotation.x, p.camera.fov]
		var ok := absf(got[0] - arm) < 0.01 and absf(got[1] - lift) < 0.02 and absf(got[2] - sh) < 0.005 \
				and absf(got[3] + tilt) < 1e-4 and absf(got[4] - fov) < 0.05
		if k == "close":
			ok = ok and is_equal_approx(arm, 5.25) and is_equal_approx(lift, 0.3) and sh == 0.0 and tilt == 0.0 and is_equal_approx(fov, 52.5)
			_expect(ok, "A (close) leaves round 3's numbers: arm %.2f, pivot +%.2f, shoulder %.2f, tilt %.4f, fov %.1f" % got)
		else:
			_expect(ok, "%s (%s) applies its own: arm %.2f (%.2f), pivot +%.2f (%.2f), shoulder %.2f (%.2f), tilt %.2f deg (%.2f), fov %.1f (%.1f)" % [
					v.get("letter", "?"), k, got[0], arm, got[1], lift, got[2], sh, -rad_to_deg(got[3]), rad_to_deg(tilt), got[4], fov])
		_expect(String(v.get("label", "")) != "" and not _show_word(String(v.label) + " " + String(v.get("line", ""))),
				"%s has a label and a line with no show word (%s)" % [k, v.get("label", "")])


func _show_word(s: String) -> bool:
	var low := s.to_lower()
	for w: String in WORDS:
		if w in low:
			return true
	return false


# ---------------------------------------------------------------- default
func _default() -> void:
	RingCamera.override = ""
	RingCamera.reload()
	var k := RingCamera.key()
	print("METRIC camera_default %s (%s)" % [k, RingCamera.variant(k).get("letter", "?")])
	_expect(k == RingCamera.default_key() and k == "high", "the default with no choice made is camera.json's: %s (C)" % k)
	await rig.secs(0.7)
	var b := rm.cam_bias()
	_expect(String(b.get("variant", "")) == k and absf(float(b.arm) - 5.25 - float(RingCamera.variant(k).arm_add)) < 1e-4,
			"cam_bias carries the default's framing (%s, arm %.2f)" % [b.get("variant", ""), float(b.get("arm", 0.0))])


# ---------------------------------------------------------------- hidden
func _hidden() -> void:
	var rows: Array = []
	for k: String in ["close", "shoulder", "high", "high_shoulder"]:
		rows.append([k, k, {}])
	for o: Dictionary in C_SWEEP:
		rows.append(["high", "high tilt %.0f fov +%.1f" % [o.tilt_deg, o.fov_add], o])
	var hi := (RingCamera.data().variants as Dictionary).high as Dictionary
	var keep := hi.duplicate()
	for row: Array in rows:
		var k: String = row[0]
		hi.merge(row[2] as Dictionary, true)
		var r := await _hidden_of(k)
		hi.merge(keep, true)
		results[row[1]] = r
		print("METRIC hidden_m %s worst %.3f mean %.3f (idle worst %.2f, cast worst %.2f; %s) deck_behind_m pitch0 %.2f aimed15 %.2f body_screen_y feet %.0f head %.0f" % [
				row[1], r.worst, r.mean, r.idle_worst, r.cast_worst, r.cases, r.behind0, r.behind15, r.feet_y, r.head_y])
	var a: Dictionary = results.get("close", {})
	var dflt := RingCamera.default_key()
	var d: Dictionary = results.get(dflt, {})
	var best := ""
	for k: String in ["close", "high"]:
		if best == "" or float((results.get(k, {}) as Dictionary).get("worst", INF)) < float((results.get(best, {}) as Dictionary).get("worst", INF)):
			best = k
	print("METRIC camera_pick %s (the best centred by the worst hidden: close %.3f, high %.3f; the bar 1.0 m: %s)" % [best,
			float(a.get("worst", INF)), float(d.get("worst", INF)), float(results.get(best, {}).get("worst", INF)) <= 1.0])
	_expect(dflt == best and float(d.get("worst", INF)) <= 1.05, "the default (%s) is the best centred variant and keeps a shot in view until about its last metre (worst %.3f m hidden, A %.3f)" % [
			dflt, float(d.get("worst", INF)), float(a.get("worst", INF))])
	_expect(not d.is_empty() and float(d.mean) < float(a.get("mean", 0.0)), "the default hides less of an incoming shot than round 3's (mean %.2f against %.2f)" % [
			float(d.get("mean", INF)), float(a.get("mean", 0.0))])
	_expect(not d.is_empty() and float(d.behind15) >= float(a.get("behind15", INF)) - 0.05,
			"aiming at a chest 15 m off, the default shows as much deck behind the feet as round 3's (%.2f m against %.2f)" % [
			float(d.get("behind15", -INF)), float(a.get("behind15", 0.0))])
	_expect(int(d.get("caps", 0)) >= 20, "the capsules fitted to the skeleton (%d)" % int(d.get("caps", 0)))
	_expect(bool(d.get("posed", false)), "the cast pose measured is on the body (SwayPose posing)")
	print("METRIC deck_behind_m %s pitch0 %.2f aimed15 %.2f (A: %.2f, %.2f)" % [dflt, float(d.get("behind0", 0.0)),
			float(d.get("behind15", 0.0)), float(a.get("behind0", 0.0)), float(a.get("behind15", 0.0))])
	print("METRIC body_screen_y %s feet %.0f head %.0f (A: feet %.0f head %.0f; 1280x720, aiming at a chest 15 m off)" % [
			dflt, float(d.get("feet_y", 0.0)), float(d.get("head_y", 0.0)), float(a.get("feet_y", 0.0)), float(a.get("head_y", 0.0))])


## The hidden-shot metric under variant `k` (see the header): {worst, mean, idle_worst, cast_worst, cases, behind0,
## behind15, feet_y, head_y, caps}.
func _hidden_of(k: String) -> Dictionary:
	await _stage(k)
	var out := {"worst": 0.0, "mean": 0.0, "idle_worst": 0.0, "cast_worst": 0.0, "cases": "", "caps": 0}
	out.behind0 = _deck_behind()
	var all: Array[float] = []
	var worst_case := ""
	for pose: String in ["idle", "cast"]:
		for dist: float in DISTS:
			await _stage(k)
			var fwd := Vector3(1.0, 0.0, 0.0)
			var aim := _chest() + fwd * dist
			await _aim_at(aim)
			if is_equal_approx(dist, 15.0) and pose == "idle":
				out.behind15 = _deck_behind()
				out.feet_y = _screen_y(p.global_position)
				out.head_y = _screen_y(p.global_position + Vector3.UP * 1.62)
			var caster := SwayCaster.of(p)
			var mark: Node3D = null
			if pose == "cast" and caster != null:
				# (Earth Shove's press on the body: SwayPose's own clip; its lock's place a mark at the aim, as FormCast reads one)
				mark = Node3D.new()
				current_scene.add_child(mark)
				mark.global_position = aim
				caster.lock_started.emit(CAST_MOVE, mark)
				await rig.secs(0.15)
				out.posed = bool(out.get("posed", true)) and caster.pose != null and caster.pose.posing()
			var paths: Array = []
			for ang: float in ANGLES:
				var dir := fwd.rotated(Vector3.UP, deg_to_rad(ang))
				var src := _chest() + dir * dist
				var end := _chest() + dir * END_M
				paths.append({"src": src, "end": end, "at": src, "hid": 0.0, "done": false, "ang": ang})
			var left := paths.size()
			var dt := 1.0 / Engine.physics_ticks_per_second
			while left > 0:
				await physics_frame
				var caps := RingCamera.body_capsules(p.skeleton)
				out.caps = caps.size()
				var cam := p.camera.global_position
				for path: Dictionary in paths:
					if path.done:
						continue
					var to: Vector3 = path.end
					var from: Vector3 = path.at
					var step := minf(SHOT_MPS * dt, from.distance_to(to))
					var nxt := from + (to - from).normalized() * step
					for s in SUBSTEPS:
						var a := from.lerp(nxt, float(s) / SUBSTEPS)
						var b := from.lerp(nxt, float(s + 1) / SUBSTEPS)
						if RingCamera.hidden(cam, (a + b) * 0.5, caps):
							path.hid = float(path.hid) + a.distance_to(b)
					path.at = nxt
					if nxt.distance_to(to) < 1e-3:
						path.done = true
						left -= 1
			if pose == "cast" and caster != null:
				caster.fizzled.emit(CAST_MOVE, mark)
				mark.queue_free()
			for path: Dictionary in paths:
				var h := float(path.hid)
				all.append(h)
				out[pose + "_worst"] = maxf(float(out[pose + "_worst"]), h)
				if h >= float(out.worst):
					out.worst = h
					worst_case = "%s %.0f m %+.0f deg" % [pose, dist, float(path.ang)]
	var sum := 0.0
	for h in all:
		sum += h
	out.mean = sum / maxf(all.size(), 1.0)
	out.cases = "worst: " + worst_case
	return out


# ---------------------------------------------------------------- launch
func _launch() -> void:
	await _stage(RingCamera.default_key())
	await _aim_at(_chest() + Vector3(15.0, 0.0, 0.0))
	await physics_frame
	var b0 := p.camera.global_basis
	var y0 := p.yaw
	var pt0 := p.pitch
	var t0 := p.camera_tilt.rotation
	var worst := 0.0
	BendStatus.knock(p, Vector3(5.0, 8.0, 3.0), null)
	for i in 60:
		await physics_frame
		var b := p.camera.global_basis
		worst = maxf(worst, maxf((b.x - b0.x).length(), maxf((b.y - b0.y).length(), (b.z - b0.z).length())))
	_expect(worst < 1e-4 and absf(p.yaw - y0) < 1e-6 and absf(p.pitch - pt0) < 1e-6 and p.camera_tilt.rotation.is_equal_approx(t0),
			"a launch never turns the camera (its basis moved %.6f; yaw, pitch and tilt unchanged)" % worst)
	await rig.until(func() -> bool: return p.is_on_floor(), 3.0)


# ---------------------------------------------------------------- lock-on
func _lock_on() -> void:
	await _stage(RingCamera.default_key())
	rig.place(foe, rig.at(23.0, 0.0), PI * 0.5)
	await _aim_at(_chest() + Vector3(15.0, 0.0, 0.0))
	await physics_frame
	var x0 := p.camera.global_transform
	var worst := 0.0
	for i in 60:
		foe.global_position = rig.at(23.0, 4.0 * float(i + 1) / 60.0)
		await physics_frame
		worst = maxf(worst, (p.camera.global_transform.origin - x0.origin).length() + (p.camera.global_basis.z - x0.basis.z).length())
	_expect(worst < 1e-4, "the bot walked 4 m across: the camera never followed or turned toward him (%.6f)" % worst)
	var chain := []
	var n: Node = p.camera
	while n != null and n != p:
		chain.append(n.name)
		n = n.get_parent()
	_expect(n == p and not foe.is_ancestor_of(p.camera), "the camera's parents are the player's own (%s)" % [chain])
	rig.place(foe, rig.at(23.0, 0.0), PI * 0.5)


# ---------------------------------------------------------------- hits
func _hits() -> void:
	var spec: Dictionary = ((SwayMoves.move("fire_blast").get("bend", {}) as Dictionary).get("punch", {}) as Dictionary).duplicate(true)
	_expect(not spec.is_empty(), "Fire Blast's punch spec")
	var all_hit := true
	var aim_ok := true
	var help0 := MatchSetup.aim_help()
	for k: String in ["close", "shoulder", "high", "high_shoulder"]:
		await _stage(k)
		# (a fresh bot each time: one struck before answers the next shot with his guard)
		if is_instance_valid(foe):
			foe.queue_free()
		foe = await rig.bot("fire", rig.at(23.0, 0.0), PI * 0.5)
		await rig.secs(0.3)
		var chest := NpcSenses.chest_of(foe)
		await _aim_at(chest)
		var off := _off_deg(chest)
		var ap := p.get_aim_point()
		var line_off := rad_to_deg((ap - p.camera.global_position).angle_to(-p.camera.global_basis.z))
		aim_ok = aim_ok and line_off < 0.01
		var hit := [false, "", Vector3.INF]
		var before := get_nodes_in_group(BendBolt.GROUP)
		BendEffects.apply(p, "fire_blast", "punch", spec)
		for b in get_nodes_in_group(BendBolt.GROUP):
			if not before.has(b):
				var bb := b as BendBolt
				bb.struck.connect(func(who: Node, _d: float) -> void:
					if who == foe:
						hit[0] = true)
				bb.ended.connect(func(why: String) -> void:
					hit[1] = why
					hit[2] = bb.global_position)
		var t := await rig.until(func() -> bool: return bool(hit[0]), 1.5)
		print("    %s: crosshair %.2f deg off his chest, the aim point on the camera's line (%.4f deg), hit %s after %.2f s (ended %s at %s; bot at %s, chest %s, dead %s, aim point %s)" % [
				k, off, line_off, hit[0], t, hit[1], hit[2], foe.global_position, chest, foe.is_dead(), ap])
		all_hit = all_hit and bool(hit[0])
		await rig.secs(0.5)
	_expect(all_hit, "under every variant a bolt cast at a bot 15 m away, the crosshair on his chest, hits him (as under A)")
	var aim_unchanged := aim_ok and MatchSetup.aim_help() == help0
	print("METRIC aim_unchanged_ok %s" % aim_unchanged)
	_expect(aim_unchanged, "the crosshair is the camera's centre under every variant and the aim help untouched (%s)" % MatchSetup.aim_help())


# ---------------------------------------------------------------- menu
func _menu() -> void:
	RingCamera.override = ""
	RingCamera.reload()
	var menu := RingMenu.install(current_scene, null)
	await process_frame
	var k0 := RingCamera.key()
	menu.cycle_camera()
	var k1 := RingCamera.key()
	RingCamera.reload()
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	_expect(k1 != k0 and String(cf.get_value("ring", "camera", "")) == k1 and RingCamera.key() == k1,
			"the Camera row: %s -> %s, written to GameSettings ring.camera and read back" % [k0, k1])
	var row := menu.find_child("Camera", true, false)
	var label := row.find_child("Text", true, false) as Label if row != null else null
	_expect(label != null and RingCamera.label(k1) in label.text and not _show_word(label.text), "the row says it: %s" % (label.text if label else "-"))
	var j0 := RingCamera.jolt_on()
	menu.toggle_jolt()
	RingCamera.reload()
	cf.load(GameSettings.file())
	_expect(j0 == true and RingCamera.jolt_on() == false and cf.get_value("ring", "jolt", true) == false,
			"the Screen jolt row: on by default, off written to GameSettings ring.jolt and read back")
	menu.toggle_jolt()
	RingCamera.set_key(RingCamera.default_key())
	menu.queue_free()
	await process_frame


# ---------------------------------------------------------------- the open world
func _world() -> void:
	RingCamera.override = "high"                 # (even a variant asked for: the open world never reads it)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 200:
		await physics_frame
	var w := current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene != null else null
	_expect(w != null, "the open world and its player")
	if w == null:
		return
	await physics_frame
	var ok := w.ring_moves == null and is_equal_approx(w.cam_distance_now(), 4.1) and is_equal_approx(w.spring_arm.position.x, w.shoulder_offset) \
			and w.camera_tilt.rotation == Vector3.ZERO and w.camera.global_basis.is_equal_approx(w.camera_pivot.global_basis) \
			and is_equal_approx(w.fov, 52.5) and is_equal_approx(w.camera_pivot.position.y, w._eye_y)
	print("METRIC open_world_cam_unchanged_ok %s" % ok)
	_expect(ok, "the open world's camera is today's: arm 4.1 m, centred, level, no ring framing")
	RingCamera.override = ""
