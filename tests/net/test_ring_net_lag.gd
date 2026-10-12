extends SceneTree
## The ring online, phase R1 e (NetCasts.age_of, catch_up; docs/tidebreak/ring_netcode.md "Time"): a cast run on another
## machine is as old as the wire made it. Two processes, both water; the host stands in for a slow link (NetCasts.age_bias:
## every cast it runs 0.1 s older):
##   zsh tools/net/ring_net_pair.sh <worktree> tests/net/test_ring_net_lag.gd
##   the bolt    the joiner's Splash run on the host: its bolt flown on by its age at once (28 m/s: 2.8 m and more as the host
##               first sees it), where the joiner's own ghost of it already is
##   the guard   the joiner's Turn run on the host: its zone that much older (its beat measured from when he raised it)
## Each prints "RING NET LAG <role> PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

const LIMIT_S := 240.0
const BIAS_S := 0.1

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
		print("RING NET LAG %s FAILED (watchdog)" % role)
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
	_expect(up and net.role != RingNet.Role.OFF, "the ring and its session")
	if not up:
		return _end()
	net.noted.connect(func(_id: int, tag: String, d: Variant) -> void: got[tag] = d)
	player = mode.player
	player.ignore_mouse_capture = true
	c = SwayCaster.of(player)
	c._quick["water"] = MatchSetup.jab_of("water")
	var joined := await _until(func() -> bool: return net.roster.size() == 2 and _puppet() != null and net.clock.synced, 120.0)
	var fight := await _until(func() -> bool: return mode.phase == "FIGHT", 40.0)
	_expect(joined and fight, "both in the match, in its fight")
	if role == "host":
		NetCasts.age_bias = BIAS_S
	# ---- the bolt
	var sp := _spots()
	RingLevel.place(player, Transform3D(Basis.IDENTITY, sp[0]))
	await _frames(30)
	var p := _puppet()
	if role == "join":
		aim_on = p
		await _until(func() -> bool: return got.has("ready_bolt"), 15.0)
		c.quick_override = true
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
		c.quick_override = false
		await _until(func() -> bool: return got.has("bolt_done"), 15.0)
		aim_on = null
	else:
		var r0 := NetCasts.ran.size()
		net.note("ready_bolt")
		var ran := await _until(func() -> bool: return NetCasts.ran.size() > r0, 10.0)
		var ev: Dictionary = NetCasts.ran.back() if ran else {}
		var b := NetSpells.find(String(ev.get("id", "?")) + ":0") as BendBolt
		var tr := b.travelled if b != null and is_instance_valid(b) else -1.0
		# (polled a physics frame after its run at most: 0.47 m of its own; the catch-up's 2.8 m and more on top)
		_expect(ran and tr >= 28.0 * BIAS_S, "the joiner's Splash flown on by its age as the host first sees it (%.2f m)" % tr)
		net.note("bolt_done")
	# ---- the guard
	await _frames(30)
	if role == "join":
		await _until(func() -> bool: return got.has("ready_guard"), 15.0)
		c.guard_override = true
		await _until(func() -> bool: return c.guard_up(), 2.0)
		await _frames(5)
		c.guard_override = false
		await _until(func() -> bool: return got.has("guard_done"), 15.0)
	else:
		var r1 := NetCasts.ran.size()
		net.note("ready_guard")
		var ran2 := await _until(func() -> bool: return NetCasts.ran.size() > r1, 10.0)
		var z: Variant = null
		if ran2:
			z = NetSpells.find(String((NetCasts.ran.back() as Dictionary).get("id", "?")) + ":0")
		var zt := (z as BendZone).t if z is BendZone and is_instance_valid(z) else -1.0
		_expect(ran2 and zt >= BIAS_S, "the joiner's Turn run here that much older: its beat from when he raised it (t %.3f s)" % zt)
		net.note("guard_done")
	NetCasts.age_bias = 0.0
	net.note("done")
	await _until(func() -> bool: return got.has("done"), 15.0)
	_end()


## This machine's spot and the other's, 8 m apart on the ring's axis.
func _spots() -> Array:
	var a := mode.ring.center() + mode.ring.axis() * 4.0
	var b := mode.ring.center() - mode.ring.axis() * 4.0
	a.y = mode.ring.deck_y()
	b.y = mode.ring.deck_y()
	return [a, b] if role == "host" else [b, a]


func _end() -> void:
	NetCasts.age_bias = 0.0
	if c != null:
		c.quick_override = null
		c.guard_override = null
	if fails.is_empty() and checks > 0:
		print("RING NET LAG %s PASSED (%d checks)" % [role, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING NET LAG %s FAILED (%d of %d)" % [role, fails.size(), checks])
		quit(1)
