extends Node
## Supine hip-support hold: Ctrl+Shift+N enter, K recoil / partner flinch, movement exit.
## Yoga together (scripts/companion/tandem_link.gd; user 2026-09-29: "new poses and tandem poses to add to yoga"): the
## wife's stand-in, or the player, kneels over this hold in the Wide Kneel (take_partner; invite_partner makes a generic
## companion instead). companion / joined / mode read like FrontierTandem's for FrontierPlayer._skirt_tuck: the man in
## the plank under her is the pair's partner, his breeches down at the knees while she kneels over him.
## Who (user 2026-09-29: "reverse plank is the only postion where both sexes can use but only women can enter as a
## partner"): anyone lies in the plank, solo or under a partner; the one who kneels over it is a woman (take_partner
## turns a man away; wide_kneel.gd will not start for one).
const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")
const TANDEM = preload("res://features/tandem/frontier_tandem.gd")
var player: FrontierPlayer
var active := false
var ap: AnimationPlayer
var saved: Dictionary = {}
var paused: Array = []
## Grounded knees flank the lower player's thighs. Local to the character rig.
@export var partner_offset := Vector3(0, 0, -0.02)
@export var partner_reversed := false
var _rotation_applied := false
var partner: FrontierPlayer
var partner_pose: Node
var inviting := false
## The partner was made here (invite_partner) and goes with the pair; a borrowed one (take_partner) only stands up.
var _owned := true
## While a partner kneels over the hold: joined, mode "wide", companion this player (see the top).
var joined := false
var mode := ""
var companion: FrontierPlayer
var _partner_health := 0.0
signal stamina_reacted
@export var stamina_max := 100.0
@export var reaction_cost := 10.0
@export var idle_regain := 3.0
@export var recovery_delay := 0.75
var stamina := 100.0
var _rest := 0.0
func _ready() -> void:
	name = "ReversePlank"
	if "--reverse-wide-reversed-preview" in OS.get_cmdline_user_args(): partner_reversed = true
	if "--reverse-plank-preview" in OS.get_cmdline_user_args() or "--reverse-wide-preview" in OS.get_cmdline_user_args() or "--reverse-wide-reversed-preview" in OS.get_cmdline_user_args(): call_deferred("preview")
func _input(e: InputEvent) -> void:
	if not player.is_local or not e is InputEventKey or not e.pressed or e.echo: return
	if active:
		match e.physical_keycode:
			KEY_K:
				if is_instance_valid(partner_pose): partner_pose.react("bounce", flinch_gauge())
				else: react("dip")
			KEY_B:
				if is_instance_valid(partner_pose): partner_pose.react("wave", flinch_gauge())
			KEY_R: set_partner_reversed(not partner_reversed)
			KEY_I: invite_partner()
			KEY_N, KEY_BACKSPACE, KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE: stop()
	elif e.physical_keycode == KEY_N and e.ctrl_pressed and e.shift_pressed:
		start()
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
	if not ap.has_animation_library(&"reverse_plank"):
		var lib := AnimationLibrary.new()
		lib.add_animation("recoil", CLIPS.retarget(load("res://features/tandem/hip_support_recoil.tres"), ap, player.skeleton))
		lib.add_animation("support", CLIPS.retarget(load("res://features/tandem/hip_support_idle.tres"), ap, player.skeleton))
		ap.add_animation_library(&"reverse_plank", lib)
	active = true
	ap.animation_finished.connect(_finished)
	ap.play("reverse_plank/support", 0.25)
	player.camera_pivot.position.y = 0.45
	return true
func react(kind: String) -> void:
	if not active or kind not in ["dip"] or is_instance_valid(partner): return
	ap.play("reverse_plank/recoil", 0.08)
	ap.seek(0.0, true)
func _finished(_clip: StringName) -> void:
	if active: ap.play("reverse_plank/support", 0.10)
func _process(delta: float) -> void:
	_rest = maxf(0.0, _rest - delta)
	if _rest <= 0.0 and (not active or ap.current_animation != "reverse_plank/recoil"):
		stamina = minf(stamina_max, stamina + idle_regain * delta)
	# as the tandem poses: she stands up, dies or is hurt, and he lies back alone; he is hurt or dies, or spends himself
	# holding her up, and the pose ends
	if active and is_instance_valid(partner_pose) and not inviting and (not partner_pose.active or partner.is_dead
			or partner.health < _partner_health):
		_drop_partner()
		ap.play("reverse_plank/support", 0.25)
	if active and (player.is_dead or player.health < saved.health or player.kneeling != self): stop()
	elif active and joined and stamina <= 0.0: stop()
func stop() -> void:
	if not active: return
	active = false
	_drop_partner()
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
		push_error("REVERSE_PLANK preview entry blocked")
		return
	await get_tree().create_timer(3.0).timeout
	if "--reverse-wide-preview" in OS.get_cmdline_user_args() or "--reverse-wide-reversed-preview" in OS.get_cmdline_user_args():
		await invite_partner()
	player.camera_distance = 3.2
	player.yaw = player.rotation.y + PI * 0.5
	player.pitch = -0.18
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/frontier-reverse-plank.png")
	print("REVERSE_PLANK_READY Ctrl+Shift+N pose; I wide-kneel partner; K/B partner flinch; R reverse facing; Backspace exit")


func invite_partner() -> void:
	if not active or inviting or is_instance_valid(partner): return
	var at := _partner_spot()
	if at == Vector3.INF: return
	var p := FrontierPlayer.new()
	p.name = "WideKneelPartner"
	p.is_local = false
	p.controls = PlayerControls.new(false)
	p.use_appearance = false
	p.show_gear = false
	p.demo_horse = false
	p.demo_wheelbarrow = false
	player.get_parent().add_child(p)
	await _seat(p, at, true)


## Takes `p` (a FrontierPlayer: the wife's stand-in, or the player herself) as the Wide Kneel partner over the hold, for
## yoga together (TandemLink). Her own WideKneel (and the tandem gate it needs) is added when she has none.
func take_partner(p: FrontierPlayer) -> void:
	if not active or inviting or is_instance_valid(partner) or not is_instance_valid(p): return
	var tandem := player.get_node_or_null("TandemPoses")
	if tandem == null or not tandem.is_woman(p): return
	var at := _partner_spot()
	if at == Vector3.INF: return
	await _seat(p, at, false)


## Where she kneels: over the hips (partner_offset), on ground level with the hold; INF when not.
func _partner_spot() -> Vector3:
	var at: Vector3 = player.global_position + player.skeleton.get_parent().global_basis * partner_offset
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at - Vector3.UP * 0.4)
	query.exclude = [player.get_rid()]
	var ground := player.get_world_3d().direct_space_state.intersect_ray(query)
	if ground.is_empty() or absf(ground.position.y - player.global_position.y) > 0.08:
		return Vector3.INF
	return at


func _seat(p: FrontierPlayer, at: Vector3, owned: bool) -> void:
	inviting = true
	partner = p
	_owned = owned
	p.global_transform = player.global_transform
	p.global_position = at + Vector3.UP * 0.03
	p.yaw = player.rotation.y
	p.velocity = Vector3.ZERO
	player.add_collision_exception_with(p)
	p.add_collision_exception_with(player)
	if p.get_node_or_null("TandemPoses") == null:
		var gate: Node = load("res://features/tandem/frontier_tandem.gd").new()
		gate.player = p
		p.add_child(gate)
		gate.set_process_input(false)    # (her gate only checks the ground; the keys are the player's)
	partner_pose = p.get_node_or_null("WideKneel")
	if partner_pose == null:
		partner_pose = load("res://features/tandem/wide_kneel.gd").new()
		partner_pose.player = p
		p.add_child(partner_pose)
	for attempt in 80:
		await get_tree().create_timer(0.1).timeout
		if not active or not is_instance_valid(p) or partner != p: return
		if partner_pose.start():
			await get_tree().create_timer(0.3).timeout
			if not active or not is_instance_valid(partner_pose) or not partner_pose.active: return
			_apply_partner_facing()
			inviting = false
			joined = true
			mode = "wide"
			companion = player
			_partner_health = p.health
			partner_pose.base = self
			partner_pose.settled.connect(_on_partner_settled)
			ap.play("reverse_plank/support", 0.35)
			print("REVERSE_WIDE_PAIR_READY knees grounded")
			return
	_drop_partner()

func _drop_partner() -> void:
	inviting = false
	_rotation_applied = false
	joined = false
	mode = ""
	companion = null
	if is_instance_valid(partner_pose):
		if partner_pose.settled.is_connected(_on_partner_settled): partner_pose.settled.disconnect(_on_partner_settled)
		partner_pose.base = null
		partner_pose.stop()
	partner_pose = null
	if is_instance_valid(partner):
		player.remove_collision_exception_with(partner)
		partner.remove_collision_exception_with(player)
		if _owned:
			partner.queue_free()
	partner = null
	_owned = true


func _on_partner_settled(_kind: String) -> void:
	if not active or inviting or not is_instance_valid(partner_pose) or not partner_pose.active: return
	stamina = maxf(0.0, stamina - reaction_cost)
	_rest = recovery_delay
	ap.play(CLIPS.variant(ap, &"reverse_plank", "recoil", flinch_gauge()), 0.05)
	ap.seek(0.0, true)
	stamina_reacted.emit()


## The tandem flinch gauge of this pair (FrontierTandem.gauge_for): from the genital stat of the man in the plank; a
## woman there has none (the authored flinch).
func flinch_gauge() -> float:
	var tandem := player.get_node_or_null("TandemPoses")
	return TANDEM.gauge_for(tandem.genital_stat(player)) if tandem != null else 1.0


## Choose the normal or 180-degree Wide Kneel variant without moving its hip-support anchor.
func set_partner_reversed(value: bool) -> bool:
	if inviting: return false
	if is_instance_valid(partner_pose) and not partner_pose._reaction.is_empty(): return false
	partner_reversed = value
	_apply_partner_facing()
	return true

func _apply_partner_facing() -> void:
	if not is_instance_valid(partner) or not is_instance_valid(partner_pose) or not partner_pose.active: return
	if _rotation_applied == partner_reversed: return
	var pelvis_bone := partner.skeleton.find_bone("pelvis")
	var pose := partner.skeleton.get_bone_global_pose(pelvis_bone)
	var anchor := partner.skeleton.to_global(pose.origin)
	partner.rotate_y(PI)
	partner.global_position += anchor - partner.skeleton.to_global(pose.origin)
	partner.yaw = partner.rotation.y
	_rotation_applied = partner_reversed
