extends Node
## Solo puppy hold derived from crawl. Ctrl+P enter; K forward flinch; movement or Backspace exit.
const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")
var player: FrontierPlayer
var motion: SkeletonModifier3D
var active := false
var ap: AnimationPlayer
var saved: Dictionary = {}
var paused: Array = []
func _ready() -> void:
	name = "PuppyPose"
	if "--puppy-preview" in OS.get_cmdline_user_args(): call_deferred("preview")
func _input(e: InputEvent) -> void:
	if not player.is_local or not e is InputEventKey or not e.pressed or e.echo: return
	if active:
		var pair := player.get_node_or_null("PuppyTandem")
		if e.physical_keycode == KEY_I and pair != null: pair.invite_partner()
		elif e.physical_keycode == KEY_K:
			if pair != null and pair.joined: pair.react()
			else: flinch()
		elif e.physical_keycode == KEY_C:
			var tp: Node = player.get_node_or_null("TandemPoses")
			if tp != null: tp.cinematic = not tp.cinematic
		elif e.physical_keycode in [KEY_O, KEY_U]:
			var kind := "wave" if e.physical_keycode == KEY_O else "sway"
			if pair != null and pair.joined:
				pair.play_motion(kind, "puppy" if e.ctrl_pressed else ("upright" if e.shift_pressed else "both"))
			else: play_motion(kind)
		elif e.physical_keycode in [KEY_P, KEY_N, KEY_BACKSPACE, KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]: stop()
		else: return
	elif e.physical_keycode == KEY_P and e.ctrl_pressed: start()
	else: return
	get_viewport().set_input_as_handled()
func start() -> bool:
	var tandem := player.get_node_or_null("TandemPoses")
	if active or tandem == null or not tandem._available(player): return false
	ap = player.begin_kneel(self, player.global_position - player.global_basis.z)
	if ap == null: return false
	saved = {"active": player.anim.active, "camera_y": player.camera_pivot.position.y, "health": player.health}
	player.anim.active = false
	for n: Node in [player.building, player.interactor, player.torch, player.gather, player.equip_wheel, player.get_node_or_null("Weapons")]:
		if n:
			paused.append([n, n.process_mode])
			n.process_mode = Node.PROCESS_MODE_DISABLED
	if not ap.has_animation_library(&"puppy"):
		var lib := AnimationLibrary.new()
		lib.add_animation("idle", CLIPS.retarget(load("res://features/tandem/puppy_idle.tres"), ap, player.skeleton))
		lib.add_animation("flinch", CLIPS.retarget(load("res://features/tandem/puppy_flinch.tres"), ap, player.skeleton))
		ap.add_animation_library(&"puppy", lib)
	motion = load("res://features/tandem/yoga_motion.gd").new()
	motion.name = "PuppyMotion"
	motion.puppy_pose = true
	tandem._put_before_body(player.skeleton, motion)
	active = true
	ap.animation_finished.connect(_finished)
	ap.play("puppy/idle", 0.3)
	player.camera_pivot.position.y = 0.35
	return true
func play_motion(kind: String, start_ms: int = -1) -> void:
	if active and is_instance_valid(motion):
		ap.play("puppy/idle", 0.08)
		motion.play_motion(kind, start_ms)
func flinch() -> void:
	if not active: return
	motion.cancel()
	ap.play("puppy/flinch", 0.04)
	ap.seek(0.0, true)
func _finished(clip: StringName) -> void:
	if active and clip == &"puppy/flinch": ap.play("puppy/idle", 0.08)
func _process(_delta: float) -> void:
	if active and (player.is_dead or player.health < saved.health or player.kneeling != self): stop()
func stop() -> void:
	if not active: return
	active = false
	if is_instance_valid(motion):
		motion.active = false
		motion.queue_free()
	motion = null
	var pair := player.get_node_or_null("PuppyTandem")
	if pair != null: pair.stop_pair()
	if ap.animation_finished.is_connected(_finished): ap.animation_finished.disconnect(_finished)
	ap.stop()
	for item in paused:
		if is_instance_valid(item[0]): item[0].process_mode = item[1]
	paused.clear()
	player.anim.active = saved.active
	player.camera_pivot.position.y = saved.camera_y
	if player.kneeling == self: player.end_kneel()
	saved.clear()
func _exit_tree() -> void:
	if is_instance_valid(player): stop()
func preview() -> void:
	for attempt in 120:
		await get_tree().create_timer(0.25).timeout
		if start(): break
	if not active:
		push_error("PUPPY preview entry blocked")
		return
	player.camera_distance = 2.6
	player.yaw = player.rotation.y + PI * 0.5
	player.pitch = -0.15
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/frontier-puppy.png")
	print("PUPPY_READY Ctrl+P enter; K forward flinch; Backspace/movement exit")
