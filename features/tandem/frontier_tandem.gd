extends Node
## In-world tandem interaction on FrontierPlayer's canonical rig.
## Two roles. The LEAD is in the crawl (N) or Happy Baby (Shift+N): women only. The PARTNER joins her tandem
## (kneeling behind the crawl, in the plank over Happy Baby): anyone can, of any look.
## Lead: I invites a companion (she joins as soon as both are ready; Enter joins at once, and dips in Happy Baby),
## K paired crawl flinch, B her own backward flinch (the crawl's only two flinches; her partner rocks back after B).
## In the crawl the partner's right hand holds her right bicep (IK).
## Partner: I next to a woman who is in a pose joins her; Enter dips (Happy Baby), K reacts (crawl).
## Both: C cinematic camera on / off (on once the pair is in the pose). Backspace or movement stands up.
## There is no on-screen text.

const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")
const CRAWL = preload("res://features/tandem/crawl_hold.gd")
const KNEEL = preload("res://features/tandem/kneel_pose.gd")
const YOGA = preload("res://features/tandem/yoga_hold_controller.gd")
const PLANK = preload("res://features/tandem/plank_dip_controller.gd")
const BARS = preload("res://features/tandem/tandem_bars.gd")
const ARM_HOLD = preload("res://features/tandem/tandem_arm_hold.gd")
const ARM_LIFT = preload("res://features/tandem/tandem_arm_lift.gd")
## The companion wears the game's own body (body v4) with this look (a CharacterPeoples preset).
const COMPANION_LOOK := "english_f_a"
## A woman in a pose can be joined from this far (m).
const JOIN_RANGE_M := 3.0
## An invitation left unanswered (no flat ground, a busy companion) is dropped after this long.
const INVITE_WAIT_S := 12.0
## The partner walks into the pose over this long, and out of it again (no snap, no shove).
const JOIN_S := 0.6
const LEAVE_S := 0.6
## Happy Baby's stamina. The lead's pool is seconds of holding (a bar drains 1 a second and she collapses at zero;
## the shaking only starts in the last quarter); a dip costs the partner PLANK_DIP_COST of her PLANK_MAX (she
## regains PLANK_REGAIN a second after PLANK_REST_S), strains the lead a little and makes her flinch.
const YOGA_HOLD_S := 120.0
const YOGA_TREMOR_FROM := 0.25
const YOGA_FLINCH_BELOW := 0.12
const PLANK_MAX := 100.0
const PLANK_DIP_COST := 25.0
const PLANK_REGAIN := 3.0
const PLANK_REST_S := 0.75
const DIP_LEAD_COST := 3.0
## The lead flinches when the dip reaches its lowest point (0.33 s into the 1.67 s clip).
const DIP_REACT_DELAY := 0.33
## The flinch gauge: how full the flinches a tandem causes play, from the male partner's genital stat (the look's
## `genital`, -1..1, the customizer's body slider): 1 plays the authored flinch, 0 half of it, -1 a quarter (linear
## between). A partner who is not a man has no such stat: the authored flinch. It shapes the partner's own K flinch
## and the lead's answer (a K in the crawl, a dip in Happy Baby); the lead's own B is always as authored.
const GAUGE_AT_ONE := 1.0
const GAUGE_AT_ZERO := 0.5
const GAUGE_AT_MINUS_ONE := 0.25
## Cinematic camera: side-on to the pair, a little above, slowly drifting; eased in over CINE_BLEND_S.
const CINE_BLEND_S := 1.4
const CINE_PITCH := -0.10
const CINE_DIST := {"crawl": 2.6, "yoga": 2.7, "wide": 2.6}
const CINE_PIVOT_Y := {"crawl": 0.55, "yoga": 0.6, "wide": 0.8}
## Which side of the pair the shot is taken from: +1 her right (where the crawl's arm is lifted and held), -1 her
## left. Measured against her own shoulders (the rig faces +Z, the game -Z: her right is +1 here).
const CINE_SIDE := {"crawl": 1.0, "yoga": 1.0, "wide": 1.0}
@export var crawl_offset := Vector3(0, 0, -0.30)
@export var reaction_delay := 0.15
@export var cinematic := true
var player: FrontierPlayer
## The partner of the pose this controller leads: the invited companion, or a player who joined (a visitor).
var companion: FrontierPlayer
var mode := ""
var invited := false
var joined := false
var base_pose: Node
var partner_pose: Node
## The controller of the pose this player joined as its partner (null when leading or free).
var _lead: Node
var _visitor := false
var _own_companion: FrontierPlayer
var _saved: Dictionary = {}
var _responses: Array[float] = []
var _peer_return := Transform3D.IDENTITY
var _health := 0.0
var _peer_health := 0.0
var _crawl_stamina := 100.0
var _kneel_stamina := 100.0
var _invite_left := 0.0
var _retry := 0.0
var _join_t := 1.0
var _join_from := Transform3D.IDENTITY
var _cine := 0.0
var _cine_time := 0.0
var _cine_mode := "crawl"
var _cam0: Dictionary = {}
## The Reverse Plank pair's camera: before the woman on top (its eased yaw; INF: not yet).
var _cine_front := INF
## Partners under a player's own control that stood up inside the pose: collision comes back once they are clear.
var _separating: Dictionary = {}
var _exiting := false
## The partner's right hand on the crawler's right bicep (the crawl), and the partner's answers to her backward flinch.
var _arm_hold: Node
var _arm_lift: Node
var _partner_back: Array[float] = []
var _bars: Control
var _plank_stamina := PLANK_MAX
var _plank_rest := 0.0

func _ready() -> void:
	name = "TandemPoses"
	process_priority = 60
	if player.is_local:
		var layer := CanvasLayer.new()
		layer.layer = 8
		add_child(layer)
		_bars = BARS.new()
		layer.add_child(_bars)
	var args := OS.get_cmdline_user_args()
	if player.is_local and "--two-pose-preview" in args:
		call_deferred("_preview_two_poses")
	elif player.is_local and "--tandem-preview" in args:
		call_deferred("_preview", "crawl")
	elif player.is_local and "--tandem-preview-yoga" in args:
		call_deferred("_preview", "yoga")

func _input(event: InputEvent) -> void:
	# The solo wide-kneel controller owns its keys and pose.
	if player.kneeling != null and player.kneeling.name in ["WideKneel", "ReversePlank"]: return
	if event is InputEventKey and event.ctrl_pressed and event.physical_keycode == KEY_N: return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if not mode.is_empty():
		match key:
			KEY_N, KEY_BACKSPACE, KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE:
				stop_pose()
			KEY_I: invite_partner()
			KEY_C: cinematic = not cinematic
			KEY_ENTER:
				if joined and mode == "yoga": partner_enter()
				elif invited: accept_partner()
			KEY_K: partner_reaction()
			KEY_B: lead_backward()
		# Pose mode owns keyboard actions; weapon/build/inventory keys cannot steal it.
	elif is_instance_valid(_lead):
		match key:
			KEY_N, KEY_BACKSPACE, KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE:
				_lead.stop_partner()
			KEY_C: cinematic = not cinematic
			KEY_ENTER: _lead.partner_enter()
			KEY_K: _lead.partner_reaction()
	elif key == KEY_N and is_woman(player):
		start_pose("yoga" if event.shift_pressed else "crawl")
	elif not (key == KEY_I and join_nearby()):
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	if _lead != null and not is_instance_valid(_lead):
		_lead_ended()
	_separate(delta)
	if not mode.is_empty():
		if player.is_dead or player.health < _health or player.kneeling != self or not is_woman(player):
			stop_pose()
		elif mode == "crawl" and not base_pose.holding:
			stop_pose()
		elif mode == "yoga" and base_pose.state == base_pose.State.COLLAPSE:
			stop_pose()
		elif joined:
			if not is_instance_valid(companion) or companion.is_dead or companion.health < _peer_health:
				_drop_partner()
			else:
				_align_partner(delta)
				if is_instance_valid(_arm_hold): _arm_hold.hold = smoothstep(0.0, 1.0, _join_t)
				if is_instance_valid(_arm_lift): _arm_lift.lift = smoothstep(0.0, 1.0, _join_t)
				for i in _partner_back.size(): _partner_back[i] -= delta
				while not _partner_back.is_empty() and _partner_back[0] <= 0:
					_partner_back.pop_front()
					if mode == "crawl" and is_instance_valid(partner_pose): partner_pose.flinch_backward(flinch_gauge())
				for i in _responses.size(): _responses[i] -= delta
				while not _responses.is_empty() and _responses[0] <= 0:
					_responses.pop_front()
					_lead_reacts()
		elif invited:
			_answer_invitation(delta)
	if mode.is_empty():
		_crawl_stamina = minf(_crawl_stamina + 3.0 * delta, 100.0)
		_kneel_stamina = minf(_kneel_stamina + 3.0 * delta, 100.0)
	_plank_rest -= delta
	if _plank_rest <= 0.0:
		_plank_stamina = minf(_plank_stamina + PLANK_REGAIN * delta, PLANK_MAX)
	_cinematic(delta)
	if _bars != null: _bars.show_values(_pair_stamina(), delta)

## Only women lead these poses (the crawl and Happy Baby). A player without a customizer look (use_appearance
## off) wears the legacy clothed female base body; otherwise the look's sex decides (CreatorOptions.is_male).
## Joining a tandem as the partner is open to anyone.
func is_woman(p: FrontierPlayer) -> bool:
	if not is_instance_valid(p): return false
	return p.appearance == null or not CreatorOptions.is_male(p.appearance.look)

func _available(p: FrontierPlayer) -> bool:
	return is_instance_valid(p) and not p.is_dead and p.is_on_floor() and p.kneeling == null \
		and p.climbing == null and p.riding == null and p.perch == null and p.pushing == null \
		and not p.is_switching() and not (p.traversal and p.traversal.showing) \
		and not (p.building and p.building.active) and not is_instance_valid(p._inv_screen) \
		and p.drag_speed_cap == INF

func start_pose(which: String) -> bool:
	if not mode.is_empty() or is_instance_valid(_lead) or not is_woman(player) or not _available(player):
		return false
	var ap := _claim(player)
	if ap == null: return false
	mode = which
	_health = player.health
	if mode == "crawl":
		CLIPS.install(ap, player.skeleton, "res://features/tandem/actor_b_crawl.glb", &"tandem_crawl")
		base_pose = CRAWL.new()
		base_pose.anim_player = ap
		base_pose.library = &"tandem_crawl"
		base_pose.backward_clip = CLIPS.retarget(load("res://features/tandem/crawl_backward_flinch.tres"), ap, player.skeleton)
		base_pose.drain_hold = 0.0
		base_pose.recover_while_holding = true
		base_pose.regain = 3.0
		base_pose.rest_s = 0.75
		add_child(base_pose)
		base_pose.stamina = _crawl_stamina
		if not base_pose.start_hold():
			stop_pose()
			return false
	else:
		CLIPS.install(ap, player.skeleton, "res://features/tandem/actor_b_yoga.glb", &"tandem_yoga")
		base_pose = YOGA.new()
		base_pose.animation_player = ap
		base_pose.library = &"tandem_yoga"
		# The pose's own 10 s pool ended it in the middle of an invitation: a long one, shown on the bars.
		base_pose.max_stamina = YOGA_HOLD_S
		base_pose.tremor_from = YOGA_TREMOR_FROM
		base_pose.flinch_below = YOGA_FLINCH_BELOW
		add_child(base_pose)
		base_pose.set_held(true)
	player.camera_pivot.position.y = 0.8
	return true


# ---------------------------------------------------------------------------------------------
# The partner: a companion invited by the lead, or anyone who walks up and joins
# ---------------------------------------------------------------------------------------------

## Joins the nearest woman in a pose (within JOIN_RANGE_M, her partner place free) as her partner. Anyone can:
## the pose asks nothing of the partner's look. False when nobody is near.
func join_nearby() -> bool:
	if mode != "" or is_instance_valid(_lead) or not _available(player): return false
	var best: Node = null
	var best_d := JOIN_RANGE_M
	for n: Node in player.get_parent().get_children():
		if n == player or not n is FrontierPlayer: continue
		# someone in the Reverse Plank with nobody over them: a woman kneels over them (reverse_plank.gd)
		var rp := n.get_node_or_null("ReversePlank")
		if rp != null and rp.active and not rp.joined and not rp.inviting and is_woman(player) \
				and player.global_position.distance_to((n as Node3D).global_position) < best_d:
			rp.take_partner(player)
			return true
		var t := n.get_node_or_null("TandemPoses")
		if t == null or t.mode.is_empty() or t.joined: continue
		var d := player.global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best = t
			best_d = d
	return best != null and best.take_partner(player)

## `p` (anyone) becomes this pose's partner. Happy Baby takes partners once she is holding it.
func take_partner(p: FrontierPlayer) -> bool:
	if mode.is_empty() or joined or p == player or not is_instance_valid(p): return false
	if mode == "yoga" and base_pose.state != base_pose.State.HOLD: return false
	var was_invited := invited
	_own_companion = companion
	companion = p
	invited = true
	if accept_partner():
		_visitor = true
		var t := p.get_node_or_null("TandemPoses")
		if t != null and t != self: t._lead = self
		return true
	companion = _own_companion
	_own_companion = null
	invited = was_invited
	return false

## The partner's keys, from whoever leads: a dip in Happy Baby, a reaction in the crawl.
func partner_enter() -> void:
	if joined and mode == "yoga" and _plank_stamina >= PLANK_DIP_COST:
		partner_pose.request_dip()

## A dip began (also one buffered from an earlier press): it costs the partner, and strains the lead a little.
func _on_dipped() -> void:
	_plank_stamina = maxf(_plank_stamina - PLANK_DIP_COST, 0.0)
	_plank_rest = PLANK_REST_S
	if is_instance_valid(base_pose): base_pose.stamina = maxf(base_pose.stamina - DIP_LEAD_COST, 0.0)
	_responses.append(DIP_REACT_DELAY)

## The lead's flinch answering her partner: in the crawl a partner's flinch, in Happy Baby a dip.
func _lead_reacts() -> void:
	if not is_instance_valid(base_pose): return
	if mode == "crawl": base_pose.flinch("partner", flinch_gauge())
	else: base_pose.flinch(0.0, flinch_gauge())

## The genital stat of a man's look (-1..1). A partner who is not a man has none (NAN).
func genital_stat(p: FrontierPlayer) -> float:
	if is_instance_valid(p) and p.appearance != null and CreatorOptions.is_male(p.appearance.look):
		return clampf(float(p.appearance.look.get("genital", 0.0)), -1.0, 1.0)
	return NAN

## How full a flinch plays for that stat: GAUGE_AT_ONE at 1 (the authored flinch), GAUGE_AT_ZERO at 0,
## GAUGE_AT_MINUS_ONE at -1, linear between. No stat (not a man): the authored flinch.
static func gauge_for(stat: float) -> float:
	if is_nan(stat):
		return GAUGE_AT_ONE
	var g := clampf(stat, -1.0, 1.0)
	return lerpf(GAUGE_AT_ZERO, GAUGE_AT_ONE, g) if g >= 0.0 else lerpf(GAUGE_AT_ZERO, GAUGE_AT_MINUS_ONE, -g)

## The flinch gauge of this tandem: from its partner's genital stat.
func flinch_gauge() -> float:
	return gauge_for(genital_stat(companion))

## The lead's own backward flinch; her partner rocks back after it (his own backward flinch, at the gauge).
func lead_backward() -> void:
	if mode == "crawl" and base_pose.flinch_backward() and joined:
		_partner_back.append(reaction_delay)

func partner_reaction() -> void:
	if mode == "crawl" and joined and base_pose.stamina > 0 and partner_pose.flinch(flinch_gauge()):
		base_pose.pause_recovery()
		_responses.append(reaction_delay)

## The partner stands up; the lead stays in her pose.
func stop_partner() -> void:
	_drop_partner()

## Invites the companion: she appears beside you and joins as soon as both are ready (in Happy Baby, once you
## are holding the pose), or at once on Enter. Asking again while she is on the way does nothing.
func invite_partner() -> bool:
	if mode.is_empty() or joined or invited: return false
	if not is_instance_valid(companion):
		companion = FrontierPlayer.new()
		companion.name = "TandemCompanion"
		companion.is_local = false
		companion.controls = PlayerControls.new(false)
		companion.demo_horse = false
		companion.demo_wheelbarrow = false
		companion.show_gear = false
		companion.use_appearance = false
		player.get_parent().add_child(companion)
		_dress(companion, COMPANION_LOOK)
		companion.toggle_hands_free()
		companion.global_position = _spot_beside() + Vector3.UP * 0.05
	elif companion.global_position.distance_to(player.global_position) > 4.0:
		companion.global_position = _spot_beside() + Vector3.UP * 0.05
	_face(companion, player.global_position)
	invited = true
	_invite_left = INVITE_WAIT_S
	return true

## A place beside the player on the same flat ground with nothing between: right, left, ahead, behind.
func _spot_beside() -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var b := player.global_basis
	var from := player.global_position
	for d: Vector3 in [b.x * 1.5, -b.x * 1.5, -b.z * 1.6, b.z * 1.6]:
		var at := from + d
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at - Vector3.UP * 0.8)
		ray.exclude = [player.get_rid()]
		var ground := space.intersect_ray(ray)
		if ground.is_empty() or absf(ground.position.y - from.y) > 0.15: continue
		var wall := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.9, at + Vector3.UP * 0.9)
		wall.exclude = [player.get_rid()]
		if not space.intersect_ray(wall).is_empty(): continue
		return ground.position
	return from + b.x * 1.5

func _face(p: FrontierPlayer, at: Vector3) -> void:
	var to := at - p.global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		p.rotation.y = atan2(-to.x, -to.z)
		p.yaw = p.rotation.y

## The waiting invitation: joins when the pose and the companion are ready, drops after INVITE_WAIT_S.
func _answer_invitation(delta: float) -> void:
	_invite_left -= delta
	if _invite_left <= 0.0:
		invited = false
		return
	_retry -= delta
	if _retry > 0.0: return
	_retry = 0.2
	if mode == "yoga" and base_pose.state != base_pose.State.HOLD: return
	accept_partner()

func accept_partner() -> bool:
	if not invited or not _available(companion): return false
	var offset: Vector3 = player.skeleton.get_parent().global_basis * (crawl_offset if mode == "crawl" else Vector3.ZERO)
	var at: Vector3 = player.global_position + offset
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at - Vector3.UP * 0.5)
	ray.exclude = [player.get_rid(), companion.get_rid()]
	var ground := player.get_world_3d().direct_space_state.intersect_ray(ray)
	if ground.is_empty() or absf(ground.position.y - player.global_position.y) > 0.15:
		return false
	_peer_return = companion.global_transform
	var ap := _claim(companion)
	if ap == null: return false
	_peer_health = companion.health
	player.add_collision_exception_with(companion)
	companion.add_collision_exception_with(player)
	if mode == "crawl":
		CLIPS.install(ap, companion.skeleton, "res://features/tandem/actor_b_kneel.glb", &"tandem_kneel")
		partner_pose = KNEEL.new()
		partner_pose.anim_player = ap
		partner_pose.library = &"tandem_kneel"
		partner_pose.backward_clip = CLIPS.retarget(load("res://features/tandem/kneel_backward_flinch.tres"), ap, companion.skeleton)
		add_child(partner_pose)
		partner_pose.stamina = _kneel_stamina
		_hold_her_arm()
	else:
		CLIPS.install(ap, companion.skeleton, "res://features/tandem/actor_b_yoga.glb", &"tandem_yoga")
		partner_pose = PLANK.new()
		partner_pose.animation_player = ap
		partner_pose.library = &"tandem_yoga"
		partner_pose.base_clip = &"flow"
		partner_pose.read_input = false
		partner_pose.dipped.connect(_on_dipped)
		add_child(partner_pose)
	companion.camera_pivot.position.y = 0.8
	joined = true
	invited = false
	_join_from = companion.global_transform
	_join_t = 0.0
	_align_partner(0.0)
	return true

## The partner's right hand takes hold of the crawler's right bicep and lifts her right arm (IK: TandemArmHold on the
## partner, TandemArmLift on the crawler), from the moment the partner moves in.
func _hold_her_arm() -> void:
	_arm_lift = ARM_LIFT.new()
	_arm_lift.name = "TandemArmLift"
	_put_before_body(player.skeleton, _arm_lift)
	_arm_hold = ARM_HOLD.new()
	_arm_hold.name = "TandemArmHold"
	_arm_hold.lead = player.skeleton
	_arm_hold.lead_lift = _arm_lift
	_put_before_body(companion.skeleton, _arm_hold)

## A modifier on a skeleton, before the props' last placement and the body mesh (which keeps itself last).
func _put_before_body(sk: Skeleton3D, m: Node) -> void:
	sk.add_child(m)
	for i in sk.get_child_count():
		var c := sk.get_child(i)
		if c is CharacterBodyMesh or String(c.name) == "HandPropsFinal":
			sk.move_child(m, i)
			break

## The partner in her place in the pose; on joining she moves there over JOIN_S instead of appearing on it.
func _align_partner(delta: float) -> void:
	var tf := player.global_transform
	if mode == "crawl":
		tf.origin += player.skeleton.get_parent().global_basis * crawl_offset
	else:
		tf.basis = tf.basis.rotated(Vector3.UP, PI)
	if _join_t < 1.0:
		_join_t = minf(_join_t + delta / JOIN_S, 1.0)
		tf = _join_from.interpolate_with(tf, smoothstep(0.0, 1.0, _join_t))
	companion.global_transform = tf
	if not companion.is_local:
		companion.yaw = companion.rotation.y   # (a player's yaw is their camera: the cinematic shot owns it)

func _claim(p: FrontierPlayer) -> AnimationPlayer:
	var ap := p.begin_kneel(self, p.global_position - p.global_basis.z)
	if ap == null: return null
	var state := {"active": p.anim.active, "camera_y": p.camera_pivot.position.y, "nodes": [], "hud": null}
	p.anim.active = false
	# The interact prompt ("E Take ...") would stay on screen, stale, while the interactor is paused.
	if p.interactor != null and "_layer" in p.interactor and p.interactor._layer is CanvasLayer:
		state.hud = p.interactor._layer
		state.hud.visible = false
	# Polling subsystems also need to pause; consuming a key event alone is insufficient.
	for n: Node in [p.building, p.interactor, p.torch, p.gather, p.equip_wheel, p.get_node_or_null("Weapons")]:
		if n != null:
			state.nodes.append([n, n.process_mode])
			n.process_mode = Node.PROCESS_MODE_DISABLED
	_saved[p] = state
	return ap

## Gives a claimed player back to normal play (process modes, animation, camera height, the pose handoff).
func _restore(p: Node) -> void:
	if not _saved.has(p): return
	var state: Dictionary = _saved[p]
	_saved.erase(p)
	if not is_instance_valid(p): return
	for pair: Array in state.nodes:
		if is_instance_valid(pair[0]): pair[0].process_mode = pair[1]
	p.camera_pivot.position.y = state.camera_y
	p.anim.active = state.active
	if is_instance_valid(state.hud): state.hud.visible = true
	if p.kneeling == self: p.end_kneel()

func stop_pose() -> void:
	if mode.is_empty(): return
	var was_crawl := mode == "crawl"
	mode = ""
	invited = false
	_release_camera()
	if is_instance_valid(base_pose):
		if was_crawl: _crawl_stamina = base_pose.stamina
		base_pose.tree.active = false
		base_pose.process_mode = Node.PROCESS_MODE_DISABLED
		base_pose.queue_free()
	base_pose = null
	_drop_partner(was_crawl)
	for p: Node in _saved.keys():
		_restore(p)

## The partner stands up (the lead stays in her pose). The partner walks aside instead of being shoved: the pair
## shared the spot (in Happy Baby exactly), and lifting their collision exception on top of each other threw the
## player across the map and snapped the partner back to where she stood.
func _drop_partner(was_crawl := mode == "crawl") -> void:
	if not joined: return
	_responses.clear()
	_partner_back.clear()
	if is_instance_valid(_arm_hold): _arm_hold.queue_free()
	_arm_hold = null
	if is_instance_valid(_arm_lift): _arm_lift.queue_free()
	_arm_lift = null
	if is_instance_valid(partner_pose):
		if was_crawl: _kneel_stamina = partner_pose.stamina
		partner_pose.stop_session()
		partner_pose.queue_free()
	partner_pose = null
	joined = false
	var c := companion
	if is_instance_valid(c):
		_restore(c)
		var t := c.get_node_or_null("TandemPoses")
		if t != null and t != self: t._lead_ended()
		_release_companion(c)
	if _visitor:
		companion = _own_companion
		_own_companion = null
		_visitor = false

func _release_companion(c: FrontierPlayer) -> void:
	if c.is_local and not _exiting:
		# A player stands up where she is and walks off (no slide against her keys): the pair's collision exception
		# stays until they are apart.
		_separating[c] = 6.0
		return
	var to_yaw := c.rotation.y + wrapf(_peer_return.basis.get_euler().y - c.rotation.y, -PI, PI)
	if _exiting or not is_inside_tree():
		c.global_transform = _peer_return
		c.yaw = c.rotation.y
		_pair_apart(c)
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(c, "global_position", _peer_return.origin, LEAVE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "yaw", to_yaw, LEAVE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(_pair_apart.bind(c))

func _separate(delta: float) -> void:
	for c in _separating.keys():
		_separating[c] -= delta
		if not is_instance_valid(c) or _separating[c] <= 0.0 \
				or Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z).length() > 0.9:
			_separating.erase(c)
			_pair_apart(c)

func _pair_apart(c: FrontierPlayer) -> void:
	if is_instance_valid(player) and is_instance_valid(c):
		player.remove_collision_exception_with(c)
		c.remove_collision_exception_with(player)

## The pose this player joined has ended (or she stood up): back to normal play and the normal camera.
func _lead_ended() -> void:
	_lead = null
	_release_camera()

func _exit_tree() -> void:
	_exiting = true
	if is_instance_valid(_lead): _lead.stop_partner()
	stop_pose()
	if is_instance_valid(companion) and is_instance_valid(player):
		_pair_apart(companion)
	for c in _separating.keys():
		_pair_apart(c)


# ---------------------------------------------------------------------------------------------
# Cinematic camera
# ---------------------------------------------------------------------------------------------

## The lead's stamina and the partner's, 0..1 (1 when there is none).
func lead_fraction() -> float:
	if not is_instance_valid(base_pose): return 1.0
	return base_pose.stamina / base_pose.stamina_max if mode == "crawl" else base_pose.stamina_fraction()

func partner_fraction() -> float:
	if mode == "yoga": return _plank_stamina / PLANK_MAX
	return partner_pose.stamina / partner_pose.stamina_max if is_instance_valid(partner_pose) else 1.0

## (yours, the other's) for the bars while this player is paired in a pose, else (-1, -1). The Reverse Plank pair
## (reverse_plank.gd, wide_kneel.gd): his stamina holding her, hers for her flinches.
func _pair_stamina() -> Vector2:
	var k: Node = player.kneeling
	if k != null and k.name == "ReversePlank" and k.joined and is_instance_valid(k.partner_pose):
		return Vector2(k.stamina / k.stamina_max, k.partner_pose.stamina / k.partner_pose.stamina_max)
	if k != null and k.name == "WideKneel" and is_instance_valid(k.base) and k.base.joined:
		return Vector2(k.stamina / k.stamina_max, k.base.stamina / k.base.stamina_max)
	if is_instance_valid(_lead):
		return Vector2(_lead.partner_fraction(), _lead.lead_fraction()) if _lead.joined else Vector2(-1.0, -1.0)
	return Vector2(lead_fraction(), partner_fraction()) if joined else Vector2(-1.0, -1.0)

## The pose this player is paired in, as lead or partner ("" when alone).
func _pair_mode() -> String:
	var k: Node = player.kneeling
	if k != null and ((k.name == "ReversePlank" and k.joined) or (k.name == "WideKneel" and is_instance_valid(k.base))):
		return "wide"
	if is_instance_valid(_lead): return _lead.mode if _lead.joined else ""
	return mode if joined else ""

## Once both are in the pose the camera settles side-on to the pair, a little above, and drifts slowly; C gives
## the camera back. Nothing changes while alone.
func _cinematic(delta: float) -> void:
	var pair := _pair_mode()
	var want := cinematic and pair != "" and is_instance_valid(player.spring_arm)
	if want and _cine <= 0.0:
		_cine_mode = pair
		_cine_time = 0.0
		_cine_front = INF
		_cam0 = {"yaw": player.yaw, "pitch": player.pitch, "dist": player.spring_arm.spring_length,
				"y": player.camera_pivot.position.y}
	if not want and _cine <= 0.0: return
	_cine = move_toward(_cine, 1.0 if want else 0.0, delta / CINE_BLEND_S)
	_cine_time += delta
	var e := smoothstep(0.0, 1.0, _cine)
	var facing: float = _lead.player.rotation.y if is_instance_valid(_lead) else player.rotation.y
	var yaw_to: float = facing + PI * 0.5 * float(CINE_SIDE[_cine_mode]) + sin(_cine_time * 0.4) * 0.16
	var her := _wide_upper() if _cine_mode == "wide" else null
	if her != null:
		# the Reverse Plank pair (user 2026-09-29: "the camera face the partner on top"): out before the woman kneeling
		# on top, looking at her (her rig's +Z is her front), easing round when she turns about (R)
		var f: Vector3 = her.skeleton.get_parent().global_basis.z
		var front := atan2(f.x, f.z) + sin(_cine_time * 0.4) * 0.12
		_cine_front = front if _cine_front == INF else lerp_angle(_cine_front, front, minf(1.0, delta * 2.5))
		yaw_to = _cine_front
	player.yaw = lerp_angle(_cam0.yaw, yaw_to, e)
	player.pitch = lerpf(_cam0.pitch, CINE_PITCH, e)
	player.spring_arm.spring_length = lerpf(_cam0.dist, CINE_DIST[_cine_mode], e)
	player.camera_pivot.position.y = lerpf(_cam0.y, CINE_PIVOT_Y[_cine_mode], e)

## The woman kneeling on top in the Reverse Plank pair: this player, or the one over this player's plank; else null.
func _wide_upper() -> FrontierPlayer:
	var k: Node = player.kneeling
	if k != null and k.name == "ReversePlank" and is_instance_valid(k.partner) and k.joined:
		return k.partner
	if k != null and k.name == "WideKneel" and is_instance_valid(k.base):
		return player
	return null

func _release_camera() -> void:
	if _cine <= 0.0 or _cam0.is_empty(): return
	_cine = 0.0
	if is_instance_valid(player) and is_instance_valid(player.spring_arm):
		player.spring_arm.spring_length = _cam0.dist
		player.pitch = _cam0.pitch


# ---------------------------------------------------------------------------------------------
# Looks and previews
# ---------------------------------------------------------------------------------------------

## Dresses a player in the game's own body (body v4) with a CharacterPeoples preset. A player that has no
## customizer look yet (a companion, a dummy) gets one attached; it takes no input of its own.
func _dress(p: FrontierPlayer, look_id: String) -> void:
	var look := CharacterPeoples.preset_look(look_id)
	if look.is_empty(): return
	if p.appearance != null:
		p.appearance.apply(look)
		return
	var body := p.skeleton.get_node_or_null("Body") as CharacterBodyMesh
	if body == null: return
	var pa := PlayerAppearance.new()
	pa.name = "Appearance"
	pa.body = body
	pa.set_process_unhandled_input(false)
	p.add_child(pa)
	p.appearance = pa
	pa.apply(look)

## An NPC: a FrontierPlayer nobody controls.
func _make_npc(npc_name: String) -> FrontierPlayer:
	var npc := FrontierPlayer.new()
	npc.name = npc_name
	npc.is_local = false
	npc.controls = PlayerControls.new(false)
	npc.demo_horse = false
	npc.demo_wheelbarrow = false
	npc.show_gear = false
	npc.use_appearance = false
	return npc


func _preview(which: String) -> void:
	_dress(player, "japanese_f_a")
	for attempt in 40:
		await get_tree().create_timer(0.25).timeout
		if start_pose(which): break
	if mode.is_empty():
		print("TANDEM_PREVIEW_ENTRY_BLOCKED floor=", player.is_on_floor(), " switching=", player.is_switching(), " kneeling=", player.kneeling, " drag=", player.drag_speed_cap, " pos=", player.global_position)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/frontier-in-world-tandem.png")
		return
	invite_partner()
	for attempt in 80:
		await get_tree().create_timer(0.25).timeout
		if joined: break
	print("TANDEM_PREVIEW_JOINED ", joined)
	if joined:
		await get_tree().create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/frontier-in-world-tandem-%s.png" % which)
		print("IN_WORLD_TANDEM_READY ", which)


## Two NPC women in the game's own body (body v4) pose in front of the spawn: one in Happy Baby, one crawling.
## The player stays free (any look): walk up to either and press I to join her as her partner.
func _preview_two_poses() -> void:
	await get_tree().create_timer(1.0).timeout
	var forward := -player.global_basis.z
	var right := player.global_basis.x
	var placed := []
	for spec: Array in [["FemaleHappyBabyNpc", "yoga", "haudenosaunee_f_a", -1.4], ["FemaleCrawlNpc", "crawl", "japanese_f_a", 1.4]]:
		var npc := _make_npc(spec[0])
		player.get_parent().add_child(npc)
		_dress(npc, spec[2])
		npc.global_position = player.global_position + forward * 2.0 + right * float(spec[3]) + Vector3.UP * 0.15
		npc.rotation.y = player.rotation.y + PI * 0.5
		npc.yaw = npc.rotation.y
		var poses: Node = get_script().new()
		poses.player = npc
		npc.add_child(poses)
		poses.set_process_input(false)
		for attempt in 120:
			await get_tree().create_timer(0.25).timeout
			if poses.start_pose(spec[1]): break
		placed.append(poses.mode)
	print("TWO_FEMALE_POSES_READY ", placed)
