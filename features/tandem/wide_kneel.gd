extends Node
## Solo wide upright kneel: Ctrl+N enter, K dip/rise, B pelvic tilt, movement exit.
## A woman's pose, as the tandem feature's leads are (FrontierTandem.is_woman; user 2026-09-29): she kneels over a
## partner in the Reverse Plank (reverse_plank.gd take_partner / invite_partner).
const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")
signal settled(kind: String)
@export var stamina_max := 100.0
@export var flinch_cost := 5.0
@export var idle_regain := 3.0
@export var recovery_delay := 0.75
var stamina := 100.0
var _rest := 0.0
var _reaction := ""
var _playing := StringName()
var _generation := 0
## The Reverse Plank she kneels over (null alone): its man's flinch gauge scales her flinches (reverse_plank.gd).
var base: Node
var player: FrontierPlayer
var active := false
var ap: AnimationPlayer
var saved: Dictionary = {}
var paused: Array = []
func _ready() -> void:
	name = "WideKneel"
	if "--wide-kneel-preview" in OS.get_cmdline_user_args(): call_deferred("preview")
func _input(e: InputEvent) -> void:
	if not player.is_local or not e is InputEventKey or not e.pressed or e.echo: return
	if active:
		match e.physical_keycode:
			KEY_K: react("bounce", _gauge())
			KEY_B: react("wave", _gauge())
			KEY_N, KEY_BACKSPACE, KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE: stop()
	elif e.physical_keycode == KEY_N and e.ctrl_pressed and not e.shift_pressed:
		start()
	else: return
	get_viewport().set_input_as_handled()
func start() -> bool:
	var tandem := player.get_node_or_null("TandemPoses")
	if active or tandem == null or not tandem.is_woman(player) or not tandem._available(player): return false
	ap = player.begin_kneel(self, player.global_position - player.global_basis.z)
	if ap == null: return false
	saved = {"active": player.anim.active, "camera_y": player.camera_pivot.position.y, "health": player.health}
	player.anim.active = false
	for n: Node in [player.building, player.interactor, player.torch, player.gather, player.equip_wheel, player.get_node_or_null("Weapons")]:
		if n:
			paused.append([n, n.process_mode])
			n.process_mode = Node.PROCESS_MODE_DISABLED
	if not ap.has_animation_library(&"wide_kneel"):
		var lib := AnimationLibrary.new()
		for kind in ["idle", "bounce", "wave"]:
			lib.add_animation(kind, CLIPS.retarget(load("res://features/tandem/wide_kneel_" + kind + ".tres"), ap, player.skeleton))
		ap.add_animation_library(&"wide_kneel", lib)
	active = true
	ap.animation_finished.connect(_finished)
	ap.play("wide_kneel/idle", 0.25)
	player.camera_pivot.position.y = 0.65
	return true
## Her flinch, as full as `gauge` (the tandem flinch gauge: TandemClips variants); none when she is spent.
func react(kind: String, gauge := 1.0) -> bool:
	if not active or kind not in ["bounce", "wave"] or stamina < flinch_cost: return false
	_generation += 1
	_reaction = kind
	stamina -= flinch_cost
	_rest = recovery_delay
	_playing = CLIPS.variant(ap, &"wide_kneel", kind, gauge)
	ap.play(_playing, 0.08)
	ap.seek(0.0, true)
	# her breasts jolt with it, as full as the flinch (FrontierTandem.jiggle)
	var tandem := player.get_node_or_null("TandemPoses")
	if tandem != null: tandem.jiggle(player, gauge)
	return true
func _gauge() -> float:
	return base.flinch_gauge() if is_instance_valid(base) else 1.0
func _finished(clip: StringName) -> void:
	if not active or _reaction.is_empty() or clip != _playing: return
	var kind := _reaction
	var generation := _generation
	_reaction = ""
	ap.play("wide_kneel/idle", 0.10)
	# Notify after the return-to-idle blend has settled, not when the reaction begins.
	await get_tree().create_timer(0.10).timeout
	if active and generation == _generation: settled.emit(kind)
func _process(delta: float) -> void:
	_rest = maxf(0.0, _rest - delta)
	if _rest <= 0.0 and _reaction.is_empty(): stamina = minf(stamina_max, stamina + idle_regain * delta)
	if active and (player.is_dead or player.health < saved.health or player.kneeling != self): stop()
	# (a look changed to a man's mid-pose stands her up, as a tandem lead)
	elif active and not player.get_node("TandemPoses").is_woman(player): stop()
func stop() -> void:
	if not active: return
	active = false
	_generation += 1
	_reaction = ""
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
		push_error("WIDE_KNEEL preview entry blocked")
		return
	player.camera_distance = 2.5
	player.yaw = player.rotation.y + PI + 0.45
	player.pitch = -0.12
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/frontier-wide-kneel.png")
	print("WIDE_KNEEL_READY Ctrl+N pose; K bounce; B wave; Backspace exit")
