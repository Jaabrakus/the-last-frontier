extends SceneTree
## The ring online, stones (NetStones, docs/tidebreak/ring_netcode.md "Stones"): two machines in one 1v1 % ring, both earth,
## two processes (tools/net/ring_net_pair.sh runs both and prints their results):
##   zsh tools/net/ring_net_pair.sh <worktree> tests/net/test_ring_net_stones.gd
##   the Spike          the joiner's key 1 held: at its fill the stone rises before him (a "raise" run on every machine, the
##                      stone the same name everywhere), the release throws it (his cast, run on the host on his puppet): on
##                      the host it strikes the host's player (his % up) and bursts; its end the host's word to the joiner
##   the catch          the joiner's Spike again, the host's E up as it comes: caught, held before the host; the joiner's
##                      machine told (the stone's state: held by the host's puppet there)
##   the return         the host's E again throws the held stone back (his cast, run on the joiner's machine on the same
##                      stone): it strikes the joiner (the host's word, a ".return"), his % up
## Each prints "RING NET STONES <role> PASSED (<n> checks)" or "... FAILED (<f> of <n>)"; exit 0 only on a pass.

const LIMIT_S := 240.0
const APART_M := 8.0

var checks := 0
var fails: Array[String] = []
var role := ""
var net: RingNet
var mode: RingMode
var player: FrontierPlayer
var c: SwayCaster
var aim_on: Node3D
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
		print("RING NET STONES %s FAILED (watchdog)" % role)
		quit(2))
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 300.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	physics_frame.connect(_aim)
	_run.call_deferred()


func _aim() -> void:
	if aim_on == null or not is_instance_valid(aim_on) or player == null or player.camera == null:
		return
	var d := (NpcSenses.chest_of(aim_on) - player.camera.global_position).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0))


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


func _spots(apart: float) -> Array:
	var a := mode.ring.center() + mode.ring.axis() * apart * 0.5
	var b := mode.ring.center() - mode.ring.axis() * apart * 0.5
	a.y = mode.ring.deck_y()
	b.y = mode.ring.deck_y()
	return [a, b] if role == "host" else [b, a]


func _settle(apart: float, tag: String) -> bool:
	var sp := _spots(apart)
	var mine: Vector3 = sp[0]
	var theirs: Vector3 = sp[1]
	var place := func() -> void:
		RingLevel.place(player, Transform3D(Basis.IDENTITY, mine))
		player.velocity = Vector3.ZERO
		var kn := BendKnock.peek(player)
		if kn != null:
			kn.reset()
			kn.stun_t = 0.0
		RingRules.current().reset_pct(player, 0.0)
		for k: StringName in BendStatus.ROUND_METAS:
			if player.has_meta(k):
				player.remove_meta(k)
		c.drop_all()
	place.call()
	var p := _puppet()
	var there := await _until(func() -> bool:
		if player.global_position.distance_to(mine) > 0.4:
			place.call()
		return p != null and Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(theirs.x, theirs.z)) < 0.4, 15.0)
	await _frames(20)
	place.call()
	net.note(tag)
	var both := await _until(func() -> bool: return got.has(tag), 15.0)
	await _frames(10)
	return there and both


## Key 1 (the Spike) held on the aim till its lock is full, then let go: the throw.
func _spike() -> void:
	player.hotbar.select(0)
	await _frames(3)
	c.held_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	c.held_override = false
	await _frames(2)


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
	c = SwayCaster.of(player)
	var joined := await _until(func() -> bool: return net.roster.size() == 2 and _puppet() != null and net.clock.synced, 120.0)
	_expect(joined, "both in the match")
	if not joined:
		return _end()
	var fight := await _until(func() -> bool: return mode.phase == "FIGHT" and player.hotbar.spell != "", 40.0)
	_expect(fight, "the match in its fight, the bar laid (%s)" % mode.phase)
	await _spike_hit()
	await _catch_and_return()
	_end()


## The newest event of `kind` among `list` (NetCasts.sent / ran) after index `from` ({} none).
func _ev(list: Array, from: int, kind: String) -> Dictionary:
	for i in range(list.size() - 1, from - 1, -1):
		if i >= 0 and String((list[i] as Dictionary).get("kind", "cast")) == kind:
			return list[i]
	return {}


# ---------------------------------------------------------------- the Spike
func _spike_hit() -> void:
	var ok := await _settle(APART_M, "settled_1")
	_expect(ok, "both at their spots for the Spike")
	var p := _puppet()
	if role == "join":
		aim_on = p
		await _frames(15)
		var n0 := NetCasts.sent.size()
		await _spike()
		var raised := await _until(func() -> bool: return not _ev(NetCasts.sent, n0, "raise").is_empty(), 3.0)
		var rid := String(_ev(NetCasts.sent, n0, "raise").get("id", "?")) + ":0"
		_expect(raised and NetSpells.find(rid) is FormStone, "the Spike's stone raised at the fill, recorded and sent, named %s" % rid)
		var cast := await _until(func() -> bool: return not _ev(NetCasts.sent, n0, "cast").is_empty(), 3.0)
		_expect(cast, "the throw cast and sent")
		var ended := await _until(func() -> bool: return _word_on("end", rid) != [], 5.0)
		_expect(ended, "the stone's end the host's word (%s)" % str(_word_on("end", rid)))
		aim_on = null
		net.note("j1_done")
		await _until(func() -> bool: return got.has("h1_done"), 15.0)
	else:
		var r0 := NetCasts.ran.size()
		var raised := await _until(func() -> bool: return not _ev(NetCasts.ran, r0, "raise").is_empty(), 8.0)
		var rid := String(_ev(NetCasts.ran, r0, "raise").get("id", "?")) + ":0"
		var s := NetSpells.find(rid)
		_expect(raised and s is FormStone and int(s.get_meta(&"bend_raised_by", 0)) == p.get_instance_id(),
				"the joiner's raise run here: his stone up before his puppet, named %s" % rid)
		var hit := await _until(func() -> bool: return RingRules.current().pct_of(player) > 0.0, 6.0)
		_expect(hit, "his Spike struck the host's player: %.1f%%" % RingRules.current().pct_of(player))
		var gone := await _until(func() -> bool: return _sent_word("end", rid) != [], 3.0)
		_expect(gone, "its burst told the joiner")
		net.note("h1_done")
		await _until(func() -> bool: return got.has("j1_done"), 15.0)


# ---------------------------------------------------------------- the catch and the return
func _catch_and_return() -> void:
	var ok := await _settle(APART_M, "settled_2")
	_expect(ok, "both at their spots for the catch")
	var p := _puppet()
	aim_on = p
	await _frames(15)
	if role == "join":
		var n0 := NetCasts.sent.size()
		var hits0 := _applied_ops("hit").size()
		await _until(func() -> bool: return got.has("catch_ready"), 10.0)
		await _spike()
		await _until(func() -> bool: return not _ev(NetCasts.sent, n0, "raise").is_empty(), 3.0)
		var rid := String(_ev(NetCasts.sent, n0, "raise").get("id", "?")) + ":0"
		var held := await _until(func() -> bool:
			var s := NetSpells.find(rid)
			return s != null and int(s.get_meta(&"bend_held_by", 0)) == p.get_instance_id(), 6.0)
		_expect(held, "told: the host caught it, held before his puppet here")
		var back := await _until(func() -> bool: return _applied_ops("hit").size() > hits0, 8.0)
		var h: Array = _applied_ops("hit").back() if back else []
		var tag := String((h[8] as Dictionary).get("tag", "")) if h.size() > 8 and h[8] is Dictionary else ""
		_expect(back and tag.ends_with(".return") and RingRules.current().pct_of(player) > 0.0,
				"the host's return struck the joiner (%s, %.1f%%)" % [tag, RingRules.current().pct_of(player)])
		net.note("j2_done")
		await _until(func() -> bool: return got.has("h2_done"), 15.0)
	else:
		var r0 := NetCasts.ran.size()
		var pct0 := RingRules.current().pct_of(player)
		net.note("catch_ready")
		# (E up as his stone rises: the catch's whole window, window_s from its standing, ahead of his throw)
		var raised := await _until(func() -> bool: return not _ev(NetCasts.ran, r0, "raise").is_empty(), 8.0)
		var t_e := BendStatus.now()
		c.guard_override = true
		var stood := await _until(func() -> bool: return c.guard_up(), 1.0)
		var t_up := BendStatus.now()
		var caught := await _until(func() -> bool: return BendZone.held_stone(player) != null or RingRules.current().pct_of(player) > pct0, 4.0)
		var t_c := BendStatus.now()
		c.guard_override = false
		var st := BendZone.held_stone(player)
		var lg: Variant = player.get_meta(&"bend_last_guard", {})
		print("  [host] catch: E at raise, up %s %.2f s after, caught %s %.2f s after it stood, last guard %s, %% %.1f" % [stood,
				t_up - t_e, st != null, t_c - t_up, str(lg), RingRules.current().pct_of(player)])
		_expect(raised and caught and st != null and NetSpells.id_of(st) != "", "the host caught the joiner's Spike: held (%s)" % NetSpells.id_of(st))
		await _until(func() -> bool: return not c.guard_up(), 3.0)
		await _frames(10)
		c.guard_override = true                       # (E again: the stone thrown back along his aim)
		var thrown := await _until(func() -> bool: return BendZone.held_stone(player) == null, 3.0)
		c.guard_override = false
		var fwd := await _until(func() -> bool:
			for w: Array in NetSpells.sent:
				if String(w[0]) == "hit" and w[1] is Dictionary and int((w[1] as Dictionary).get("@b", 0)) == _other():
					return true
			return false, 6.0)
		_expect(thrown and fwd, "E again threw it back: it struck the joiner's puppet, the hit sent to him")
		net.note("h2_done")
		await _until(func() -> bool: return got.has("j2_done"), 15.0)
	aim_on = null


func _word_on(kind: String, id: String) -> Array:
	for i in range(NetSpells.applied.size() - 1, -1, -1):
		var w: Array = NetSpells.applied[i]
		if w.size() > 1 and String(w[0]) == kind and str(w[1]) == id:
			return w
	return []


func _sent_word(kind: String, id: String) -> Array:
	for i in range(NetSpells.sent.size() - 1, -1, -1):
		var w: Array = NetSpells.sent[i]
		if w.size() > 1 and String(w[0]) == kind and str(w[1]) == id:
			return w
	return []


func _applied_ops(op: String) -> Array:
	var out: Array = []
	for w: Array in NetSpells.applied:
		if w.size() > 0 and String(w[0]) == op:
			out.append(w)
	return out


func _end() -> void:
	if c != null:
		c.held_override = null
		c.guard_override = null
	if fails.is_empty() and checks > 0:
		print("RING NET STONES %s PASSED (%d checks)" % [role, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING NET STONES %s FAILED (%d of %d)" % [role, fails.size(), checks])
		quit(1)
