class_name TandemLink
extends Node
## The node side of the intimacy gauge and the yoga together (user 2026-09-28). A child of Household (it creates one). It
## keeps the gauge (Intimacy, on the spouse's SpouseCore) fed from what happens in the world (time near her, meals,
## gifts to the store, finished jobs, talk), makes the offer when the gauge is full and all is calm, runs the YogaFlow
## state machine (her borrowed follow role, the offer prompt, the pose menu) and starts the real tandem pose through
## TandemProxy (features/tandem is not changed): the woman leads, the man joins as the partner.
##   Household.link.talked()          a Talk tab reply (once an hour counts)
##   Household.link.yoga_gate()       "" or the reason yoga cannot be asked now
##   Household.link.ask()             the Talk tab's button: her line (she follows, or says why not)

var house: Household
var intim: Intimacy
var flow: YogaFlow
var proxy: FrontierPlayer
## The proxy's own tandem controller when she leads (the wife, for a male player).
var lead: Node
var leader := ""
## The pose of the session (Happy Baby: "yoga"; the tandem feature's only pose started through the yoga-together menu).
var _pose := ""
## The puppy of the session (features/tandem/puppy_pose.gd on whoever leads) and its pair (puppy_tandem.gd).
var _pup: Node
var _pup_pair: Node
var _sc: SpouseCore
var _prev_min := -1.0
var _prev_stomach := 0.0
var _prev_food := -1
var _food_t := 0.0
var _last_cook := -1e12
var _hp_prev := -1.0
var _hurt_t := 0.0
var _danger := false
var _danger_t := 0.0
var _borrowed := false
var _prev_role := "home"
var _prev_focus := ""
var _prompt: YogaPrompt
var _try_t := 0.0
var _start_failed := false
var _finish_t := 0.0
var _dist := 0.0
const JOIN_RANGE_M := 3.0
var _pre: FrontierPlayer
## She is in her pose and the player has not joined: the partner presses I (user 2026-10-01: "the other partner presses a button to
## join", not entering by itself).
var _waiting_join := false
var _hint_layer: CanvasLayer
var _hint: Label
var _pre_layer := 1
var _pre_mask := 1
var _pre_look := 0


func _bind(sc: SpouseCore) -> void:
	_sc = sc
	intim = Intimacy.new(sc)
	flow = YogaFlow.new(intim)
	_prev_min = -1.0
	_prev_food = -1
	sc.task_finished.connect(func(_t: String, _x: String) -> void:
		if intim != null and _sc == sc:
			if _t == "cook":
				_last_cook = sc.core.state.minutes
			intim.on_job(sc.core.state.minutes))


func _process(dt: float) -> void:
	var sc := house.sc if house != null else null
	if sc == null or not is_instance_valid(house.player):
		return
	if sc != _sc:
		_bind(sc)
	var now := sc.core.state.minutes
	var dm := maxf(now - _prev_min, 0.0) if _prev_min >= 0.0 else 0.0
	_prev_min = now
	var body := house.body if is_instance_valid(house.body) else null
	var at: Vector3 = proxy.global_position if is_instance_valid(proxy) else (body.global_position if body else Vector3.INF)
	_dist = house.player.global_position.distance_to(at) if at != Vector3.INF else 1e9
	_watch(dt, now)
	if _waiting_join and _paired():
		_waiting_join = false
	_update_hint()
	intim.tick(dm, _dist <= float(intim.cfg.near_m) and not flow.active(), sc.awake() and not house.player.is_dead, now)
	if _finish_t > 0.0:
		_finish_t -= dt
		if _finish_t <= 0.0:
			_park_end()
		return
	var ctx := _ctx()
	if flow.state == YogaFlow.S.IDLE:
		if house.screen == null and not get_tree().paused and body != null:
			flow.idle_step(dt, ctx)
	elif flow.state != YogaFlow.S.OFFERED:
		if flow.state == YogaFlow.S.STARTING:
			_start_tick(dt)
		ctx["role_changed"] = _borrowed and sc.role != "follow"
		ctx["paired"] = _paired()
		ctx["waiting"] = _waiting_join
		ctx["start_failed"] = _start_failed
		flow.step(dt, ctx)
	for e: Dictionary in flow.drain():
		var line := _do(e)
		if line != "":
			_toast(line)


func _unhandled_input(e: InputEvent) -> void:
	if not _waiting_join or not (e is InputEventKey) or not e.pressed or e.echo or e.physical_keycode != KEY_I:
		return
	if _pose == "puppy" and is_instance_valid(_pup_pair) and leader == "spouse":
		if _near_enough() and _pup_pair.take_partner(house.player):
			_waiting_join = false
			get_viewport().set_input_as_handled()


## Within the range the tandem poses join from.
func _near_enough() -> bool:
	var at: Vector3 = proxy.global_position if is_instance_valid(proxy) else (house.body.global_position if is_instance_valid(house.body) else Vector3.INF)
	return at != Vector3.INF and house.player.global_position.distance_to(at) <= JOIN_RANGE_M


func _update_hint() -> void:
	var show := _waiting_join and not _paired() and flow != null and flow.state == YogaFlow.S.STARTING
	if not show:
		if _hint_layer != null:
			_hint_layer.visible = false
		return
	if _hint_layer == null:
		_hint_layer = CanvasLayer.new()
		_hint_layer.layer = 6
		add_child(_hint_layer)
		_hint = Label.new()
		_hint.add_theme_font_size_override("font_size", 22)
		_hint.add_theme_color_override("font_color", Color(0.98, 0.9, 0.62))
		_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_hint.add_theme_constant_override("outline_size", 6)
		_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_hint.offset_top = -170.0
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_layer.add_child(_hint)
	_hint_layer.visible = true
	_hint.text = ("Press I to join %s" if _near_enough() else "Go to %s and press I to join") % house.sc.name


func _ctx() -> Dictionary:
	var sc := house.sc
	return {"minor": not AdultsOnly.is_adult(house, sc), "hour": sc.hour(), "busy": sc.busy(), "danger": _danger, "combat": _hurt_t > 0.0, "dist": _dist,
			"alive": not sc.core.is_dead() and not house.player.is_dead}


## Feeds the gauge from the world: meals the player eats near her, food put in the store, and the threats to keep away.
func _watch(dt: float, now: float) -> void:
	var sc := house.sc
	var near := _dist <= float(intim.cfg.near_m)
	var stomach := float(house.bridge.core.state.needs.get("stomach", 0.0))
	if stomach - _prev_stomach >= float(intim.cfg.meal_kcal) and near and sc.awake():
		intim.on_meal(now, now - _last_cook <= float(intim.cfg.cooked_recent_min))
	_prev_stomach = stomach
	_food_t -= dt
	if _food_t <= 0.0:
		_food_t = 0.5
		var n := 0
		for kind: String in sc.items:
			n += sc.stock.count(kind)
		if _prev_food >= 0 and n > _prev_food and not sc.busy():
			intim.on_gift(now)
		_prev_food = n
	var hp: float = house.player.health
	if _hp_prev >= 0.0 and hp < _hp_prev - 0.01:
		_hurt_t = float(intim.cfg.combat_s)
	_hp_prev = hp
	_hurt_t = maxf(_hurt_t - dt, 0.0)
	_danger_t -= dt
	if _danger_t <= 0.0:
		_danger_t = 1.0
		_danger = _threat_near()


## A live predator within danger_m of the player.
func _threat_near() -> bool:
	var p: Vector3 = house.player.global_position
	var lim := float(intim.cfg.danger_m)
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		if not n is Node3D or not n.has_method("is_prey") or not n.has_method("is_dead"):
			continue
		if not n.is_prey() and not n.is_dead() and (n as Node3D).global_position.distance_to(p) <= lim:
			return true
	return false


# ---------------------------------------------------------------- what the Talk tab asks
func talked() -> void:
	if intim != null and house.sc != null:
		intim.on_talk(house.sc.core.state.minutes)


## "" when yoga can be asked now, else why not (an Intimacy reason key).
func yoga_gate() -> String:
	if intim == null or flow == null:
		return "dead"
	if flow.active() or _finish_t > 0.0:
		return "active"
	return intim.gate(_ctx(), true)


## She is following for yoga and waiting to be asked for the pose.
func following() -> bool:
	return flow != null and flow.state == YogaFlow.S.FOLLOWING


## The player asks for the pose while she follows: the menu opens as she comes beside them.
func request_pose() -> void:
	if flow == null or not flow.request_pose():
		return
	for e: Dictionary in flow.drain():
		var line := _do(e)
		if line != "":
			_toast(line)


func ask() -> String:
	if intim == null or flow == null:
		return ""
	if flow.active() or _finish_t > 0.0:
		return house.pick(["intimacy", "ask", "active"])
	flow.ask(_ctx())
	var out := ""
	for e: Dictionary in flow.drain():
		var line := _do(e)
		if line != "":
			out = line
	return out


# ---------------------------------------------------------------- doing what the flow says
func _do(e: Dictionary) -> String:
	var sc := house.sc
	match String(e.do):
		"say":
			return house.pick(e.path)
		"offer":
			_prompt = YogaPrompt.offer(get_tree(), house.pick(["intimacy", "offer", intim.leader()]), sc.name)
			_prompt.answered.connect(func(yes: bool) -> void: flow.answer(yes))
		"follow":
			_borrow_follow()
		"choose":
			_prompt = YogaPrompt.poses(get_tree(), intim.cfg.poses, house.pick(["intimacy", "choose", intim.leader()]), sc.name)
			_prompt.chosen.connect(func(id: String) -> void: flow.choose(id))
			_prompt.cancelled.connect(func() -> void: flow.cancel())
		"start":
			_begin_pose(String(e.pose), String(e.leader))
		"end_follow":
			_end_follow()
		"session_done":
			if house.pregnancy != null:
				house.pregnancy.on_session()   # PREGNANCY: the roll after a finished session
	return ""


func _toast(line: String) -> void:
	var text := "%s: \"%s\"" % [house.sc.name, line]
	if house.player.hud != null:
		house.player.hud.toast(text)
	else:
		print(text)


## She follows for the yoga: her role is borrowed (and saved as it was), a job in hand is put down.
func _borrow_follow() -> void:
	var sc := house.sc
	if not _borrowed:
		_prev_role = sc.role
		_prev_focus = sc.focus
		sc.role_saved = sc.role
		_borrowed = true
	if sc.busy():
		sc.cancel("asked")
	sc.role = "follow"
	if house.body:
		house.body._plan = {}


func _end_follow() -> void:
	_stop_poses()
	if proxy != null and is_instance_valid(proxy):
		# let the partner's walk out of the pose finish before the stand-in goes
		_finish_t = 1.0
	else:
		_park_end()


## The stand-in goes, her own body takes over where it stood, and her role comes back (unless the player gave new orders).
func _park_end() -> void:
	_waiting_join = false
	var sc := house.sc
	if is_instance_valid(proxy):
		var at := proxy.global_position
		proxy.queue_free()
		if is_instance_valid(house.body):
			house.body.global_position = at + Vector3.UP * 0.1
	proxy = null
	lead = null
	if is_instance_valid(house.body):
		var b := house.body
		b.process_mode = Node.PROCESS_MODE_INHERIT
		b.visible = true
		b.collision_layer = 1
		b.velocity = Vector3.ZERO
		b._plan = {}
	if _borrowed:
		if sc.role == "follow":
			sc.role = _prev_role
			sc.focus = _prev_focus
		sc.role_saved = ""
		_borrowed = false


func _stop_poses() -> void:
	_waiting_join = false
	if is_instance_valid(_pup):
		_pup.stop()
	_pup = null
	_pup_pair = null
	_pose = ""
	if is_instance_valid(lead):
		lead.stop_pose()
	var pt := TandemProxy.controller_of(house.player)
	if pt != null and leader == "player" and not pt.mode.is_empty():
		pt.stop_pose()
	leader = ""


# ---------------------------------------------------------------- the pose
func _begin_pose(pose: String, who: String) -> void:
	leader = who
	_pose = pose
	_start_failed = false
	_try_t = 0.0
	var pt := TandemProxy.controller_of(house.player)
	if pt == null:
		_start_failed = true
		return
	if pose == "puppy":
		_begin_puppy(who, pt)
		return
	if who == "spouse":
		_swap_in()
		lead = TandemProxy.add_lead(proxy, pt)
		lead.set_meta(&"pose", pose)
	else:
		pt.set_meta(&"pose", pose)


## The puppy: the woman leads (the wife, through her stand-in, for a male player; the player herself otherwise) and the man kneels upright
## behind her (the player, or the husband's stand-in), taken in _start_tick.
func _begin_puppy(who: String, pt: Node) -> void:
	var woman: FrontierPlayer = house.player
	if who == "spouse":
		_swap_in()
		woman = proxy
		lead = TandemProxy.add_lead(proxy, pt)
	_pup = woman.get_node_or_null("PuppyPose")
	_pup_pair = woman.get_node_or_null("PuppyTandem")
	if _pup == null:
		_pup = load("res://features/tandem/puppy_pose.gd").new()
		_pup.player = woman
		woman.add_child(_pup)
		_pup_pair = load("res://features/tandem/puppy_tandem.gd").new()
		_pup_pair.player = woman
		_pup_pair.puppy = _pup
		woman.add_child(_pup_pair)


## The stand-in is built ahead of the pose, parked unseen and switched off, so asking for yoga does not build a whole body in the
## frame the pose begins (user 2026-10-01: "when we do a yoga pose it spawns in, not cool"). The Talk tab asks for it when it opens.
func prewarm() -> void:
	if is_instance_valid(proxy) or is_instance_valid(_pre) or house == null or house.sc == null or not is_instance_valid(house.body):
		return
	var b := house.body
	_pre = TandemProxy.make(house.player.get_parent(), house.sc.look, b.global_position, b.rotation.y)
	_pre_layer = _pre.collision_layer
	_pre_mask = _pre.collision_mask
	_pre_look = house.sc.look.hash()
	_pre.collision_layer = 0
	_pre.collision_mask = 0
	_pre.visible = false
	_pre.process_mode = Node.PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	if is_instance_valid(_pre):
		_pre.queue_free()


## The spouse's body is hidden and parked, a stand-in FrontierPlayer takes her place (see TandemProxy).
func _swap_in() -> void:
	if is_instance_valid(proxy):
		return
	var b := house.body
	if is_instance_valid(_pre):
		# the stand-in made ahead (prewarm): put where she stands, in her look, and switched on
		proxy = _pre
		_pre = null
		proxy.process_mode = Node.PROCESS_MODE_INHERIT
		proxy.collision_layer = _pre_layer
		proxy.collision_mask = _pre_mask
		proxy.global_position = b.global_position + Vector3.UP * 0.05
		proxy.rotation.y = b.rotation.y
		proxy.yaw = b.rotation.y
		if _pre_look != house.sc.look.hash():
			TandemProxy.dress(proxy, house.sc.look)
		proxy.visible = true
	else:
		proxy = TandemProxy.make(house.player.get_parent(), house.sc.look, b.global_position, b.rotation.y)
	b.visible = false
	b.collision_layer = 0
	b.process_mode = Node.PROCESS_MODE_DISABLED


## Every quarter second until the pair is in the pose: the lead starts it, the partner joins.
func _start_tick(dt: float) -> void:
	_try_t -= dt
	if _try_t > 0.0:
		return
	_try_t = 0.25
	var pt := TandemProxy.controller_of(house.player)
	if pt == null:
		_start_failed = true
		return
	if _pose == "puppy":
		if not is_instance_valid(_pup) or not is_instance_valid(_pup_pair):
			_start_failed = true
		elif not _pup.active:
			_pup.start()
		elif not _pup_pair.joined and not _pup_pair.inviting:
			if leader == "spouse":
				_waiting_join = true      # she kneels as the puppy and waits: the player presses I to kneel behind her
			else:
				_swap_in()
				_pup_pair.take_partner(proxy)
		return
	if leader == "spouse":
		if not is_instance_valid(lead):
			return
		if lead.mode.is_empty():
			lead.start_pose(String(lead.get_meta(&"pose", "yoga")))
		elif not lead.joined:
			_waiting_join = true          # she holds the pose; the player presses I beside her to join (TandemPoses)
	else:
		if pt.mode.is_empty():
			pt.start_pose(String(pt.get_meta(&"pose", "yoga")))
		elif not pt.joined:
			_swap_in()
			pt.take_partner(proxy)


func _paired() -> bool:
	if _pose == "puppy":
		return is_instance_valid(_pup) and _pup.active and is_instance_valid(_pup_pair) and _pup_pair.joined
	var pt := TandemProxy.controller_of(house.player)
	if leader == "spouse":
		return is_instance_valid(lead) and not lead.mode.is_empty() and lead.joined
	if leader == "player":
		return pt != null and not pt.mode.is_empty() and pt.joined
	return false
