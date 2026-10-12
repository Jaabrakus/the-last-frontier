extends SceneTree
## The ring online, phase R1 d (NetMatch, docs/tidebreak/ring_netcode.md "The match"): two machines in one 1v1 % ring, the
## host the referee, two processes (tools/net/ring_net_pair.sh runs both and prints their results):
##   zsh tools/net/ring_net_pair.sh <worktree> tests/net/test_ring_net_match.gd
##   the fight     the joiner's fight begins at the host's word ("m_fight"), not its own countdown
##   the %         each machine's own % shown on the other (the host's books of the joiner's puppet, the joiner's of the
##                 host's: NetBody's pct slot)
##   a fall        the joiner drops into the water: his machine tells the host, the host takes the life on its books and
##                 tells both ("m_ko"): his lives one fewer on both machines, his body hidden and back on his spout
##   the match     two more falls: his side out of lives on the host's books, the round the host's (a win there, a loss on
##                 the joiner's machine, each in its own numbering), the match over on both ("m_end", "m_done")
## Each prints "RING NET MATCH <role> PASSED (<n> checks)" or "... FAILED (<f> of <n>)"; exit 0 only on a pass.

const LIMIT_S := 300.0

var checks := 0
var fails: Array[String] = []
var role := ""
var net: RingNet
var mode: RingMode
var player: FrontierPlayer
var got := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + "[%s] %s" % [role, what])
	if not ok:
		fails.append(what)


func _initialize() -> void:
	var want := RingNet.incoming_mode()
	role = "host" if String(want.get("role", "")) == "host" else "join"
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("RING NET MATCH %s FAILED (watchdog)" % role)
		quit(2))
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "air" if role == "host" else "fire"
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


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _other() -> int:
	if net == null:
		return 0
	for id: int in net.roster:
		if id != net.my_id():
			return id
	return 0


func _puppet() -> FrontierPlayer:
	return net.body_of(_other()) as FrontierPlayer if net != null and _other() != 0 else null


## The words applied here of `kind` (raw, newest last).
func _applied(kind: String) -> Array:
	var out: Array = []
	for w: Array in NetSpells.applied:
		if w.size() > 0 and String(w[0]) == kind:
			out.append(w)
	return out


func _run() -> void:
	for i in 30:
		await process_frame
	var up := await _until(func() -> bool: return RingMode.find(self) != null and RingNet.find(self) != null, 60.0)
	mode = RingMode.find(self)
	net = RingNet.find(self)
	_expect(up and net.role != RingNet.Role.OFF, "the ring and its session")
	if not up:
		return _end()
	net.noted.connect(func(_id: int, tag: String, d: Variant) -> void: got[tag] = d)
	player = mode.player
	player.ignore_mouse_capture = true
	var joined := await _until(func() -> bool: return net.roster.size() == 2 and _puppet() != null and net.clock.synced, 120.0)
	_expect(joined, "both in the match")
	if not joined:
		return _end()
	var fight := await _until(func() -> bool: return mode.phase == "FIGHT", 40.0)
	if role == "join":
		_expect(fight and not _applied("m_fight").is_empty(), "the fight begun at the host's word (%s)" % str(_applied("m_fight")))
	else:
		_expect(fight, "the fight begun (the host's own countdown)")
	var p := _puppet()
	var rules := mode.rules
	# ---- the %: each machine's own, shown on the other
	await _frames(30)
	var mine := 37.0 if role == "join" else 21.0
	var theirs := 21.0 if role == "join" else 37.0
	rules.add_pct(player, mine, null, "test")
	var shown := await _until(func() -> bool: return absf(rules.pct_of(p) - theirs) < 0.01, 5.0)
	_expect(shown, "the other's %% shown here: %.1f (his machine's %.1f)" % [rules.pct_of(p), theirs])
	net.note("pct_done")
	await _until(func() -> bool: return got.has("pct_done"), 15.0)
	# ---- the falls: the joiner's three, the match the host's
	var lives0 := rules.stocks_of(player if role == "join" else p)
	for k in lives0:
		if role == "join":
			await _until(func() -> bool: return not rules.is_away(player) and not rules.is_gone(player), 10.0)
			await _frames(20)
			var before := rules.stocks_of(player)
			var kos := _applied("m_ko").size()
			player.global_position = mode.ring.center() + Vector3.DOWN * 3.0      # (into the water under the deck)
			player.velocity = Vector3.ZERO
			var lost := await _until(func() -> bool: return rules.stocks_of(player) == before - 1, 5.0)
			_expect(lost and _applied("m_ko").size() > kos,
					"fall %d: a life gone at the host's word (%d -> %d)" % [k + 1, before, rules.stocks_of(player)])
			if rules.stocks_of(player) > 0:
				var hidden := not player.visible
				var back := await _until(func() -> bool: return player.visible and not rules.is_away(player), 8.0)
				var spout := mode.ring.spout_at(rules.end_of(player), 0)
				var near_spout := Vector2(player.global_position.x - spout.x, player.global_position.z - spout.z).length() < 6.0
				_expect(hidden and back and near_spout, "...hidden, then back on his spout (%s)" % str(player.global_position))
			net.note("fell_%d" % k)
		else:
			var before := rules.stocks_of(p)
			var lost := await _until(func() -> bool: return rules.stocks_of(p) == before - 1, 20.0)
			var fell := false
			for f: Dictionary in mode.falls:
				fell = fell or f.get("who") == p
			_expect(lost and fell, "the joiner's fall %d taken on the host's books (%d -> %d)" % [k + 1, before, rules.stocks_of(p)])
			await _until(func() -> bool: return got.has("fell_%d" % k), 15.0)
	# ---- the match: the host's win, the joiner's loss, over on both
	var over := await _until(func() -> bool: return mode.phase in ["OVER", "DONE"], 8.0)
	var want := "win" if role == "host" else "loss"
	_expect(over and mode.last_result == want and mode.last_why == "falls",
			"the round over: a %s here (%s, %s; score %s)" % [want, mode.last_result, mode.last_why, str(mode.score)])
	var done := await _until(func() -> bool: return mode.phase == "DONE", 10.0)
	var w := mode.winner
	_expect(done and w == (0 if role == "host" else 1), "the match over: won by %s (winner %d here)" % ["the host", w])
	if role == "join":
		_expect(not _applied("m_end").is_empty() and not _applied("m_done").is_empty(), "both the host's words")
	net.note("done")
	await _until(func() -> bool: return got.has("done"), 15.0)
	_end()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("RING NET MATCH %s PASSED (%d checks)" % [role, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING NET MATCH %s FAILED (%d of %d)" % [role, fails.size(), checks])
		quit(1)
