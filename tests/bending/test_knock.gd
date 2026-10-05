extends SceneTree
## One knockback model (BendKnock; Tidebreak, the ring sport: "knockback wins", docs/bending_design.md): the player and the
## duel's bender knocked by the same numbers, on a flat slab raised 200 m over the duel ground (not the arena's terrain and
## its cover), after the countdown (the FIGHT phase: no countdown hold on the player's pace).
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_knock.gd -- mode=duel
##
##   flat       an 8 m/s knock carries the player and the bot about 5.3 m (v^2 / 2 GROUND_DECEL, within 20%), within 15% of
##              each other; last_knocker is who knocked; a listener in bend_knock_listeners told once a knock
##   launch     (0, 11, 0) lifts both more than 1.5 m; is_launched() in the air, not after landing; `landed` once
##   anchor     an anchored one is not moved by a knock
##   ragdoll    a knock under BendKnock.ragdoll_mps never throws the player down (PlayerRagdoll.is_down() stays false)
##   hold       the duel's countdown hold (drag_speed_cap 0) is left alone by a root that ends inside it (the bend's own cap
##              is bend_speed_cap)
##   root       a rooted bot: held stays false, feet_held, no horizontal speed for the root's time, its brain still thinks
##              (NpcFighter.thinks), free after
##   winded     no_death: 999 of a blow (Hit.deliver), a bleed past the last of the health, a bot's wound pool: alive at 1
##              health, `winded` once each
## Last line "KNOCK TEST PASSED" or "KNOCK TEST FAILED"; exit 0 only on a pass.

const LIMIT_S := 240.0
const SLAB_Y := 200.0

var fails := 0
var p: FrontierPlayer
var n: NpcFighter
var duel: DuelMode
var mid := Vector3.ZERO
var heard: Array = []


class Listener extends Node:
	var got: Array = []

	func on_knocked(who: Node, v: Vector3, by: Node) -> void:
		got.append([who, v, by])


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(1750)
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("KNOCK TEST FAILED (watchdog)")
		quit(2))
	_go.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A 60 x 60 m slab of stone, its top at SLAB_Y, over the duel's ground.
func _slab(at: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = "KnockSlab"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	cs.shape = box
	sb.add_child(cs)
	current_scene.add_child(sb)
	sb.global_position = Vector3(at.x, SLAB_Y - 0.5, at.z)


## Both on the slab, still, whole; the bot held (its mind still) unless `think`.
func _stage(think := false) -> void:
	p.global_position = mid + Vector3(-10.0, 0.05, 0.0)
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	n.held = not think
	n.global_position = mid + Vector3(10.0, 0.05, 0.0)
	n.velocity = Vector3.ZERO
	n.health = n.health_max
	n.action = ""
	for b in [p, n]:
		var k := BendKnock.peek(b)
		if k != null:
			k.reset()
		if b.has_meta(&"bend_anchor"):
			b.remove_meta(&"bend_anchor")
	await _secs(0.6)


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	_expect(p != null and duel != null, "the duel and its player")
	if p == null or duel == null:
		return _end()
	p.ignore_mouse_capture = true
	await _secs(Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0)
	n = duel.npc
	_expect(n != null and duel.phase == DuelMode.Phase.FIGHT, "the fight on, the bender there (%s)" % DuelMode.PHASES[duel.phase])
	if n == null:
		return _end()
	mid = n.global_position
	mid.y = SLAB_Y
	_slab(mid)
	var l := Listener.new()
	l.add_to_group(BendKnock.LISTENERS)
	root.add_child(l)
	await _flat_knock(l)
	await _launch()
	await _anchor()
	await _no_ragdoll()
	await _hold()
	await _root()
	await _winded()
	_end()


func _end() -> void:
	print("KNOCK TEST " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- flat
func _flat_knock(l: Listener) -> void:
	await _stage()
	var p0 := p.global_position
	var n0 := n.global_position
	var heard0 := l.got.size()
	BendStatus.knock(p, Vector3(-8.0, 0.0, 0.0), n)
	BendStatus.knock(n, Vector3(8.0, 0.0, 0.0), p)
	var kp := BendKnock.peek(p)
	var kn := BendKnock.peek(n)
	_expect(kp != null and kn != null and kp.knock_t > 0.25 and kn.knock_t > 0.25 and n.knock_t() > 0.25,
			"knocked: each has its BendKnock and a reaction window (%.2f s, %.2f s)" % [kp.knock_t if kp else 0.0, kn.knock_t if kn else 0.0])
	await _secs(2.5)
	var dp := _flat(p.global_position, p0)
	var dn := _flat(n.global_position, n0)
	var want := 64.0 / (2.0 * BendKnock.GROUND_DECEL)
	_expect(absf(dp - want) <= want * 0.2 and absf(dn - want) <= want * 0.2,
			"8 m/s on flat stone: the player %.2f m, the bot %.2f m (about %.2f)" % [dp, dn, want])
	_expect(absf(dp - dn) <= maxf(dp, dn) * 0.15, "the same knock for both: within 15%% (%.2f against %.2f m)" % [dp, dn])
	_expect(p.global_position.y > SLAB_Y - 0.2 and n.global_position.y > SLAB_Y - 0.2, "both still on the slab")
	_expect(kp.last_knocker == n and kn.last_knocker == p, "last_knocker: the bot knocked the player and the player the bot")
	_expect(l.got.size() - heard0 == 2 and l.got[heard0][0] == p and l.got[heard0 + 1][0] == n and l.got[heard0][2] == n,
			"a listener in bend_knock_listeners told once a knock (%d)" % (l.got.size() - heard0))
	_expect(kp.kv == Vector3.ZERO and kn.kv == Vector3.ZERO and kp.knock_t == 0.0 and n.knock_t() == 0.0 and n.action == "",
			"spent: no knock left, the bot's hands its own again ('%s')" % n.action)


# ---------------------------------------------------------------- launch
func _launch() -> void:
	await _stage()
	var was := BendKnock.ragdoll_mps
	BendKnock.ragdoll_mps = 16.0              # (the ring's: an 11 m/s knock-up lifts, not a ragdoll)
	var lands := [0, 0]
	BendKnock.of(p).landed.connect(func() -> void: lands[0] += 1)
	BendKnock.of(n).landed.connect(func() -> void: lands[1] += 1)
	var y0 := [p.global_position.y, n.global_position.y]
	BendStatus.knock(p, Vector3(0.0, 11.0, 0.0), n)
	BendStatus.knock(n, Vector3(0.0, 11.0, 0.0), p)
	var top := [0.0, 0.0]
	var air_launched := [true, true]
	var t := 0.0
	while t < 4.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		top[0] = maxf(top[0], p.global_position.y - float(y0[0]))
		top[1] = maxf(top[1], n.global_position.y - float(y0[1]))
		if not p.is_on_floor() and top[0] > 0.5 and not BendKnock.of(p).is_launched():
			air_launched[0] = false
		if not n.is_on_floor() and top[1] > 0.5 and not BendKnock.of(n).is_launched():
			air_launched[1] = false
	BendKnock.ragdoll_mps = was
	_expect(top[0] > 1.5 and top[1] > 1.5, "(0, 11, 0) lifts both: the player %.2f m, the bot %.2f m" % [top[0], top[1]])
	_expect(air_launched[0] and air_launched[1], "launched all the way through the air")
	_expect(not p.is_launched() and not n.is_launched() and p.is_on_floor() and n.is_on_floor(), "down again: launched no more")
	_expect(lands[0] == 1 and lands[1] == 1, "landed once each (%d, %d)" % lands)
	_expect(not PlayerRagdoll.of(p).is_down() and not p.is_dead, "the player on his feet, alive")


# ---------------------------------------------------------------- anchor
func _anchor() -> void:
	await _stage()
	var p0 := p.global_position
	var n0 := n.global_position
	BendStatus.anchor(p, 2.0)
	BendStatus.anchor(n, 2.0)
	var k0 := BendKnock.of(p).knocks
	BendStatus.knock(p, Vector3(-8.0, 3.0, 0.0), n)
	BendStatus.knock(n, Vector3(8.0, 3.0, 0.0), p)
	await _secs(1.0)
	_expect(_flat(p.global_position, p0) < 0.1 and _flat(n.global_position, n0) < 0.1 and BendKnock.of(p).knocks == k0,
			"anchored: a knock moves neither (%.2f, %.2f m)" % [_flat(p.global_position, p0), _flat(n.global_position, n0)])


# ---------------------------------------------------------------- no ragdoll under the threshold
func _no_ragdoll() -> void:
	await _stage()
	var down := false
	BendStatus.knock(p, Vector3(-BendKnock.ragdoll_mps + 0.5, 0.0, 0.0), n)
	for i in int(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		down = down or PlayerRagdoll.of(p).is_down()
	_expect(not down, "a knock of %.1f m/s (under %.1f): pushed, never off his feet" % [BendKnock.ragdoll_mps - 0.5, BendKnock.ragdoll_mps])


# ---------------------------------------------------------------- the countdown's hold
func _hold() -> void:
	await _stage()
	p.drag_speed_cap = 0.0                   # (as DuelMode holds him through a countdown)
	BendStatus.root(p, 0.3)
	_expect(p.bend_speed_cap == 0.0 and p.drag_speed_cap == 0.0, "rooted: the bend's own cap at 0")
	await _secs(0.6)
	_expect(p.drag_speed_cap == 0.0 and p.bend_speed_cap == INF, "the root over inside the hold: the hold kept (%.1f), the bend's cap let go"
			% p.drag_speed_cap)
	p.drag_speed_cap = INF
	BendStatus.slow(p, 0.3)
	_expect(is_equal_approx(p.bend_speed_cap, BendStatus.SLOW_MPS) and p.drag_speed_cap == INF, "slowed: the bend's cap at the slow pace")
	await _secs(0.6)
	_expect(p.bend_speed_cap == INF, "the slow over: free")


# ---------------------------------------------------------------- root on the bot
func _root() -> void:
	await _stage(true)
	await _secs(0.5)
	var th0 := n.thinks
	var s := 1.5
	BendStatus.root(n, s)
	var fast := 0.0
	var held_ever := false
	var feet := true
	for i in int((s - 0.1) * Engine.physics_ticks_per_second):
		await physics_frame
		fast = maxf(fast, Vector2(n.velocity.x, n.velocity.z).length())
		held_ever = held_ever or n.held
		feet = feet and n.feet_held
	var thought := n.thinks - th0
	_expect(not held_ever and feet, "rooted: only the feet held (held %s, feet_held throughout %s)" % [held_ever, feet])
	_expect(fast < 0.05, "rooted: no horizontal speed (%.3f m/s at most)" % fast)
	_expect(thought >= 4, "rooted: the brain still thinks (%d thoughts in %.1f s)" % [thought, s - 0.1])
	await _secs(0.4)
	_expect(not n.feet_held and not n.held, "the root over: the feet free")


# ---------------------------------------------------------------- no death
func _winded() -> void:
	await _stage()
	var wp: Array = []
	var wn: Array = []
	p.winded.connect(func(by: Node) -> void: wp.append(by))
	n.winded.connect(func(by: Node) -> void: wn.append(by))
	p.no_death = true
	n.no_death = true
	n.set_meta(&"damage_kind", "blunt")
	Hit.deliver(p, 999.0, p.global_position + Vector3.UP, Vector3.LEFT, n)
	n.remove_meta(&"damage_kind")
	_expect(not p.is_dead and p.health >= 1.0 and wp.size() == 1 and wp[0] == n,
			"no_death: 999 on the player leaves him alive (%.0f health), winded once by the bot (%d)" % [p.health, wp.size()])
	p.lose_blood(999.0)
	_expect(not p.is_dead and p.health >= 1.0 and wp.size() == 2, "no_death: bled past the last of it, alive, winded (%d)" % wp.size())
	p.set_meta(&"damage_kind", "blunt")
	Hit.deliver(n, 999.0, NpcSenses.chest_of(n), Vector3.RIGHT, p)
	p.remove_meta(&"damage_kind")
	_expect(not n.is_dead() and n.health >= 1.0 and wn.size() == 1 and wn[0] == p,
			"no_death: 999 on the bot leaves it alive (%.0f health), winded once by the player (%d)" % [n.health, wn.size()])
	n.health = 5.0
	n.pool = 400.0
	await _secs(1.0)
	_expect(not n.is_dead() and n.health >= 0.5 and wn.size() == 2 and n.pool == 0.0,
			"no_death: its wounds' pool run past its health, alive, winded once (%d)" % wn.size())
	p.no_death = false
	n.no_death = false
	p.health = p.max_health
	n.health = n.health_max
