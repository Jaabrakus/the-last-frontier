extends Node
## Upright kneeling companion behind a puppy lead, using the game's existing pose handoff.
const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")
const SUPPORT = preload("res://features/tandem/puppy_pelvis_support.gd")
const KNEEL = preload("res://features/tandem/kneel_pose.gd")
@export var partner_offset := Vector3(0, 0, -0.30)
@export var reaction_delay := 0.15
var player: FrontierPlayer
var puppy: Node
var partner: FrontierPlayer
var partner_pose: Node
var motion: SkeletonModifier3D
var support: SkeletonModifier3D
var joined := false
var inviting := false
var _gate: Node
var _own_partner := true
var _health := 0.0
var _generation := 0
var _responses: Array[float] = []
func _ready() -> void: name = "PuppyTandem"
func invite_partner() -> bool:
	if not puppy.active or joined or inviting: return false
	_gate = player.get_node_or_null("TandemPoses")
	if _gate == null: return false
	var at: Vector3 = player.global_position + player.skeleton.get_parent().global_basis * partner_offset
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at - Vector3.UP * 0.5)
	ray.exclude = [player.get_rid()]
	var ground := player.get_world_3d().direct_space_state.intersect_ray(ray)
	if ground.is_empty() or absf(ground.position.y - player.global_position.y) > 0.10: return false
	inviting = true
	_generation += 1
	var generation := _generation
	_own_partner = true
	partner = FrontierPlayer.new()
	partner.name = "PuppyUprightPartner"
	partner.is_local = false
	partner.controls = PlayerControls.new(false)
	partner.use_appearance = false
	partner.show_gear = false
	partner.demo_horse = false
	partner.demo_wheelbarrow = false
	player.get_parent().add_child(partner)
	_gate._dress(partner, "english_f_a")
	partner.global_transform = player.global_transform
	partner.global_position = at + Vector3.UP * 0.04
	partner.yaw = player.rotation.y
	player.add_collision_exception_with(partner)
	partner.add_collision_exception_with(player)
	for attempt in 80:
		await get_tree().create_timer(0.1).timeout
		if generation != _generation or not puppy.active or not is_instance_valid(partner): return false
		if not _gate._available(partner): continue
		if _adopt(partner): return true
	stop_pair()
	return false
## An existing body (the yoga-together partner: the husband's stand-in, or the man himself) becomes the upright kneeling partner behind the
## puppy; it is not made and is not freed when the pair ends.
func take_partner(p: FrontierPlayer) -> bool:
	if not puppy.active or joined or inviting or not is_instance_valid(p) or p == player: return false
	_gate = player.get_node_or_null("TandemPoses")
	if _gate == null or not _gate._available(p): return false
	_generation += 1
	partner = p
	_own_partner = false
	player.add_collision_exception_with(p)
	p.add_collision_exception_with(player)
	# into the kneeling place behind her, facing as she faces (as invite_partner puts its own partner): the pair is joined at the hips
	var at: Vector3 = player.global_position + player.skeleton.get_parent().global_basis * partner_offset
	p.velocity = Vector3.ZERO
	p.global_transform = player.global_transform
	p.global_position = Vector3(at.x, player.global_position.y + 0.04, at.z)
	p.yaw = player.rotation.y
	if _adopt(p): return true
	partner = null
	player.remove_collision_exception_with(p)
	p.remove_collision_exception_with(player)
	return false
## The partner body `p` claimed and put in the upright kneel behind the puppy.
func _adopt(p: FrontierPlayer) -> bool:
	var ap: AnimationPlayer = _gate._claim(p)
	if ap == null: return false
	if not ap.has_animation_library(&"kneel_upright"):
		var library := AnimationLibrary.new()
		for kind in ["idle", "flinch"]:
			library.add_animation(kind, CLIPS.retarget(load("res://features/tandem/kneel_upright_" + kind + ".tres"), ap, p.skeleton))
		ap.add_animation_library(&"kneel_upright", library)
	partner_pose = KNEEL.new()
	partner_pose.anim_player = ap
	partner_pose.library = &"kneel_upright"
	partner_pose.loop_clip = "idle"
	partner_pose.flinch_clip = "flinch"
	partner_pose.backward_clip = CLIPS.retarget(load("res://features/tandem/kneel_upright_backward.tres"), ap, p.skeleton)
	add_child(partner_pose)
	motion = load("res://features/tandem/yoga_motion.gd").new()
	motion.name = "UprightYogaMotion"
	_gate._put_before_body(p.skeleton, motion)
	support = SUPPORT.new()
	support.name = "PuppyPelvisSupport"
	support.lead = player.skeleton
	support.lead_motion = puppy.motion
	_gate._put_before_body(p.skeleton, support)
	_health = p.health
	joined = true
	inviting = false
	print("PUPPY_UPRIGHT_PAIR_READY")
	return true
## The man himself, as the partner, stands up with the usual keys; K reacts.
func _input(e: InputEvent) -> void:
	if not joined or not is_instance_valid(partner) or not partner.is_local or player.is_local or not e is InputEventKey or not e.pressed or e.echo: return
	if e.physical_keycode == KEY_K: react()
	elif e.physical_keycode in [KEY_BACKSPACE, KEY_ESCAPE, KEY_N, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]: stop_pair()
	else: return
	get_viewport().set_input_as_handled()
func play_motion(kind: String, who := "both") -> bool:
	if not joined or not puppy.active or who not in ["both", "puppy", "upright"]: return false
	_responses.clear()
	var start_ms := Time.get_ticks_msec()
	if who in ["both", "puppy"]: puppy.play_motion(kind, start_ms)
	if who in ["both", "upright"]: motion.play_motion(kind, start_ms)
	return true
func react() -> bool:
	if not joined or not puppy.active or not is_instance_valid(partner_pose): return false
	if not partner_pose.flinch(): return false
	motion.cancel()
	puppy.motion.cancel()
	_responses.append(reaction_delay)
	return true
func _process(delta: float) -> void:
	if (joined or inviting) and not puppy.active:
		stop_pair()
		return
	if not joined: return
	if not is_instance_valid(partner) or partner.is_dead or partner.health < _health or partner.kneeling != _gate:
		stop_pair()
		return
	support.hold = minf(1.0, support.hold + delta / 0.25)
	for i in _responses.size(): _responses[i] -= delta
	while not _responses.is_empty() and _responses[0] <= 0:
		_responses.pop_front()
		puppy.flinch()
func stop_pair() -> void:
	_generation += 1
	joined = false
	inviting = false
	_responses.clear()
	if is_instance_valid(motion):
		motion.active = false
		motion.queue_free()
	motion = null
	if is_instance_valid(support):
		support.active = false
		support.queue_free()
	support = null
	if is_instance_valid(partner_pose):
		partner_pose.stop_session()
		partner_pose.queue_free()
	partner_pose = null
	if is_instance_valid(partner):
		if is_instance_valid(_gate): _gate._restore(partner)
		if is_instance_valid(player): player.remove_collision_exception_with(partner)
		partner.remove_collision_exception_with(player)
		if _own_partner: partner.queue_free()
	partner = null
func _exit_tree() -> void: stop_pair()
