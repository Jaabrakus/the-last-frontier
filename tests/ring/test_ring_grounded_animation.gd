extends SceneTree
## Grounded presentation on real ring bodies: opponent-relative steps, plant-phase
## continuity, and player step sounds separated from knock carry/body-state movement.
## Does not change movement tuning, animation assets, or combat timing.
## Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_grounded_animation.gd

const Rig := preload("res://tests/ring/r3_move_rig.gd")
const OWN_CFG := "user://ring_grounded_animation_test.cfg"
var checks := 0
var fails: Array[String] = []
var rig: Rig
var bot: NpcFighter

class StepRecorder extends Footsteps:
	var heard := 0
	func _step(_gait_name: String) -> void:
		heard += 1
	func _play(_id: String, _pos: Vector3, _gain_db := 0.0, _follow := false) -> void:
		pass
	func _land(_fall: float) -> void:
		pass


func _initialize() -> void:
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	create_timer(120.0, true, false, true).timeout.connect(func() -> void: quit(2))
	_run.call_deferred()


func _expect(ok: bool, label: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		fails.append(label)


func _run() -> void:
	rig = Rig.new(self)
	_expect(await rig.setup("water"), "real ring player on the test deck")
	if rig.p == null:
		_end()
		return
	bot = await rig.bot("fire", rig.at(18.0, 0.0))
	_expect(bot != null and bot.body != null, "real unarmed element opponent with RingMoves")
	if bot == null or bot.body == null:
		_end()
		return
	await rig.secs(0.4)
	bot.set_physics_process(false)
	bot.body.set_process(false)
	bot.action = "idle"
	bot.face_lock = bot.global_position + Vector3.FORWARD * 10.0
	bot.rotation.y = 0.0
	bot.ring_moves.mode = ""
	var kn := BendKnock.peek(bot)
	if kn != null:
		kn.reset()
	_directions()
	_phases()
	_footsteps()
	_end()


func _directions() -> void:
	for spec: Array in [[Vector3.RIGHT, "run_rt"], [Vector3.LEFT, "run_lt"],
			[Vector3.BACK, "run_bw"], [Vector3.FORWARD, "run"]]:
		bot.velocity = spec[0] * 3.75
		var before := bot.global_transform
		var velocity := bot.velocity
		bot._pose()
		_expect(bot.body.clip == spec[1], "opponent facing forward steps %s at 3.75 m/s (got %s)" % [spec[1], bot.body.clip])
		_expect(bot.global_transform == before and bot.velocity == velocity, "presentation leaves physical pose/velocity unchanged")
	# The side stride uses its measured pace, not the forward loop's generic divisor.
	bot.velocity = Vector3.RIGHT * 3.75
	bot._pose()
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AnimGraphData.METRICS_PATH))
	var speed := float(metrics.clips["actor_b-p-run-fw-rt"].travel.speed)
	_expect(absf(bot.body.ap.speed_scale * speed - 3.75) < 0.02, "sideways footwork pace matches actual travel")
	# Small noise either side of a diagonal must not repeatedly restart the loop.
	bot.velocity = Vector3(3.0, 0.0, -2.9).normalized() * 3.75
	bot._pose()
	var key := bot.body.clip
	for i in 8:
		bot.velocity = Vector3(3.0, 0.0, -2.9 - 0.2 * float(i % 2)).normalized() * 3.75
		bot._pose()
		_expect(bot.body.clip == key, "diagonal jitter keeps directional loop (%d)" % i)
	# Existing full-body cast ownership must still win over grounded movement.
	bot.action = "cast"
	bot.velocity = Vector3.LEFT * 5.0
	bot._pose()
	_expect(bot.body.clip == key, "casting owns the pose while moving")
	bot.action = "idle"
	var rm := bot.ring_moves
	bot.ring_moves = null
	bot.velocity = Vector3.RIGHT * 3.75
	bot._pose()
	_expect(bot.body.clip == "run", "non-ring NPC selection retains existing forward-run behavior")
	bot.ring_moves = rm


func _phases() -> void:
	var body := bot.body
	body.play("run", 0.0)
	body.ap.seek(body.clip_length("run") * 0.909091, true)
	body.play("run_bw", 0.25)
	_expect(body.clip == "run_bw", "backward loop is available on the real AnimationPlayer")
	if body.clip != "run_bw":
		return
	var phase := body.ap.current_animation_position / body.ap.current_animation_length
	_expect(absf(phase - 0.386364) < 0.005, "forward left-foot plant remains left-foot plant after backward switch")
	body.play("sprint", 0.25)
	phase = body.ap.current_animation_position / body.ap.current_animation_length
	_expect(minf(absf(phase - 0.45), absf(phase - 0.9125)) < 0.005, "one-stride to two-stride loop preserves the planted foot")
	var at := body.ap.current_animation_position
	body.play("sprint", 0.25, 1.1)
	_expect(is_equal_approx(body.ap.current_animation_position, at), "same loop rate update does not restart its phase")


func _footsteps() -> void:
	var p := rig.p
	p.set_physics_process(false)
	var original := p.get_node_or_null("Footsteps")
	if original != null:
		original.set_physics_process(false)
	var recorder := StepRecorder.new()
	recorder.player = p
	p.add_child(recorder)
	recorder.set_physics_process(false)
	_expect(p.is_on_floor(), "footstep fixture is grounded")
	var kn := BendKnock.of(p)
	var rm := p.ring_moves
	rm.mode = ""
	kn.applied = Vector3.RIGHT * 5.0
	p.velocity = kn.applied
	recorder._physics_process(0.5)
	_expect(recorder.heard == 0, "grounded knock carry alone produces no walking/running footstep")
	recorder.heard = 0
	kn.applied = Vector3.ZERO
	p.velocity = Vector3.FORWARD * 5.0
	recorder._physics_process(0.5)
	_expect(recorder.heard == 1, "ordinary grounded locomotion still produces a footstep")
	rm.mode = "roll"
	recorder._physics_process(0.5)
	_expect(recorder.heard == 1, "roll body-state movement does not produce running footsteps")
	rm.mode = ""
	kn.applied = Vector3.RIGHT * 5.0
	p.velocity = kn.applied + Vector3.FORWARD * 2.0
	recorder._moving = true
	recorder._acc = 0.0
	recorder._physics_process(0.2)
	_expect(is_equal_approx(recorder._acc, 0.4), "mixed own motion + knock accumulates only own travel distance")
	p.ring_moves = null
	p.velocity = Vector3.RIGHT * 5.0
	recorder.heard = 0
	recorder._physics_process(0.5)
	_expect(recorder.heard == 1, "world footstep behavior remains unchanged")
	p.ring_moves = rm
	kn.reset()
	recorder.queue_free()


func _end() -> void:
	RingMoves.geo_override = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	print("RING GROUNDED ANIMATION %s (%d/%d checks)" % ["PASSED" if fails.is_empty() else "FAILED", checks - fails.size(), checks])
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
		await process_frame
	quit(0 if fails.is_empty() else 1)
