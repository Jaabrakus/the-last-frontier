extends "res://tools/ring/move_reel.gd"
## Water's Rise as a Stream filmed for the owner (2026-10-12: "it should be like the fire but with water the user uses the aim
## to move like a dragon", "it auto turns and then we steer"; RingMoves kind "stream"): the player off the deck's end 2.5 m out
## and a metre under the lip, his double jump spent, the Rise pressed: aimed at the deck (up and over), aimed along the edge
## and the mouse swung to the deck in its travel (it curves after the aim), and aimed away with the mouse still a moment (the
## recovery turn brings the camera round, the Stream with it) and then steered. The move reel's captions, a wide side camera:
##   GODOT_TIMEOUT=1800 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 --write-movie <dir>/raw.avi \
##     -s tools/ring/water_rise_reel.gd -- out=<dir> fps=60 size=1280x720 quality=high upscale=off music=off character_look=soft
## Cut as the move reel is: python3 tools/ring/move_reel_cut.py <dir> <out>.

const SIDE := 8.0

var _wide := false


func _order() -> Array:
	return ["water"]


func _shots_of(_el: String) -> Array:
	return [
		{"kind": "wr", "key": 0, "id": "rise", "mode": "", "how": "deck", "label": "Water Rise  ·  aimed at the deck", "detail": "Space off the deck: a stream carries you along your aim"},
		{"kind": "wr", "key": 0, "id": "rise", "mode": "", "how": "steer", "label": "Water Rise  ·  steered", "detail": "aimed along the edge, then the mouse swings to the deck: it curves after it"},
		{"kind": "wr", "key": 0, "id": "rise", "mode": "", "how": "auto", "label": "Water Rise  ·  auto-turn, then steer", "detail": "aimed away: the camera turns toward the deck by itself, then the mouse takes it"},
	]


func _cam(dt: float) -> Array:
	if not _wide:
		return super._cam(dt)
	var ax := mode.ring.axis()
	var across := ax.cross(Vector3.UP).normalized()
	return [_cam_mid + across * SIDE + Vector3.UP * 1.0 - ax * 1.5, _cam_mid, CAM_FOV + 14.0]


func _do(sh: Dictionary) -> void:
	if String(sh.kind) != "wr":
		await super._do(sh)
		return
	var ring := mode.ring
	var ax := ring.axis()
	var rm := RingMoves.of(player)
	var lip := ring.center() + ax * ring.half_l()
	var at := lip + ax * 2.5 + Vector3.DOWN * 1.0
	var to_deck := atan2(ax.x, ax.z)                 # (the yaw facing -ax: toward the deck)
	var away := to_deck + PI
	var how := String(sh.how)
	_wide = true
	_cam_mid = lip + ax * 1.2 + Vector3.UP * 1.0
	player.global_position = at
	player.velocity = Vector3(0.0, -1.0, 0.0)
	player.yaw = {"deck": to_deck, "steer": to_deck + PI * 0.5, "auto": to_deck + PI * 0.75}.get(how, away)
	player.pitch = 0.0
	player.rotation.y = player.yaw
	await _frame()
	await physics_frame
	# (the airtime's double jump spent in the tick Space goes down: the ticks after the placement hand one back, as he
	# leaves the deck); Space as a player presses it: down at a physics tick (PlayerControls.just_pressed is that tick's)
	rm._air = true
	rm.jumps_left = 0
	rm._dj_at = -INF
	rm.rise_ready = true
	rm._turn_off = false
	rm._turning = false
	_ctl.set_held(&"jump", true)
	await physics_frame
	await physics_frame
	_ctl.set_held(&"jump", false)
	var n := int(2.6 * fps)
	for i in n:
		var steer_at := {"steer": 0.15, "auto": 0.45}.get(how, INF) as float
		if rm.mode == "rise" and rm.mode_t > steer_at:
			# (the mouse swung toward the deck, a quarter turn in 0.3 s; "auto": the recovery turn's own first, mouse still)
			player.yaw = move_toward(player.yaw, to_deck, PI * 0.5 / 0.3 / fps)
			rm.note_mouse()
		await _frame()
	print("MOVE REEL WATER RISE %s: on the deck %s, mode '%s'" % [how, ring.on_deck(player.global_position), rm.mode])
	_wide = false
