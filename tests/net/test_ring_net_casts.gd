extends SceneTree
## The ring online, phase R1 b (NetCasts, NetSpells; docs/tidebreak/ring_netcode.md "Casts", "Ghost mode", "Hits"): two
## machines in one 1v1 % ring, both water, two processes (tools/net/ring_net_pair.sh runs both and prints their results):
##   zsh tools/net/ring_net_pair.sh <worktree> tests/net/test_ring_net_casts.gd
##   the joiner's jab   its Splash cast on its own machine (recorded and sent; its bolt a ghost there, named
##                      "<peer>:<seq>:0"): the host runs it on the joiner's puppet (the bolt the same name), it hits the host's
##                      player (his % up, the hit by the puppet), and its end is the host's word to the joiner ("hit")
##   the lock           the joiner's lock played on the host's puppet of him (its SwayCaster locking, its pose's lock clip)
##   the host's jab     the host's Splash at the joiner's puppet: decided on the host, the hit sent to the joiner ("hit"), who
##                      takes it on his own body (his % up); the joiner ran the cast as a ghost, its bolt the same name
##   the Turn           the host's Turn (water's E) on the joiner's Splash, on the beat: on the host it swings round him and
##                      leaves along his aim; the joiner's ghost turned by the host's words (the swing begun round the host's
##                      puppet, then left), the return's hit sent to the joiner (".return"), the guard's result told on the
##                      joiner's machine ("perfect" on the host's puppet), the parried caster's slower next cast given the
##                      joiner (1.15)
## Each prints "RING NET CASTS <role> PASSED (<n> checks)" or "... FAILED (<f> of <n>)"; exit 0 only on a pass.

const LIMIT_S := 240.0
## The two apart for the jabs, and for the Turn (the Splash's 10 m reach; the Turn's beat wants a longer flight).
const APART_M := 6.0
const TURN_APART_M := 9.0

var checks := 0
var fails: Array[String] = []
var role := ""
var net: RingNet
var mode: RingMode
var player: FrontierPlayer
var c: SwayCaster
## The crosshair held on this one's chest every physics frame while set.
var aim_on: Node3D
## The other machine's notes: tag -> data.
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
		print("RING NET CASTS %s FAILED (watchdog)" % role)
		quit(2))
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "water"
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


## This machine's spot and the other's: on the ring's axis, `apart` m between them (the host's toward +axis).
func _spots(apart: float) -> Array:
	var a := mode.ring.center() + mode.ring.axis() * apart * 0.5
	var b := mode.ring.center() - mode.ring.axis() * apart * 0.5
	a.y = mode.ring.deck_y()
	b.y = mode.ring.deck_y()
	return [a, b] if role == "host" else [b, a]


## Both whole and still at their spots `apart` m apart, % 0, no hitstun; true once the other's puppet is at its spot too.
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


## Holds the left button (the quick spell, the jab) till its lock is full, then lets go: the cast.
func _jab() -> void:
	c.quick_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.quick_override = false
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
	c._quick["water"] = MatchSetup.jab_of("water")      # (the left button the jab, whatever a test run's settings file kept)
	var joined := await _until(func() -> bool: return net.roster.size() == 2 and _puppet() != null and net.clock.synced, 120.0)
	_expect(joined and BendCaster.of(_puppet()) is NetBendCaster, "both in the match, the other's puppet casting through a NetBendCaster")
	if not joined:
		return _end()
	var fight := await _until(func() -> bool: return mode.phase == "FIGHT", 40.0)
	_expect(fight, "the match in its fight (%s)" % mode.phase)
	await _joiners_jab()
	await _hosts_jab()
	await _turn()
	_end()


# ---------------------------------------------------------------- the joiner's jab
func _joiners_jab() -> void:
	var ok := await _settle(APART_M, "settled_1")
	_expect(ok, "both at their spots for the joiner's jab")
	var p := _puppet()
	if role == "join":
		aim_on = p
		await _frames(15)
		var n0 := NetCasts.sent.size()
		await _jab()
		var sent := await _until(func() -> bool: return NetCasts.sent.size() > n0, 3.0)
		var ev: Dictionary = NetCasts.sent.back() if sent else {}
		var bid := String(ev.get("id", "?")) + ":0"
		var ghost := NetSpells.find(bid)
		_expect(sent and String(ev.get("m", "")) == "water_jet" and not (ev.get("tape", {}) as Dictionary).is_empty(),
				"the Splash recorded and sent (%s, its tape: %s)" % [ev.get("m", "-"), str((ev.get("tape", {}) as Dictionary).keys())])
		_expect(ghost is BendBolt, "its bolt here a ghost named %s" % bid)
		var ended := await _until(func() -> bool: return _word_on("end", bid) != [], 4.0)
		var w := _word_on("end", bid)
		_expect(ended and String(w[2]) == "hit", "its end the host's word: %s" % str(w))
		aim_on = null
		net.note("j1_done", {"id": bid})
		await _until(func() -> bool: return got.has("h1_done"), 15.0)
	else:
		var r0 := NetCasts.ran.size()
		var ran := await _until(func() -> bool: return NetCasts.ran.size() > r0, 8.0)
		var ev: Dictionary = NetCasts.ran.back() if ran else {}
		var bid := String(ev.get("id", "?")) + ":0"
		var b := NetSpells.find(bid)
		_expect(ran and b is BendBolt and (b as BendBolt).caster == p, "the joiner's Splash run here on his puppet, its bolt named %s" % bid)
		# (the lock played on the puppet: seen before the cast's run, its pose's lock clip)
		var hit := await _until(func() -> bool: return RingRules.current().pct_of(player) > 0.0, 4.0)
		var by_him := false
		for h: Dictionary in BendR3.hits_log:
			by_him = by_him or (h.n == player and h.by == p)
		_expect(hit and by_him, "it hit the host's player: %.1f%%, the hit his puppet's" % RingRules.current().pct_of(player))
		_expect(_sent_word("end", bid) != [], "its end told the joiner (%s)" % str(_sent_word("end", bid)))
		_expect(_lock_seen, "the joiner's lock played on his puppet here (its SwayCaster locking, its pose: %s)" % _lock_clip)
		net.note("h1_done")
		await _until(func() -> bool: return got.has("j1_done"), 15.0)


var _lock_seen := false
var _lock_clip := ""


## The words this machine applied (the host's): the newest of `kind` about `id` ([] none).
func _word_on(kind: String, id: String) -> Array:
	for i in range(NetSpells.applied.size() - 1, -1, -1):
		var w: Array = NetSpells.applied[i]
		if w.size() > 1 and String(w[0]) == kind and str(w[1]) == id:
			return w
	return []


## The words the host sent: the newest of `kind` about `id` ([] none).
func _sent_word(kind: String, id: String) -> Array:
	for i in range(NetSpells.sent.size() - 1, -1, -1):
		var w: Array = NetSpells.sent[i]
		if w.size() > 1 and String(w[0]) == kind and str(w[1]) == id:
			return w
	return []


## The hits applied here of op `op` (newest last).
func _applied_ops(op: String) -> Array:
	var out: Array = []
	for w: Array in NetSpells.applied:
		if w.size() > 0 and String(w[0]) == op:
			out.append(w)
	return out


func _process(_dt: float) -> bool:
	# (the host watches the joiner's puppet lock: its SwayCaster's state and its pose's clip)
	if role == "host" and net != null and _puppet() != null and not _lock_seen:
		var sc := SwayCaster.of(_puppet())
		if sc != null and sc.state != SwayCaster.State.IDLE and sc.move == "water_jet":
			_lock_seen = true
			_lock_clip = String(sc.pose.current_clip()) if sc.pose != null else ""
	return false


# ---------------------------------------------------------------- the host's jab
func _hosts_jab() -> void:
	var ok := await _settle(APART_M, "settled_2")
	_expect(ok, "both at their spots for the host's jab")
	var p := _puppet()
	if role == "host":
		aim_on = p
		await _frames(15)
		var n0 := NetCasts.sent.size()
		await _jab()
		var sent := await _until(func() -> bool: return NetCasts.sent.size() > n0, 3.0)
		var ev: Dictionary = NetCasts.sent.back() if sent else {}
		var bid := String(ev.get("id", "?")) + ":0"
		_expect(sent and NetSpells.find(bid) is BendBolt, "the host's Splash cast and sent, its bolt named %s" % bid)
		var fwd := await _until(func() -> bool:
			for w: Array in NetSpells.sent:
				if String(w[0]) == "hit" and w[1] is Dictionary and int((w[1] as Dictionary).get("@b", 0)) == _other():
					return true
			return false, 4.0)
		_expect(fwd, "its hit on the joiner's puppet sent to the joiner")
		aim_on = null
		net.note("h2_done", {"id": bid})
		await _until(func() -> bool: return got.has("j2_done"), 15.0)
	else:
		var r0 := NetCasts.ran.size()
		var ran := await _until(func() -> bool: return NetCasts.ran.size() > r0, 8.0)
		var ev: Dictionary = NetCasts.ran.back() if ran else {}
		var bid := String(ev.get("id", "?")) + ":0"
		var b := NetSpells.find(bid)
		_expect(ran and b is BendBolt, "the host's Splash run here as a ghost, its bolt named %s" % bid)
		var hit := await _until(func() -> bool: return RingRules.current().pct_of(player) > 0.0, 4.0)
		_expect(hit and not _applied_ops("hit").is_empty(),
				"the host's word: the hit taken on the joiner's own body (%.1f%%)" % RingRules.current().pct_of(player))
		var ended := await _until(func() -> bool: return _word_on("end", bid) != [], 3.0)
		_expect(ended, "the ghost's end the host's word (%s)" % str(_word_on("end", bid)))
		net.note("j2_done")
		await _until(func() -> bool: return got.has("h2_done"), 15.0)


# ---------------------------------------------------------------- the Turn
func _turn() -> void:
	var ok := await _settle(TURN_APART_M, "settled_3")
	_expect(ok, "both at their spots %.0f m apart for the Turn" % TURN_APART_M)
	var p := _puppet()
	aim_on = p
	await _frames(15)
	if role == "join":
		var n0 := NetCasts.sent.size()
		var hits0 := _applied_ops("hit").size()
		await _until(func() -> bool: return got.has("turn_ready"), 10.0)
		await _jab()
		await _until(func() -> bool: return NetCasts.sent.size() > n0, 3.0)
		var ev: Dictionary = NetCasts.sent.back()
		var bid := String(ev.get("id", "?")) + ":0"
		var b := NetSpells.find(bid) as BendBolt
		# (the host's words on it: its swing begun round the host's puppet, then over)
		var swung := await _until(func() -> bool: return _bolt_words(bid, true) > 0 and _bolt_words(bid, false) > 0, 4.0)
		_expect(swung, "the host's words turned the ghost: its swing begun (%d) and left (%d)" % [_bolt_words(bid, true), _bolt_words(bid, false)])
		_expect(b != null and is_instance_valid(b) and b.caster == p or _turned_to(bid, p),
				"the turned bolt the host's now (his puppet's here)")
		var back := await _until(func() -> bool: return _applied_ops("hit").size() > hits0, 4.0)
		var h: Array = _applied_ops("hit").back() if back else []
		var tag := String((h[8] as Dictionary).get("tag", "")) if h.size() > 8 and h[8] is Dictionary else ""
		_expect(back and tag.ends_with(".return"), "the return's hit taken here (%s)" % tag)
		var lg: Variant = p.get_meta(&"bend_last_guard", {})
		_expect(lg is Dictionary and String((lg as Dictionary).get("result", "")) == "perfect",
				"the guard's result told here: %s on the host's puppet" % str(lg))
		var cm := BendStatus.cast_mult(player)
		_expect(is_equal_approx(cm, 1.15), "the parried caster's next cast slower: %.2f" % cm)
		net.note("j3_done")
		await _until(func() -> bool: return got.has("h3_done"), 15.0)
	else:
		c.lock_mult = 0.01                         # (the Turn up at once: its beat is the test, not its lock)
		var r0 := NetCasts.ran.size()
		net.note("turn_ready")
		var ran := await _until(func() -> bool: return NetCasts.ran.size() > r0, 8.0)
		var ev: Dictionary = NetCasts.ran.back() if ran else {}
		var bid := String(ev.get("id", "?")) + ":0"
		var b := NetSpells.find(bid) as BendBolt
		var near := await _until(func() -> bool:
			return b != null and is_instance_valid(b) and b.global_position.distance_to(NpcSenses.chest_of(player)) < 5.0, 3.0)
		c.guard_override = true
		var swung := await _until(func() -> bool: return b != null and is_instance_valid(b) and b.swinging(), 1.5)
		var res := String((player.get_meta(&"bend_last_guard", {}) as Dictionary).get("result", "")) if player.has_meta(&"bend_last_guard") else ""
		_expect(near and swung and res == "perfect", "the Turn on the beat: the joiner's Splash swings round the host (%s)" % res)
		var left := await _until(func() -> bool: return b != null and is_instance_valid(b) and not b.swinging() and b.caster == player, 2.0)
		_expect(left, "it left along the host's aim, his")
		c.guard_override = false
		c.lock_mult = 1.0
		net.note("h3_done")
		await _until(func() -> bool: return got.has("j3_done"), 15.0)
	aim_on = null


## The "bolt" words applied here on `id`: those with a swing begun (`swinging`), or with none.
func _bolt_words(id: String, swinging: bool) -> int:
	var n := 0
	for w: Array in NetSpells.applied:
		if w.size() > 2 and String(w[0]) == "bolt" and str(w[1]) == id and w[2] is Dictionary:
			var sw: Array = (w[2] as Dictionary).get("sw", [])
			if sw.is_empty() != swinging:
				n += 1
	return n


## Whether a "bolt" word applied here on `id` made it `who`'s.
func _turned_to(id: String, who: Node) -> bool:
	for w: Array in NetSpells.applied:
		if w.size() > 2 and String(w[0]) == "bolt" and str(w[1]) == id and w[2] is Dictionary:
			var by: Variant = (w[2] as Dictionary).get("by")
			if by is Dictionary and int((by as Dictionary).get("@b", 0)) == net.net_id_of(who):
				return true
	return false


func _end() -> void:
	if c != null:
		c.quick_override = null
		c.guard_override = null
		c.lock_mult = 1.0
	if fails.is_empty() and checks > 0:
		print("RING NET CASTS %s PASSED (%d checks)" % [role, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING NET CASTS %s FAILED (%d of %d)" % [role, fails.size(), checks])
		quit(1)
