extends "res://tools/ring/air_cast_probe.gd"
## Real-input animation comparison. Reuses the practice fixture and input helpers only.
## No runtime/animation changes. Snapshot final skin-bound bones on skeleton_updated,
## per Godot4.7's after-all-modifiers signal; render frames retain their exact game clock.
## -- out=/private/tmp/fluidity-baseline tag=baseline render=1 view=side
const ELEMENTS := ["earth", "water", "fire", "air"]
const BONES := ["root", "pelvis", "spined", "heada", "r_palm", "l_palm", "r_ankle", "l_ankle", "r_ball", "l_ball"]
var skin_frames: Array = []
var skin_latest := {}
var source_manifest := {}
var npc_latest := {}
var probe_stick: ProbeStick

class ProbeStick extends PlayerControls:
	var stick := Vector2.INF
	func move_vector() -> Vector2:
		return super.move_vector() if stick == Vector2.INF else stick.limit_length(1.0)


func _initialize() -> void:
	opts.out = "/private/tmp/tidebreak-fluidity"
	opts.render = "1"
	super._initialize()
	var manifest_path := "res://artifacts/tidebreak_fluidity/baseline/source_sha256.json"
	if FileAccess.file_exists(manifest_path):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		for path: String in saved.files:
			source_manifest[path] = FileAccess.get_sha256("res://" + path)
	source_manifest["tools/ring/fluidity_probe.gd"] = FileAccess.get_sha256("res://tools/ring/fluidity_probe.gd")
	FileAccess.open(String(opts.out).path_join("source_sha256_at_launch.json"), FileAccess.WRITE).store_string(JSON.stringify(source_manifest, "\t"))
	DisplayServer.window_set_title("Fluidity comparison rendering — saved playback is normal speed")

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
	probe_stick = ProbeStick.new(false)
	p.controls = probe_stick
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
	p.skeleton.skeleton_updated.connect(_skin_updated)
	mode.foe.body.sk.skeleton_updated.connect(_npc_skin_updated)
	if opts.render == "1":
		side = Camera3D.new()
		level.add_child(side)
		side.fov = 55.0
		RenderingServer.frame_post_draw.connect(_save_frame)
	print("FLUIDITY RUNTIME LOADED")
	for element: String in ELEMENTS:
		for kind: String in ["move", "key1", "downward"]:
			var name := element + "_" + kind
			if opts.only != "" and not name in String(opts.only).split(","):
				continue
			await _fluid_case(element, kind)
	for extra: String in ["fire_chain", "earth_cancel", "npc_strafe", "loop_walk_right", "loop_sprint_back_right", "loop_sprint_back_left"]:
		if opts.only == "" or extra in String(opts.only).split(","):
			await _extra_case(extra)
	_finish("")

func _skin_updated() -> void:
	if active == "" or p == null or p.skeleton == null:
		return
	var bones := {}
	var sk := p.skeleton
	for name: String in BONES:
		var i := sk.find_bone(name)
		if i < 0:
			continue
		var g := sk.get_bone_global_pose(i)
		var w := sk.global_transform * g
		var q := sk.get_bone_pose_rotation(i)
		bones[name] = {"world": _vector(w.origin), "body_local": _vector(p.global_transform.affine_inverse() * w.origin),
			"skeleton_local": _vector(g.origin), "rotation": [q.x, q.y, q.z, q.w]}
	var loco: LocoBrain = p.anim.loco
	skin_latest = {"game_t": BendStatus.now() - t0, "engine_frame": Engine.get_process_frames(),
		"body_world": _vector(p.global_position), "body_yaw": p.rotation.y, "body_velocity": _vector(p.velocity),
		"air": rm.airborne(), "ring_state": rm.clip_state(), "cast_phase": c.pose.phase, "cast_clip": String(c.pose.anim_name),
		"cast_weight": c.pose.weight, "blend_cost_usec": c.pose._pose.blend_cost_usec if c.pose._pose != null and "blend_cost_usec" in c.pose._pose else 0, "cast_time": c.pose.clip_time() if c.pose.phase != "" else 0.0,
		"lower": {"state": String(loco.state), "graph_state": loco.graph_state, "input_id": String(loco.input_id),
			"hemi": String(loco.hemi), "phase": loco.phase(), "time_in_state": loco.time_in_state, "slots": p.anim._slots(), "carry": loco.carry_inputs(), "banks": _bank_specs()}, "bones": bones}

func _save_frame() -> void:
	if active == "":
		return
	if not skin_latest.is_empty():
		var row := skin_latest.duplicate(true)
		row["frame"] = render_frame
		row["npc"] = npc_latest.duplicate(true)
		skin_frames.append(row)
	super._save_frame()

func _hold(action: StringName, seconds: float) -> void:
	p.controls.set_held(action, true)
	_event("input_down", {"action": String(action)})
	await _secs(seconds)
	p.controls.set_held(action, false)
	_event("input_up", {"action": String(action)})

func _fluid_case(element: String, kind: String) -> void:
	await _stage(element, 1.5 if kind == "downward" else 9.0)
	_start(element + "_" + kind)
	skin_frames = []
	skin_latest = {}
	if kind == "move":
		aim_enabled = false
		await _hold(&"move_forward", 0.75)
		await _secs(0.65)
		p.controls.set_held(&"sprint", true)
		p.controls.set_held(&"move_left", true)
		await _hold(&"move_back", 0.70)
		p.controls.set_held(&"move_left", false)
		p.controls.set_held(&"move_right", true)
		await _hold(&"move_forward", 0.70)
		p.controls.release_all()
		_event("input_up", {"action": "all"})
		await _secs(0.85)
		_check(p.horizontal_speed() < 0.05, "real run, stop and diagonal reversal return to rest")
	else:
		await _jump()
		await _key(&"weapon_1" if kind == "key1" else &"weapon_2")
		await _tap(&"aim")
		await _secs(2.3)
		var releases := _matching("release")
		_check(releases.size() == 1 and bool(releases[0].air), "one real cast releases airborne")
		_check(not _matching("landing").is_empty(), "real movement lands")
	p.controls.release_all()
	var apex := 0.0
	for row: Dictionary in traces:
		apex = maxf(apex, row.height)
	var record := {"case": active, "element": element, "kind": kind, "apex_m": apex, "floor_y": floor_y,
		"events": events.duplicate(true), "trace": traces.duplicate(true), "projectiles": projectile_trace.duplicate(true),
		"render_frames": render_frame, "render_map": render_map.duplicate(true), "skin_frames": skin_frames.duplicate(true)}
	records.append(record)
	FileAccess.open(String(opts.out).path_join(active + ".json"), FileAccess.WRITE).store_string(JSON.stringify(record, "\t"))
	print("FLUIDITY CASE COMPLETE %s frames=%d skin_frames=%d" % [active, render_frame, skin_frames.size()])
	active = ""

func _npc_skin_updated() -> void:
	if active == "" or mode.foe == null:
		return
	var foe := mode.foe
	var feet := {}
	for name: String in ["r_ball", "l_ball"]:
		var sk := foe.body.sk
		var i := sk.find_bone(name)
		if i >= 0:
			feet[name] = _vector(sk.global_transform * sk.get_bone_global_pose(i).origin)
	npc_latest = {"world": _vector(foe.global_position), "local_velocity": _vector(foe.global_basis.inverse() * foe.velocity),
		"yaw": foe.rotation.y, "clip": foe.body.clip, "animation": String(foe.body.ap.current_animation),
		"position": foe.body.ap.current_animation_position, "rate": foe.body.ap.speed_scale, "feet": feet}

func _extra_case(name: String) -> void:
	await _stage("fire" if name == "fire_chain" else "earth", 7.0)
	probe_stick = ProbeStick.new(false)
	p.controls = probe_stick
	if name.begins_with("loop_"):
		# Initial fixture only: leave deck room for a complete diagonal cycle.
		var at := p.global_transform
		at.origin.z = 4.0 if name.ends_with("left") else -4.0
		at.origin.x = 4.0 if name.contains("back") else -4.0
		RingLevel.place(p, at)
		await _secs(0.3)
	_start(name)
	skin_frames = []
	skin_latest = {}
	npc_latest = {}
	if name.begins_with("loop_"):
		aim_enabled = false
		# Fixed ordinary camera facing +X; analog magnitude exercises slow walking.
		p.yaw = -PI * 0.5
		var axis := Vector2(-1.0 if name.ends_with("left") else 1.0, 1.0 if name.contains("back") else -1.0).normalized()
		var ctrl := probe_stick
		ctrl.stick = axis * (0.30 if name.contains("walk") else 1.0)
		ctrl.set_held(&"sprint", name.contains("sprint"))
		_event("analog_input", {"x": ctrl.stick.x, "y": ctrl.stick.y, "sprint": name.contains("sprint")})
		await _secs(6.0 if name.contains("walk") else 2.0)
		ctrl.stick = Vector2.INF
		ctrl.release_all()
		await _secs(0.35)
		_check(opts.render != "1" or skin_frames.size() > 90, "directional movement has continuous final-skin samples")
	elif name == "fire_chain":
		await _key(&"weapon_1")
		for i in 3:
			var count := _matching("release").size()
			await _tap(&"aim")
			await _until(func() -> bool: return _matching("release").size() > count, 1.0)
			await _secs(0.04)
		await _secs(1.0)
		_check(_matching("release").size() == 3, "three real Fire casts chain without duplicate release")
	elif name == "earth_cancel":
		await _key(&"weapon_1")
		await _hold(&"aim", 0.30)
		await _hold(&"move_back", 0.55)
		await _secs(0.9)
		_check(_matching("release").is_empty() and not _matching("broken").is_empty(), "long early release cancels charge into real movement")
	else:
		mode.practice_ctl.set_way("walk")
		mode.foe.face_lock = p.global_position
		_event("npc_order", {"order": "practice_walk_with_combat_face_lock"})
		await _secs(2.0)
		# Fixture-only: stop the practice Walk order from replacing this normal go() order.
		mode.practice_ctl.dummy = "probe_order"
		var away := (mode.foe.global_position - p.global_position).normalized()
		away.y = 0.0
		mode.foe.go(mode.foe.global_position + away * 3.0, NpcFighter.RUN_SPEED * 0.75, 0.4, true)
		_event("npc_order", {"order": "normal_go_backward_with_combat_face_lock"})
		await _secs(1.1)
		mode.practice_ctl.set_way("stand")
		mode.foe.face_lock = Vector3.INF
	p.controls.release_all()
	var record := {"case": active, "element": p.arena_element, "kind": name, "floor_y": floor_y,
		"events": events.duplicate(true), "trace": traces.duplicate(true), "projectiles": projectile_trace.duplicate(true),
		"render_frames": render_frame, "render_map": render_map.duplicate(true), "skin_frames": skin_frames.duplicate(true)}
	records.append(record)
	FileAccess.open(String(opts.out).path_join(active + ".json"), FileAccess.WRITE).store_string(JSON.stringify(record, "\t"))
	print("FLUIDITY CASE COMPLETE %s frames=%d skin_frames=%d" % [active, render_frame, skin_frames.size()])
	active = ""

func _bank_specs() -> Dictionary:
	var out := {}
	var ci := p.anim.loco.carry_inputs()
	for id: String in ci.input_w:
		var rec := p.anim.index.lower_record(StringName(id))
		if rec.has("hemis"):
			out[id] = {}
			for h: String in rec.hemis:
				var hr: Dictionary = rec.hemis[h]
				out[id][h] = {"clips": hr.clips, "lengths": hr.lengths, "loop": hr.loop}
	return out

func _finish(error: String) -> void:
	if error == "":
		var expected := 18 if opts.only == "" else String(opts.only).split(",").size()
		_check(records.size() == expected, "all requested fluidity cases completed")
	super._finish(error)
