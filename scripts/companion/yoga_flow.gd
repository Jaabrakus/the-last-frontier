class_name YogaFlow
extends RefCounted
## The flow of a yoga together, logic only (user 2026-09-28): she (or he) offers when the intimacy gauge is full (nobody
## else began), or the player asks on the Talk tab; on yes she follows (a borrowed "follow" role that is not saved and is
## given back) for as long as it takes, until the PLAYER asks for the pose (request_pose: E on her, or the Talk tab); then
## the pose menu opens (the tandem feature's poses) once she is beside them; the pick starts the tandem pose (the woman
## leads, the man joins); the session's end drops the gauge. It works at any hour: only danger or a fight end it.
##   IDLE -> OFFERED -> (yes) FOLLOWING / (no) IDLE -> CHOOSING -> STARTING -> SESSION -> IDLE
## Asking on the Talk tab goes IDLE -> FOLLOWING and the menu opens as she arrives. Danger or a fight end the follow with a
## line; Esc in the pose menu ends it too. The node side (TandemLink) reads `events` each frame and does what they say:
##   {"do": "offer"}                  open the offer prompt
##   {"do": "follow"}                 borrow the follow role
##   {"do": "choose"}                 open the pose menu
##   {"do": "start", "pose": id, "leader": "player"|"spouse"}   start the tandem pose
##   {"do": "end_follow"}             give the role back (and the pose, if any, stands down)
##   {"do": "session_done"}          a session finished (the conception roll, PregnancyLink.on_session)
##   {"do": "say", "key": k}          a line from lines.json intimacy.<k> (path in "path")

enum S { IDLE, OFFERED, FOLLOWING, CHOOSING, STARTING, SESSION }

var intim: Intimacy
var state := S.IDLE
var events: Array = []
var pose := ""
var end_reason := ""
var _t := 0.0
var _check := 0.0
var _paired_seen := false
## The player has asked for the pose: the menu opens as soon as she is beside them.
var _want_menu := false


func _init(i: Intimacy) -> void:
	intim = i


func _say(path: Array) -> void:
	events.append({"do": "say", "path": ["intimacy"] + path})


func drain() -> Array:
	var e := events
	events = []
	return e


func active() -> bool:
	return state != S.IDLE


## Now and then, while idle: the offer, when it is due. ctx as Intimacy.gate.
func idle_step(dt: float, ctx: Dictionary) -> void:
	if state != S.IDLE:
		return
	_check -= dt
	if _check > 0.0:
		return
	_check = float(intim.cfg.offer_check_s)
	if intim.offer_ok(ctx):
		state = S.OFFERED
		events.append({"do": "offer"})


## The offer's answer (buttons). Yes: she follows. No: a polite line, the gauge stays, and no new offer for a while.
func answer(accept: bool) -> void:
	if state != S.OFFERED:
		return
	if accept:
		_begin_follow(false)
		_say(["ask", "accepted_" + intim.leader()])
	else:
		state = S.IDLE
		intim.on_declined()
		_say(["offer_declined"])


## Asked on the Talk tab. Returns the reason it cannot be ("" when it starts). She puts a job down if she must.
func ask(ctx: Dictionary) -> String:
	if state != S.IDLE and state != S.OFFERED:
		return "busy"
	var why := intim.gate(ctx, true)
	if why != "":
		_say(["ask", why])
		return why
	_begin_follow(true)
	_say(["ask", "accepted_" + intim.leader()])
	return ""


## The player asks for the pose while she follows (E on her, the Talk tab): the menu opens as soon as she is beside them.
func request_pose() -> bool:
	if state != S.FOLLOWING:
		return false
	_want_menu = true
	return true


func _begin_follow(menu: bool) -> void:
	_want_menu = menu
	state = S.FOLLOWING
	_t = 0.0
	pose = ""
	end_reason = ""
	_paired_seen = false
	events.append({"do": "follow"})


## While following / choosing / starting / in the session. ctx: hour, danger, combat, dist, role_changed (the player gave
## other orders), paired (the tandem pair is in the pose), start_failed (the pose cannot start here).
func step(dt: float, ctx: Dictionary) -> void:
	match state:
		S.FOLLOWING:
			_t += dt
			if bool(ctx.get("role_changed", false)):
				_end("", false)
				return
			var why := intim.calm_reason(ctx, true)
			if why in ["danger", "combat"]:
				_end(why, true)
			elif float(intim.cfg.follow_timeout_s) > 0.0 and _t > float(intim.cfg.follow_timeout_s):
				_end("far", true)
			elif _want_menu and float(ctx.get("dist", 1e9)) <= float(intim.cfg.come_m):
				state = S.CHOOSING
				events.append({"do": "choose"})
		S.CHOOSING:
			if bool(ctx.get("role_changed", false)):
				_end("", false)
			else:
				var why := intim.calm_reason(ctx, true)
				if why in ["danger", "combat"]:
					_end(why, true)
		S.STARTING:
			_t += dt
			if bool(ctx.get("waiting", false)):
				_t = 0.0      # (she is in her pose and waits for the partner to press the join key: no timeout)
			if bool(ctx.get("paired", false)):
				state = S.SESSION
				_paired_seen = true
			elif bool(ctx.get("start_failed", false)) or _t > float(intim.cfg.start_timeout_s):
				_end("blocked", true)
		S.SESSION:
			if not bool(ctx.get("paired", false)):
				# the pair stood up: the session is over
				intim.finish_session()
				state = S.IDLE
				events.append({"do": "end_follow"})
				events.append({"do": "session_done"})   # PREGNANCY: the conception roll (PregnancyLink)
				_say(["after"])


## A pose picked in the menu (one of the configured poses); false when it is not one.
func choose(pose_id: String) -> bool:
	if state != S.CHOOSING:
		return false
	for p: Dictionary in intim.cfg.poses:
		if String(p.id) == pose_id:
			pose = pose_id
			state = S.STARTING
			_t = 0.0
			events.append({"do": "start", "pose": pose_id, "leader": intim.leader()})
			return true
	return false


## Esc in the pose menu (or the player walking off, or any cancel): yoga mode ends, she goes back to her role.
func cancel() -> void:
	if state in [S.FOLLOWING, S.CHOOSING, S.STARTING, S.OFFERED]:
		var was_offer := state == S.OFFERED
		_end("cancelled" if not was_offer else "", not was_offer)
		if was_offer:
			intim.on_declined()


func _end(reason: String, with_line: bool) -> void:
	end_reason = reason
	var was_offer := state == S.OFFERED
	state = S.IDLE
	pose = ""
	if not was_offer:
		events.append({"do": "end_follow"})
	if with_line and reason != "":
		_say(["ended", reason])
