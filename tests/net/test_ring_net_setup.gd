extends SceneTree
## The host's match settings online (NetMatch.setup_of / take_setup; docs/tidebreak/ring_netcode.md "The match"): a joiner
## whose own ring plays other rules loads the host's. Two processes, the joiner told to play the zones (rules=classic):
##   RING_NET_JOIN_ARGS=rules=classic zsh tools/net/ring_net_pair.sh <worktree> tests/net/test_ring_net_setup.gd
##   the joiner   its own ring the zones (classic); the host's roster comes with the host's settings: its ring loaded again
##                with them (stock: the % ring: RingNet.reloads), the host's puppet in it, its session the same
##   the host     the joiner in its match as ever (his puppet on its side 1); then it quits: the joiner's session closes, his
##                own player untouched, his match again with a bot
## Each prints "RING NET SETUP <role> PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

const LIMIT_S := 240.0

var checks := 0
var fails: Array[String] = []
var role := ""


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + "[%s] %s" % [role, what])
	if not ok:
		fails.append(what)


func _initialize() -> void:
	var want := RingNet.incoming_mode()
	role = "host" if String(want.get("role", "")) == "host" else "join"
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("RING NET SETUP %s FAILED (watchdog)" % role)
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


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _run() -> void:
	for i in 30:
		await process_frame
	var up := await _until(func() -> bool: return RingMode.find(self) != null and RingNet.find(self) != null, 60.0)
	var net := RingNet.find(self)
	_expect(up and net.role != RingNet.Role.OFF, "the ring and its session")
	if not up:
		return _end()
	if role == "join":
		# (its own ring the zones (rules=classic); the host's roster brings the host's settings: the ring loaded again, stock)
		var again := await _until(func() -> bool:
			var m := RingMode.find(self)
			return net.reloads >= 1 and m != null and m.rules != null and m.rules.rule_set == "stock", 60.0)
		var m := RingMode.find(self)
		_expect(again, "its own rules the zones: loaded again with the host's, the %% ring (%d time, now %s)" % [net.reloads,
				m.rules.rule_set if m != null and m.rules != null else "none"])
		var host_p := await _until(func() -> bool:
			var mm := RingMode.find(self)
			var p := net.body_of(1)
			return mm != null and p != null and mm.rules.team_of(p) == 1, 30.0)
		_expect(host_p and net.role == RingNet.Role.CLIENT, "the same session: the host's puppet on side 1 of the new ring")
		net.note("joined")
		await _until(func() -> bool: return false, 2.0)
		# (the host gone: the session closed, this machine's player still its own, the match again with a bot on side 1)
		await _until(func() -> bool: return net.role == RingNet.Role.OFF, 10.0)
		await _until(func() -> bool: return false, 1.0)
		var mm := RingMode.find(self)
		var whole := mm != null and is_instance_valid(mm.player) and mm.player.is_inside_tree()
		for t in 2:
			for bb: Variant in mm.rules.sides[t]:
				whole = whole and is_instance_valid(bb)
		_expect(net.role == RingNet.Role.OFF and whole and mm.foe != null and is_instance_valid(mm.foe),
				"the host gone: the session closed, the player still his own, a bot in the slot (the books whole)")
		_end()
		return
	else:
		var got := [false]
		net.noted.connect(func(_id: int, tag: String, _d: Variant) -> void:
			if tag == "joined":
				got[0] = true)
		var seen := await _until(func() -> bool:
			var m := RingMode.find(self)
			for id: int in net.roster:
				if id != net.my_id() and net.body_of(id) != null and m.rules.team_of(net.body_of(id)) == 1:
					return true
			return false, 120.0)
		_expect(seen, "the joiner in the host's match, side 1")
		var told := await _until(func() -> bool: return got[0], 60.0)
		_expect(told, "the joiner's ring loaded again and in the match (its word)")
		_end()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("RING NET SETUP %s PASSED (%d checks)" % [role, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING NET SETUP %s FAILED (%d of %d)" % [role, fails.size(), checks])
		quit(1)
