extends SceneTree
## Real-practice jump/cast timing. Initial per-case placement only; no fake air,
## held bodies, altered gravity, charge overrides, injected damage or outcomes.
## Headless: GODOT_TIMEOUT=300 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path .
##   -s tools/ring/air_cast_probe.gd -- out=/private/tmp/air-cast-before tag=before
## Render: omit --headless, add --resolution 1280x720 and render=1 view=side|player.
## Optional only=ground_spike,air_spike,air_spike_drift,ground_projectile,air_projectile,
## hammer_full,hammer_hop,hammer_drift,wall,patch.
## Rendered JPEGs are continuous60fps per case; physics/events retain120Hz timing.

const OWN_CFG := "user://air_cast_probe.cfg"
const CASES := ["ground_spike", "air_spike", "air_spike_drift", "ground_projectile", "air_projectile", "hammer_full", "hammer_hop", "hammer_drift", "wall", "patch"]
var opts := {"out": "/private/tmp/air-cast-probe", "tag": "probe", "render": "0", "view": "side", "only": ""}
var level: RingLevel
var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMoves
var side: Camera3D
var active := ""
var records: Array = []
var events: Array = []
var traces: Array = []
var checks: Array = []
var t0 := 0.0
var floor_y := 0.0
var was_air := false
var last_state := -1
var aim_enabled := true
var jump_on_release := false
var render_frame := 0
var render_map: Array = []
var source_hashes := {}
var jump_next_tick := false
var projectile_trace: Array = []
var seen_throws := {}


func _initialize() -> void:
	for path: String in ["data/sway/moves.json", "scripts/sway/sway_caster.gd", "scripts/sway/form_effects.gd", "scripts/sway/gust_lift.gd", "data/ring/movement.json", "tools/ring/air_cast_probe.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://" + path)
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0)
		if opts.has(key):
			opts[key] = arg.substr(key.length() + 1)
	DirAccess.make_dir_recursive_absolute(opts.out)
	FileAccess.open(String(opts.out).path_join(".gdignore"), FileAccess.WRITE)
	seed(1750)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = "strong"
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.difficulty = "normal"
	MatchSetup.light = "noon"
	MatchSetup.speed = 1.0
	MatchSetup.fresh = false
	MatchSetup.my_pct = -1.0
	MatchSetup.foe_pct = -1.0
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_title("Air-cast timing probe — normal gameplay speed")
	create_timer(240.0, true, false, true).timeout.connect(func() -> void: _finish("watchdog"))
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(condition: Callable, seconds: float) -> bool:
	for i in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _run() -> void:
	for i in 1800:
		await process_frame
		mode = RingMode.find(self)
		if mode != null and mode.foe != null and mode.phase == "FIGHT" and not current_scene.get_meta("loading_hold", false):
			break
	if mode == null or mode.foe == null:
		_finish("no ring")
		return
	level = current_scene as RingLevel
	p = mode.player
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	c = SwayCaster.of(p)
	rm = RingMoves.of(p)
	c.lock_started.connect(func(m: String, _target: Node3D) -> void: _event("lock", {"move": m, "mode": c.mode_of(m), "lock_s": c.lock_s}))
	c.locked.connect(func(m: String, _target: Node3D) -> void: _event("full", {"move": m, "mode": c.mode_of(m)}))
	c.cast_released.connect(_released)
	c.lock_broken.connect(func(m: String, _target: Node3D, why: String) -> void: _event("broken", {"move": m, "why": why}))
	c.pose.struck.connect(func(m: String) -> void: _event("pose_strike", {"move": m}))
	mode.rules.launched.connect(func(who: Node3D, velocity: Vector3, stun: float, by: Node, move: String) -> void:
		_event("contact", {"who": "player" if who == p else "target", "by_player": by == p, "move": move, "speed": velocity.length(), "stun": stun}))
	physics_frame.connect(_observe)
	if opts.render == "1":
		side = Camera3D.new()
		level.add_child(side)
		side.fov = 55.0
		RenderingServer.frame_post_draw.connect(_save_frame)
	for name: String in CASES:
		if opts.only != "" and not name in String(opts.only).split(","):
			continue
		await _case(name)
	_finish("")


func _event(kind: String, detail: Dictionary = {}) -> void:
	if active == "":
		return
	var row := {"kind": kind, "t": BendStatus.now() - t0, "physics_frame": Engine.get_physics_frames(),
		"air": rm.airborne(), "height": p.global_position.y - floor_y, "vertical_speed": p.velocity.y,
		"horizontal_speed": p.horizontal_speed(), "fill": c.fill, "state": c.state}
	row.merge(detail)
	events.append(row)
	print("AIR_PROBE_EVENT %s %s" % [active, JSON.stringify(row)])


func _released(move: String, variation: String) -> void:
	_event("release", {"move": move, "mode": variation, "strike_wait_s": c.strike_wait(move)})
	if jump_on_release:
		jump_on_release = false
		jump_next_tick = true


func _observe() -> void:
	if not is_instance_valid(p) or not is_instance_valid(mode.foe):
		return
	if jump_next_tick:
		jump_next_tick = false
		p.controls.set_held(&"jump", true)
		_event("jump_input")
	if aim_enabled:
		var to := mode.foe.global_position + Vector3.UP * 1.1 - p.camera.global_position
		p.yaw = atan2(-to.x, -to.z)
		p.pitch = atan2(to.y, maxf(Vector2(to.x, to.z).length(), 0.1))
	if active == "":
		return
	var air := rm.airborne()
	if air != was_air:
		_event("takeoff" if air else "landing")
		was_air = air
	if c.state != last_state:
		_event("state", {"state_from": last_state})
		last_state = c.state
	traces.append({"t": BendStatus.now() - t0, "air": air, "height": p.global_position.y - floor_y,
		"vy": p.velocity.y, "fill": c.fill, "state": c.state, "mode": c.mode_of(c.move) if c.move != "" else "",
		"lock_s": c.lock_s, "horizontal_speed": p.horizontal_speed(), "time_scale": Engine.time_scale, "physics_frame": Engine.get_physics_frames()})
	_observe_projectiles()


func _vector(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _observe_projectiles() -> void:
	for node in get_nodes_in_group(FormEffects.Throw.GROUP):
		var th := node as FormEffects.Throw
		if th.caster == null or not th.caster.valid() or th.caster.body != p or not is_instance_valid(th.stone) or not is_instance_valid(th.lift):
			continue
		var id := th.get_instance_id()
		if not seen_throws.has(id):
			seen_throws[id] = true
			_event("stone_created", {"id": id, "follow": th.follow, "stone": _vector(th.stone.global_position)})
			th.thrown.connect(func(stone: FormStone, toward: Vector3) -> void:
				_event("stone_thrown", {"id": id, "stone": _vector(stone.global_position), "target": _vector(toward)}))
			th.lift.struck.connect(func(who: Node, damage: float) -> void:
				_event("stone_hit", {"id": id, "target": String(who.name) if is_instance_valid(who) else "freed", "damage": damage}))
			th.lift.landed.connect(func(at: Vector3) -> void:
				_event("stone_landed", {"id": id, "at": _vector(at), "height_over_deck": at.y - floor_y}))
		projectile_trace.append({"t": BendStatus.now() - t0, "id": id, "waiting": th.waiting, "thrown": th.is_thrown,
			"follow": th.follow, "phase": th.lift.phase, "stone": _vector(th.stone.global_position),
			"player": _vector(p.global_position), "target": _vector(mode.foe.global_position), "velocity": _vector(th.lift.velocity)})


func _key(action: StringName) -> void:
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)
	await _ticks(2)


func _tap(action: StringName, duration := 0.08) -> void:
	p.controls.set_held(action, true)
	_event("input_down", {"action": String(action)})
	await _secs(duration)
	p.controls.set_held(action, false)
	_event("input_up", {"action": String(action)})


func _jump() -> void:
	p.controls.set_held(&"jump", true)
	_event("jump_input")
	await _ticks(3)
	p.controls.set_held(&"jump", false)
	await _until(func() -> bool: return rm.airborne(), 0.3)


func _stage(element: String, distance: float) -> void:
	active = ""
	jump_on_release = false
	jump_next_tick = false
	p.controls.release_all()
	MatchSetup.element = element
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.foes = ["fire"]
	mode.restart()
	await _until(func() -> bool: return mode.phase == "FIGHT" and p.arena_element == element, 10.0)
	var toward_center := mode.ring.center() - mode.foe.global_position
	toward_center.y = 0.0
	toward_center = toward_center.normalized()
	var position := mode.foe.global_position + toward_center * distance
	position.y = mode.ring.deck_y()
	RingLevel.place(p, Transform3D(Basis.looking_at(-toward_center, Vector3.UP), position))
	aim_enabled = true
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
	await _secs(0.5)
	floor_y = p.global_position.y
	if side != null:
		var middle := (p.global_position + mode.foe.global_position) * 0.5 + Vector3.UP * 1.1
		var right := toward_center.cross(Vector3.UP)
		side.look_at_from_position(middle + right * 8.0 + Vector3.UP * 2.2 + toward_center * 1.0, middle)
		if opts.view == "side":
			side.make_current()
		else:
			p.camera.make_current()


func _start(name: String) -> void:
	active = name
	events = []
	traces = []
	projectile_trace = []
	seen_throws = {}
	t0 = BendStatus.now()
	was_air = rm.airborne()
	last_state = c.state
	render_frame = 0
	render_map = []
	if opts.render == "1":
		DirAccess.make_dir_recursive_absolute(String(opts.out).path_join(name))
	_event("start")


func _check(ok: bool, label: String) -> void:
	checks.append({"case": active, "ok": ok, "label": label})
	print("AIR_PROBE %s %s %s" % ["PASS" if ok else "FAIL", active, label])


func _matching(kind: String, variation := "") -> Array:
	return events.filter(func(row: Dictionary) -> bool:
		return row.kind == kind and (variation == "" or String(row.get("mode", "")) == variation))


func _case(name: String) -> void:
	var spike := name.contains("spike")
	var hammer := name.begins_with("hammer")
	var drifting := name.ends_with("drift")
	await _stage("fire" if name.ends_with("projectile") else "earth", (4.5 if drifting else 1.5) if hammer else 9.0)
	_start(name)
	if drifting:
		p.controls.set_held(&"move_forward", true)
		_event("input_down", {"action": "move_forward"})
		await _secs(0.15)
	if name in ["ground_projectile", "air_projectile"] or spike:
		await _key(&"weapon_1")
		if name.begins_with("ground"):
			p.controls.set_held(&"aim", true)
			_event("input_down", {"action": "aim"})
			if name == "ground_spike":
				await _until(func() -> bool: return FormEffects.raised_of(p) != null, 2.0)
			else:
				await _secs(0.15)
			await _jump()
			await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
			p.controls.set_held(&"aim", false)
			_event("input_up", {"action": "aim"})
		else:
			await _jump()
			await _tap(&"aim")
	elif hammer:
		if name == "hammer_hop":
			# A real jab release triggers Full's short-hop window.
			aim_enabled = false
			p.yaw += PI
			p.pitch = 0.0
			await _secs(0.15)
			jump_on_release = true
			await _tap(&"fire")
			await _until(func() -> bool: return rm.airborne(), 2.0)
			p.controls.set_held(&"jump", false)
			aim_enabled = true
		else:
			await _jump()
		await _key(&"weapon_2")
		await _tap(&"aim")
	elif name == "wall":
		await _key(&"weapon_4")
		await _tap(&"aim")
		await _jump()
		var fill0 := c.fill
		await _secs(0.25)
		_check(absf(c.fill - fill0) < 0.035, "ground-dependent wall fill stays paused while airborne")
	elif name == "patch":
		# Earn a fresh damage pool from the practice dummy's normal throw.
		mode.practice_ctl.set_way("throw")
		var hurt := await _until(func() -> bool: return mode.rules.fresh_pct(p) > 0.0, 8.0)
		mode.practice_ctl.set_way("stand")
		_check(hurt, "practice dummy naturally creates an eligible Patch damage pool")
		await _until(func() -> bool: return p.is_on_floor() and not rm.airborne() and c.hitstun_left() <= 0.0, 3.0)
		await _key(&"weapon_5")
		await _jump()
		await _tap(&"aim")
		await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
		_check(_matching("release").is_empty(), "Patch never releases while airborne")
		await _tap(&"aim")
	if drifting:
		await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 2.0)
		p.controls.set_held(&"move_forward", false)
		_event("input_up", {"action": "move_forward"})
	await _secs(2.8)
	p.controls.release_all()
	var releases := _matching("release", "slam" if hammer else "")
	var landings := _matching("landing")
	if name in ["ground_projectile", "air_projectile"] or spike or hammer:
		_check(releases.size() == 1 and bool(releases[0].air), "exactly one intended cast releases before landing")
		_check(not landings.is_empty(), "real movement returns the player to the floor")
		if name == "hammer_full":
			var contacts := _matching("contact").filter(func(row: Dictionary) -> bool: return row.get("move", "") == "earth_shove/slam" and row.get("by_player", false))
			_check(contacts.size() == 1, "Hammer makes one real contact against the practice target")
		if spike:
			var thrown := _matching("stone_thrown")
			_check(thrown.size() == 1, "one actual Spike projectile leaves its held state")
			_check(thrown.size() == 1 and bool(thrown[0].air), "actual Spike projectile launches while the player is airborne")
			if thrown.size() == 1:
				var height_from_feet := float(thrown[0].stone[1]) - floor_y - float(thrown[0].height)
				_check(height_from_feet > 0.8, "Spike launches above airborne feet (%.3fm)" % height_from_feet)
			_check(not _matching("stone_hit").is_empty(), "Spike actually reaches and strikes the practice target")
		if drifting:
			var moving_locks := traces.filter(func(row: Dictionary) -> bool:
				return row.air and row.state == SwayCaster.State.LOCKING and row.horizontal_speed > 1.0)
			_check(moving_locks.size() >= 12, "charge is exercised during sustained real horizontal drift")
	elif name == "wall":
		_check(releases.size() == 1 and not bool(releases[0].air), "queued wall releases once after landing")
	elif name == "patch":
		_check(releases.size() == 1 and not bool(releases[0].air), "fresh grounded Patch input releases once after landing")
	var apex := 0.0
	for row: Dictionary in traces:
		apex = maxf(apex, row.height)
	if name == "hammer_hop":
		_check(apex > 0.65 and apex < 0.95, "prior real cast gives the ordinary 0.8m short hop")
	var record := {"case": name, "element": p.arena_element, "apex_m": apex, "events": events.duplicate(true), "trace": traces.duplicate(true), "projectiles": projectile_trace.duplicate(true), "render_frames": render_frame, "render_map": render_map.duplicate(true)}
	records.append(record)
	FileAccess.open(String(opts.out).path_join(name + ".json"), FileAccess.WRITE).store_string(JSON.stringify(record, "\t"))
	active = ""


func _save_frame() -> void:
	if active == "":
		return
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_jpg(String(opts.out).path_join(active).path_join("f%05d.jpg" % render_frame), 0.94)
	render_map.append({"frame": render_frame, "game_t": BendStatus.now() - t0, "engine_frame": Engine.get_process_frames(), "time_scale": Engine.time_scale})
	render_frame += 1


func _finish(error: String) -> void:
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row.ok)
	var report := {"tag": opts.tag, "engine": Engine.get_version_info(), "physics_hz": Engine.physics_ticks_per_second,
		"error": error, "checks": checks, "failures": failures.size(), "cases": records,
		"source_sha256_at_launch": source_hashes}
	FileAccess.open(String(opts.out).path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("AIR CAST PROBE %s (%d checks, %d failures)" % ["PASSED" if failures.is_empty() and error == "" else "FAILED", checks.size(), failures.size()])
	quit(0 if failures.is_empty() and error == "" else 1)
