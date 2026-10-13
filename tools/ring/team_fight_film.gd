extends "res://tools/ring/gameplay_highlight.gd"
## Team fights on film (the owner, 2026-10-10: "lets run a trailer with the team fights see how it goes i want to watch it"): one
## real 2v2 or 4v4 match (MatchSetup's format: its deck, the Ruins pieces, every bot of both sides under its team coach), the
## player played by the film's expert input model (tools/ring/highlight_input.gd, as gameplay_highlight.gd does: ordinary
## key and mouse actions). Nothing of the match is changed for filming. The picture cuts between a wide shot of the whole deck,
## a broadcast camera on the thick of the fight, a low corner angle and the player's own view with its HUD; when anyone falls,
## the camera goes to the faller for the splash. One format a run (the deck is built for it); team_trailer_cut.py joins the
## takes. The frames, frames.txt and the movie writer's AVI (for the sound) as gameplay_highlight.gd writes them:
##   GODOT_TIMEOUT=1800 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 \
##     --write-movie <dir>/raw.avi -s tools/ring/team_fight_film.gd -- out=<dir> format=4v4 fps=60 size=1920x1080 \
##     quality=high upscale=off music=on character_look=soft [seconds=40] [lead=2.5] [light=noon] [element=fire]
##     [mates=earth,water,air] [foes=water,earth,air,fire] [seed=31] [captions=1] [stills=1] [public=on]
## public=on: for posting, only our own effects (SbFx off and the lightning's own shading, none rebuilt from Spellbreak).
## plan=follow,wide,low,...: the shots in turn (PLAN's names; "player" the player's own view): posting clips leave the player's
## view out, the camera always on the thick of it. A big launch (CHASE_MPS_HIGH or more) is noted in events.json as well as a
## fall (social_cut.py picks the busiest stretch by them). chase=off: a launch is never chased (the chase can end on the
## tank's bare wall); a fall still cuts to its splash. shots.json: each recorded frame's [seconds, shot, fighters in the picture]
## (social_cut.py --min-on leaves out stretches with too few in it).
## Ends with SHOWCASE DONE (the base's line).

## The shots in turn and how long each holds (s); a big launch cuts in to chase the flyer for FLIGHT_S, a fall to its splash
## for FALL_S, wherever the turn is.
const PLAN := ["wide", "player", "follow", "low", "player", "follow"]
const HOLD := {"wide": 4.5, "player": 6.0, "follow": 5.0, "low": 3.5}
const FALL_S := 2.6
const FLIGHT_S := 2.2
## A launch is chased when it may well end in the water: this fast (m/s), or this fast at this % or more; not again within
## CHASE_GAP_S of the last chase (a 4v4 launches someone every second or two: the picture would never settle).
const CHASE_MPS := 21.0
const CHASE_MPS_HIGH := 15.0
const CHASE_PCT := 80.0
const CHASE_GAP_S := 4.0
## A flyer moving more than this between frames was put back on its spout (the fall is told after that): its flight's last
## place is the splash.
const TELEPORT_M := 2.5
## How fast the script camera's aim and place follow the action (1/s).
const LOOK_K := 2.2
const MOVE_K := 1.6

var fmt := "4v4"
var _plan: Array = PLAN
var _chase := true
## Each recorded frame: [seg_t, shot, fighters in play whose chest is in the picture's frustum].
var _shots: Array = []
var _plan_i := 0
var _shot := ""
var _shot_t := 0.0
var _fall_at := Vector3.INF
var _fall_t := -INF
var _fly: Node3D
var _fly_t := -INF
var _fly_dir := Vector3.ZERO
var _fly_last := Vector3.INF
var _look := Vector3.INF
var _pos := Vector3.INF
var _corner := 1.0
## CanvasLayers this tool hid for a script-camera shot (shown again for the player's own).
var _hid: Array = []
var _seconds := 40.0


## (gameplay_highlight.gd sets a 1v1 match before the scene loads; the base calls this hook just before it does: the team match
## is set here, over it)
func _block_user_input() -> void:
	super._block_user_input()
	fmt = String(args.get("format", "4v4"))
	# (format=1v1 only when asked: a duel filmed by the same director, its cameras on the two of them)
	if not fmt in MatchSetup.FORMATS:
		fmt = "4v4"
	MatchSetup.set_match()
	MatchSetup.format = fmt
	MatchSetup.element = String(args.get("element", "fire" if fmt == "4v4" else "earth"))
	MatchSetup.foes = Array(String(args.get("foes", "water")).split(",", false))
	MatchSetup.mates = Array(String(args.get("mates", "")).split(",", false))
	MatchSetup.light = String(args.get("light", "noon"))
	_seconds = float(args.get("seconds", "40"))
	var pl := Array(String(args.get("plan", "")).split(",", false)).filter(func(x: String) -> bool: return x in HOLD)
	if not pl.is_empty():
		_plan = pl
	_chase = String(args.get("chase", "on")) != "off"
	if String(args.get("public", "off")) == "on":
		# (footage for posting: only our own effects, none rebuilt from Spellbreak's: SbFx off, the bolt's own shading)
		SbFx.force_on = false
		BendLooks.sb_bolt = false


func _order() -> Array:
	return ["team"]


func seg_team() -> void:
	recording = false
	cine_takes_over = false               # (the picture only: the game keeps aiming with the player's own camera)
	if is_instance_valid(sim):
		sim._let_go()
		sim.free()
	sim = InputPlayer.new()
	sim.setup(player, mode, "expert", int(args.get("seed", "31")))
	sim.camera_aim = true
	sim.m = sim.m.duplicate(true)
	level.add_child(sim)
	await _warm(int(float(args.get("lead", "2.5")) * fps))
	_shot_to(String(_plan[0]) if not "wide" in _plan else "wide")
	var deck := "%s x %s m" % [str(int(_num("deck_w", 28.0))), str(int(_num("deck_l", 52.0)))]
	await _roll("Tidebreak  ·  team fights", "%s  ·  the Ruins" % fmt.replace("v", " v "), deck, 0)
	while (seg_t < _seconds or seg_t - _fall_t < FALL_S) and seg_t < _seconds + FALL_S and mode.phase != "DONE":
		_direct()
		await _frame()
	recording = false
	print("TEAM FILM %s casts=%d clicks=%d falls=%s" % [fmt, sim.casts, sim.clicks, mode.falls])
	# (the board at the take's end, for the notes: each fighter's falls dealt and taken, self falls, the % dealt, its % now)
	var board: Array = []
	for e: Dictionary in mode.roster():
		var b: Variant = e.get("body")
		board.append({"name": e.name, "el": e.element, "team": e.team, "dealt": e.falls_dealt, "taken": e.falls_taken,
				"self": e.self_falls, "pct_dealt": e.pct_dealt,
				"pct_now": roundi(mode.rules.pct_of(b)) if b is Node and is_instance_valid(b) else -1})
	print("TEAM FILM BOARD ", JSON.stringify(board))
	FileAccess.open(out.path_join("board.json"), FileAccess.WRITE).store_string(JSON.stringify(board, "\t"))
	FileAccess.open(out.path_join("events.json"), FileAccess.WRITE).store_string(JSON.stringify(events, "\t"))
	FileAccess.open(out.path_join("shots.json"), FileAccess.WRITE).store_string(JSON.stringify(_shots))
	_write_log()


# --- the director ------------------------------------------------------------------------------------------------------

func _direct() -> void:
	if recording:
		var cam: Camera3D = cine if use_cine else player.camera
		var n := 0
		if cam != null:
			for b: Node3D in _in_play():
				if b.visible and cam.is_position_in_frustum(b.global_position + Vector3.UP):
					n += 1
		_shots.append([snappedf(seg_t, 0.001), _shot, n])
	# (the flyer's last place in its flight, before any jump back to a spout)
	if is_instance_valid(_fly):
		var p := _fly.global_position
		if _fly_last == Vector3.INF or p.distance_to(_fly_last) < TELEPORT_M:
			_fly_last = p
	if _fall_at != Vector3.INF and seg_t - _fall_t < FALL_S:
		if _shot != "fall":
			_shot_to("fall")
		return
	if is_instance_valid(_fly) and seg_t - _fly_t < FLIGHT_S:
		if _shot != "flight":
			_shot_to("flight")
		return
	if _shot in ["fall", "flight"] or seg_t - _shot_t >= float(HOLD.get(_shot, 4.0)):
		_plan_i = (_plan_i + 1) % _plan.size()
		_shot_to(String(_plan[_plan_i]))


func _shot_to(shot: String) -> void:
	_shot = shot
	_shot_t = seg_t
	if shot == "player":
		use_cine = false
		cam_fn = Callable()
		view.source = player.camera
		return
	if shot == "low":
		_corner = -_corner                 # (each low shot from the other corner)
	_pos = Vector3.INF
	_look = Vector3.INF
	cam_fn = _cam
	use_cine = true
	cine.current = cine_takes_over
	view.source = cine


## The script camera's pose this frame: [position, look-at, fov].
func _cam(dt: float) -> Array:
	var ring := mode.ring
	var c := ring.center() + Vector3.UP * 0.8
	var ax := ring.axis()
	var across := ax.cross(Vector3.UP).normalized()
	var w := _num("deck_w", 28.0)
	var l := _num("deck_l", 52.0)
	var want_look := c
	var want_pos := c
	var fov := 50.0
	# (a duel: the two kept in the picture, the camera further back the further apart they are)
	var back := 1.0 + (_spread() / 14.0 if fmt == "1v1" else 0.0)
	match _shot:
		"wide":
			want_look = c.lerp(_centroid(c), 0.6)
			want_pos = c + across * (w * 0.5 + l * 0.24) + Vector3.UP * (l * 0.24) - ax * (l * 0.06)
			fov = 50.0
		"follow":
			want_look = _busiest(c) + Vector3.UP * 0.4
			want_pos = want_look + (across * 12.5 + Vector3.UP * 6.0 - ax * 3.5) * back
			fov = 44.0
		"low":
			want_look = _busiest(c) + Vector3.UP * 0.9
			want_pos = want_look + (ax * 8.5 * _corner + across * 5.5) * back + Vector3.UP * 1.6
			fov = 50.0
		"flight":
			# (behind and above the flyer, a little to the side: its flight and where it lands ahead in the picture)
			var at := _fly_last if _fly_last != Vector3.INF else _look
			want_look = at + _fly_dir * 3.0
			want_pos = at - _fly_dir * 8.5 + Vector3.UP * 4.0 + across * 2.5
			fov = 52.0
		"fall":
			# (from over the deck, looking out and down at the splash: never from behind the tank's falling water)
			var out := Vector3(_fall_at.x - c.x, 0.0, _fall_at.z - c.z).normalized()
			want_look = _fall_at
			want_pos = _fall_at - out * 9.0 + Vector3.UP * 6.5 + across * 2.0
			fov = 50.0
	var lk := LOOK_K * (3.0 if _shot == "flight" else 1.0)
	var mk := MOVE_K * (2.5 if _shot == "flight" else 1.0)
	if _look == Vector3.INF:
		_look = want_look
		_pos = want_pos
	else:
		_look = _look.lerp(want_look, 1.0 - exp(-lk * dt))
		_pos = _pos.lerp(want_pos, 1.0 - exp(-mk * dt))
	return [_pos, _look, fov]


## Every fighter of both sides still in play.
func _in_play() -> Array:
	var out: Array = []
	if mode.rules == null:
		return out
	for t in 2:
		for b in mode.rules.sides[t]:
			if mode.in_play(b):
				out.append(b)
	return out


func _centroid(def: Vector3) -> Vector3:
	var fs := _in_play()
	if fs.is_empty():
		return def
	var s := Vector3.ZERO
	for b: Node3D in fs:
		s += b.global_position
	return s / fs.size()


## How far the fighters in play are from their middle at most (m).
func _spread() -> float:
	var mid := _centroid(Vector3.ZERO)
	var most := 0.0
	for b: Node3D in _in_play():
		most = maxf(most, Vector3(b.global_position.x - mid.x, 0.0, b.global_position.z - mid.z).length())
	return most


## Where the fight is thickest: the fighter with the most others within 8 m (their middle); a duel's, the two's middle.
func _busiest(def: Vector3) -> Vector3:
	var fs := _in_play()
	if fmt == "1v1":
		return _centroid(def)
	var best := def
	var best_n := -1
	for a: Node3D in fs:
		var s := Vector3.ZERO
		var n := 0
		for b: Node3D in fs:
			if a.global_position.distance_to(b.global_position) < 8.0:
				s += b.global_position
				n += 1
		if n > best_n:
			best_n = n
			best = s / maxi(n, 1)
	return best


func _num(key: String, def: float) -> float:
	return float(RingArena.data().get(key, def))


# --- the HUD: the player's own view keeps it; a script-camera shot is clean ---------------------------------------------

func _hide_hud() -> void:
	super._hide_hud()
	if use_cine:
		for n in root.find_children("*", "CanvasLayer", true, false):
			var cl := n as CanvasLayer
			# (only the game's HUD drawn into the film: never the window's mirror of the picture, which would leave the
			# window gray, nor the film's own captions)
			if cl == overlay or not cl.visible or view.is_ancestor_of(cl) or cl.custom_viewport != view:
				continue
			cl.visible = false
			_hid.append(cl)
	elif not _hid.is_empty():
		for cl in _hid:
			if is_instance_valid(cl):
				(cl as CanvasLayer).visible = true
		_hid.clear()


# --- events: a big launch is chased, a fall cuts to its splash (the base film ended its segment after a KO; not here) -------

func _film_launch(body: Node3D, velocity: Vector3, stun: float, by: Node, tag: String) -> void:
	super._film_launch(body, velocity, stun, by, tag)
	if not recording or not is_instance_valid(body):
		return
	var v := velocity.length()
	var who := "player" if body == player else RingMode.name_of(body)
	var last: Dictionary = events.back() if not events.is_empty() else {}
	if v >= CHASE_MPS_HIGH and not (String(last.get("who", "")) == who and absf(float(last.get("time", -9.0)) - seg_t) < 0.05):
		events.append({"kind": "launch", "time": seg_t, "v": v, "who": who, "move": tag})     # (once: a launch is told twice)
	if not _chase or seg_t - _fly_t < CHASE_GAP_S:
		return
	if v >= CHASE_MPS or (v >= CHASE_MPS_HIGH and mode.rules.pct_of(body) >= CHASE_PCT):
		_fly = body
		_fly_t = seg_t
		_fly_last = body.global_position
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		_fly_dir = flat.normalized() if flat.length() > 0.5 else Vector3.FORWARD


func _film_ko(body: Node3D, _by: Node, pct: float, tag: String, left: int) -> void:
	events.append({"kind": "ko", "time": seg_t if recording else -1.0, "who": "player" if body == player else RingMode.name_of(body),
		"pct": pct, "move": tag, "lives": left})
	print("TEAM FILM EVENT ", events.back())
	if recording and is_instance_valid(body):
		# (the fall is told once the faller stands on its spout again: the splash is where its chased flight last was)
		_fall_at = _fly_last if body == _fly and _fly_last != Vector3.INF and seg_t - _fly_t < 4.0 else body.global_position
		_fall_t = seg_t
