extends SceneTree
## The ring online, phase R1 a (RingNet, docs/tidebreak/ring_netcode.md): two machines in one 1v1 % ring, two processes here
## (tools/net/ring_net_pair.sh runs both and prints their results):
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_ring_net_pair.gd -- ring_net=host name=Host
##   Godot --headless --fixed-fps 60 --path . -s tests/net/test_ring_net_pair.gd -- ring_net=join:127.0.0.1 name=Joiner
##   join      the joiner reaches the host, the roster gives it the host's side 1 slot 0; each machine has one puppet, the
##             other's fighter: a FrontierPlayer not of this machine (no camera current), its RingMoves a puppet, on the
##             rules' books on side 1 (each machine numbers its own side 0), no bot made for its slot; the two at opposite ends
##   clock     the joiner's clock synced with the host's (a round trip under 0.25 s: two headless rings' frames here)
##   follow    each puts its own fighter on a spot of its own on the deck; the other machine's puppet of it gets there
##   jump      the joiner jumps in the fight (its third press the in-ring Rise): the host's puppet of it goes up, airborne,
##             its pose playing its owner's Rise clip (SwayPose's ring layer from the puppet's clip state)
##   leave     the joiner leaves: the host's puppet goes and its match is made again with a bot in the slot
## Each prints "RING NET PAIR <role> PASSED (<n> checks)" or "RING NET PAIR <role> FAILED (<f> of <n>)"; exit 0 only on a pass.

const LIMIT_S := 240.0

var checks := 0
var fails: Array[String] = []
var role := ""
var net: RingNet
var mode: RingMode
var player: FrontierPlayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + "[%s] %s" % [role, what])
	if not ok:
		fails.append(what)


func _initialize() -> void:
	var want := RingNet.incoming_mode()
	role = "host" if String(want.get("role", "")) == "host" else "join"
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("RING NET PAIR %s FAILED (watchdog)" % role)
		quit(2))
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth" if role == "host" else "water"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 300.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


## Waits up to `s` real seconds for `cond` (a headless run's frames go faster than the clock).
func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## The other machine's peer id (0 none yet).
func _other() -> int:
	if net == null:
		return 0
	for id: int in net.roster:
		if id != net.my_id():
			return id
	return 0


func _puppet() -> FrontierPlayer:
	return net.body_of(_other()) as FrontierPlayer if net != null and _other() != 0 else null


func _run() -> void:
	for i in 30:
		await process_frame
	var up := await _until(func() -> bool: return RingMode.find(self) != null and RingNet.find(self) != null, 60.0)
	mode = RingMode.find(self)
	net = RingNet.find(self)
	_expect(up and net.role != RingNet.Role.OFF, "the ring and its session (%s)" % (net.status if net != null else "none"))
	if not up:
		return _end()
	player = mode.player
	player.ignore_mouse_capture = true
	# ---- join
	var joined := await _until(func() -> bool:
		var p := _puppet()
		return net.roster.size() == 2 and p != null and mode.rules.team_of(p) == 1, 120.0)
	var p := _puppet()
	_expect(joined, "both in the roster, the other's puppet on this machine's side 1 (%s)" % str(net.roster.keys()))
	if not joined:
		return _end()
	var e: Dictionary = net.roster[net.my_id()]
	_expect(int(e.team) == (0 if role == "host" else 1) and int(e.slot) == 0, "this machine's slot in the host's numbering: side %d slot %d" % [e.team, e.slot])
	_expect(not p.is_local and (p.camera == null or not p.camera.current) and RingMoves.of(p) != null and RingMoves.of(p).puppet,
			"the puppet is not this machine's: no view, its RingMoves a puppet")
	_expect(mode.foe == null and mode.bots().is_empty(), "no bot made for the slot a human holds")
	_expect(mode.rules.end_of(player) != mode.rules.end_of(p), "the two at opposite ends (%d, %d)" % [mode.rules.end_of(player), mode.rules.end_of(p)])
	# ---- clock
	if role == "join":
		var synced := await _until(func() -> bool: return net.clock.synced, 10.0)
		# (two headless rings on one machine: a message waits for the other's frame to be read, so the round trip is the two
		# frames', not the wire's; a live game's frames are 16 ms)
		_expect(synced and net.clock.rtt < 0.25, "the joiner's clock synced with the host's (round trip %.1f ms)" % (net.clock.rtt * 1000.0))
	# ---- follow: each on a spot of its own, the other's puppet of it there
	await _frames(60)
	var side := Vector3.UP.cross(mode.ring.axis()).normalized()
	var spot_host := mode.ring.center() + mode.ring.axis() * 3.0 + side * 2.0
	var spot_join := mode.ring.center() - mode.ring.axis() * 3.0 - side * 2.0
	spot_host.y = mode.ring.deck_y()
	spot_join.y = mode.ring.deck_y()
	var mine := spot_host if role == "host" else spot_join
	var theirs := spot_join if role == "host" else spot_host
	var placed := func() -> bool:
		RingLevel.place(player, Transform3D(Basis.IDENTITY, mine))
		return true
	placed.call()
	var there := await _until(func() -> bool:
		if player.global_position.distance_to(mine) > 0.5:
			placed.call()                     # (a round's start puts him back at his spawn: here again)
		return Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(theirs.x, theirs.z)) < 0.3, 20.0)
	_expect(there, "the other's puppet came to its owner's spot (%s, wanted %s)" % [str(p.global_position), str(theirs)])
	# ---- jump: the joiner jumps in the fight, the host's puppet of it goes up
	var fight := await _until(func() -> bool: return mode.phase == "FIGHT", 30.0)
	_expect(fight, "the match on this machine in its fight (%s)" % mode.phase)
	if role == "join":
		for k in 8:
			Input.action_press(&"jump")
			await _frames(2)
			Input.action_release(&"jump")
			await _frames(60)
		net.note("jumped")
	else:
		var deck := mode.ring.deck_y()
		var top := 0.0
		var air := false
		var rise_clip := ""
		var t_end := Time.get_ticks_msec() + 30000
		var done := [false]
		net.noted.connect(func(_id: int, tag: String, _d: Variant) -> void:
			if tag == "jumped":
				done[0] = true)
		while Time.get_ticks_msec() < t_end and not done[0]:
			top = maxf(top, p.global_position.y - deck)
			var prm := RingMoves.of(p)
			air = air or prm.airborne()
			var sp := SwayCaster.of(p).pose if SwayCaster.of(p) != null else null
			if rise_clip == "" and sp != null and String(sp.ring_clip()).contains("rise"):
				rise_clip = String(sp.ring_clip())
			await physics_frame
		_expect(top > 1.0 and air, "the joiner's jumps: the host's puppet of it went %.2f m up, airborne as its owner" % top)
		_expect(rise_clip != "", "...its pose playing its owner's Rise (%s)" % rise_clip)
	# ---- leave
	if role == "join":
		await _frames(60)
		net.leave()
		_expect(net.role == RingNet.Role.OFF and net.body_of(_other()) == null, "the joiner left: no session, no puppet")
	else:
		var gone := await _until(func() -> bool: return net.roster.size() == 1 and mode.foe != null, 30.0)
		_expect(gone, "the joiner left: its puppet gone, a bot in its slot again")
	_end()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("RING NET PAIR %s PASSED (%d checks)" % [role, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING NET PAIR %s FAILED (%d of %d)" % [role, fails.size(), checks])
		quit(1)
