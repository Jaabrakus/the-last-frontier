extends SceneTree
## The owner's flows (Tidebreak: "knockback wins"; docs/bending_design.md, How moves meet: Earth catches stone and pushes it
## back), every cast through the shared path (BendCast.cast: the player's PlayerBendCaster, the bot's BodyBendCaster), on a
## flat slab of earth 200 m over the duel's ground, the duel's earthbender held still (his mind off) before the player:
##   catch-back  the bot throws a stone at the player, a spike (Stone Form: a GustLift) and then a disc (a stone BendBolt);
##               the player casts Catch (catch), it takes the stone and holds it, and within 1.5 s of the Catch he casts Earth
##               Shove (push): the stone flies back, strikes the bot, and BendKnock moves him at least 1.5 m, its last_knocker
##               the player
##   kick-shove  the player kicks a rock up (Rock Jab kick_up) and shoves it (Earth Shove push) at the held bot: it strikes
##               him, knocked by the player
##   trap-drop   the player traps the bot's feet (Earth Grip trap: feet_held) and casts a boulder (Stone Form cannonball): it
##               lands on him while his feet are held
## Last line "FLOW PASSED" or "FLOW FAILED"; exit 0 only on a pass. User args: seed=<n> (1750).
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_flow.gd -- mode=duel

const WATCHDOG_S := 240.0
const SLAB_Y := 200.0
const GAP_M := 9.0

var fails := 0
var p: FrontierPlayer
var c: SwayCaster
var duel: DuelMode
var n: NpcFighter
var bc: BodyBendCaster
var mid := Vector3.ZERO
var opts := {"seed": 1750}


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			opts.seed = int(a.substr(5))
	seed(int(opts.seed))
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("FLOW FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _now() -> float:
	return BendStatus.now()


func _slab() -> void:
	var sb := StaticBody3D.new()
	sb.name = "FlowSlab"
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta(&"form_matter", "earth")
	sb.set_meta(&"surface", "stone")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	cs.shape = box
	sb.add_child(cs)
	current_scene.add_child(sb)
	sb.global_position = Vector3(mid.x, SLAB_Y - 0.5, mid.z)


func _clear() -> void:
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()


## The player GAP_M before the bot (the player at -x facing +x), both still, whole, unknocked and free; the bot held.
func _stage() -> void:
	_clear()
	await physics_frame
	p.global_position = mid + Vector3(-GAP_M, 0.05, 0.0)
	p.velocity = Vector3.ZERO
	p.yaw = -PI / 2.0
	p.rotation.y = p.yaw
	p.pitch = 0.0
	p.health = p.max_health
	n.held = true
	n.global_position = mid + Vector3(0.0, 0.05, 0.0)
	n.velocity = Vector3.ZERO
	n.rotation.y = PI / 2.0
	n.health = n.health_max
	n.action = ""
	n.arm_broken = ""
	n.limp = 1.0
	n.pool = 0.0
	n.mortal_left = 0.0
	n.feet_held = false
	for b: Node in [p, n]:
		var k := BendKnock.peek(b)
		if k != null:
			k.reset()
			k.last_knocker = null
		for m: StringName in [&"bend_anchor", &"bend_root", &"bend_slow"]:
			if b.has_meta(m):
				b.remove_meta(m)
	Bending.of(p).water = 100.0
	await _secs(0.5)


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	c = SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null, "the duel, its player and his caster")
	if c == null:
		return _end()
	p.ignore_mouse_capture = true
	await _secs(Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0)
	n = duel.npc
	_expect(n != null and is_instance_valid(n), "the bot")
	if n == null:
		return _end()
	n.held = true
	# (the duel's watch off: no round ends and no reset of the two meanwhile; neither killed, only winded)
	duel.set_physics_process(false)
	p.no_death = true
	n.no_death = true
	BendKnock.ragdoll_mps = 50.0
	mid = n.global_position
	mid.y = SLAB_Y
	_slab()
	bc = BodyBendCaster.new(n, p, 0.0, 0.0)
	bc.bind()
	_expect(BendCaster.wrap(c) is PlayerBendCaster and BendCaster.of(n) == bc, "the player's caster and the bot's (the shared path)")
	await _catch_back("spike")
	await _catch_back("disc")
	await _kick_shove()
	await _trap_drop()
	_end()


func _end() -> void:
	print("FLOW " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)


## The stone the player holds (a Catch's), null none.
func _held() -> FormStone:
	for st in get_nodes_in_group(FormStone.GROUP):
		if int((st as Node).get_meta(&"bend_held_by", -1)) == p.get_instance_id():
			return st as FormStone
	return null


## The bot knocked by the player after a cast: [moved (flat m, the most within `s`), last_knocker].
func _knocked_back(n0: Vector3, s: float) -> Array:
	var most := 0.0
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame
		most = maxf(most, _flat(n.global_position, n0))
	var k := BendKnock.peek(n)
	return [most, k.last_knocker if k != null else null]


# ---------------------------------------------------------------- the stone caught and sent back
func _catch_back(mode: String) -> void:
	await _stage()
	var t0 := _now()
	c.set_mode("stone_catch", "catch")
	var caught := BendCast.cast(c, "stone_catch", "catch")
	var g: BendZone = BendEffects.last.get("zone")
	_expect(caught and g != null and g.kind == "catch", "%s: the player's Catch stands (%s)" % [mode, str(BendEffects.last.get("zone_kind", "-"))])
	var lifts0 := get_nodes_in_group(GustLift.GROUP)
	var bolts0 := get_nodes_in_group(BendBolt.GROUP)
	var thrown := BendCast.cast(bc, "stone_form", mode)
	var kind_ok := false
	if mode == "spike":
		for l in get_nodes_in_group(GustLift.GROUP):
			kind_ok = kind_ok or (not lifts0.has(l) and (l as GustLift).caster == bc)
	else:
		for b in get_nodes_in_group(BendBolt.GROUP):
			kind_ok = kind_ok or (not bolts0.has(b) and (b as BendBolt).caster == n and (b as BendBolt).kind == "stone")
	_expect(thrown and kind_ok, "%s: the bot throws it at the player (%s)" % [mode, "a GustLift" if mode == "spike" else "a stone BendBolt"])
	var held: FormStone = null
	while _now() - t0 < 1.2 and held == null:
		await physics_frame
		p.health = p.max_health
		held = _held()
	_expect(held != null, "%s: the Catch takes it and holds it (%.2f s)" % [mode, _now() - t0])
	if held == null:
		return
	await _secs(0.1)
	var n0 := n.global_position
	c.set_mode("earth_shove", "push")
	var shoved := BendCast.cast(c, "earth_shove", "push")
	var dt := _now() - t0
	var target: Variant = BendEffects.last.get("target")
	_expect(shoved and target == held and dt <= 1.5, "%s: Earth Shove (push) takes the held stone %.2f s after the Catch" % [mode, dt])
	var th0 := BendEffects.last.get("throw") as FormEffects.Throw
	var hits: Array = []
	if th0 != null:
		th0.lift.struck.connect(func(who: Node, _d: float) -> void: hits.append(who))
	var st0 := held.global_position
	var r := await _knocked_back(n0, 2.0)
	# (on a miss, where it went: the throw, its aim and the stone, for the flaky earth-vs-earth catch-back)
	var why := ""
	if float(r[0]) < 1.5:
		var live := is_instance_valid(th0)
		why = "; throw %s (live %s) thrown %s target %s, stone %s -> %s, bot at %s, lift %s" % [th0 != null, live,
				th0.is_thrown if live else false, th0.target if live else Vector3.INF, st0,
				held.global_position if is_instance_valid(held) else Vector3.INF, n0,
				(th0.lift.velocity if live and is_instance_valid(th0.lift) else Vector3.INF)]
	_expect(float(r[0]) >= 1.5 and r[1] == p, "%s: the stone flies back and knocks the bot %.2f m, by the player (%s; struck %s%s)" % [mode, r[0], str(r[1]), str(hits), why])


# ---------------------------------------------------------------- kick-up, then shove
func _kick_shove() -> void:
	await _stage()
	c.set_mode("rock_jab", "kick_up")
	var kicked := BendCast.cast(c, "rock_jab", "kick_up")
	var st := BendEffects.last.get("stone") as FormStone
	_expect(kicked and st != null, "kick-up: a rock up before the player")
	await _secs(0.35)
	var n0 := n.global_position
	var h0 := n.health
	c.set_mode("earth_shove", "push")
	var shoved := BendCast.cast(c, "earth_shove", "push")
	var th := BendEffects.last.get("throw") as FormEffects.Throw
	_expect(shoved and BendEffects.last.get("target") == st and th != null, "kick-up: Earth Shove (push) throws that rock")
	var struck: Array = []
	if th != null:
		th.lift.struck.connect(func(who: Node, _d: float) -> void: struck.append(who))
	var r := await _knocked_back(n0, 2.0)
	_expect(struck.has(n) and r[1] == p and float(r[0]) >= 1.0, "kick-up: it strikes the held bot (%s; his health %.0f to %.0f), knocked %.2f m by the player"
			% [str(struck.has(n)), h0, n.health, r[0]])


# ---------------------------------------------------------------- trap, then a boulder
func _trap_drop() -> void:
	await _stage()
	c.set_mode("earth_grip", "trap")
	var trapped := BendCast.cast(c, "earth_grip", "trap")
	_expect(trapped and n.feet_held and int(BendEffects.last.get("hit", 0)) >= 1, "trap: the bot's feet held (%s)" % str(n.feet_held))
	var ths0 := get_nodes_in_group(FormEffects.Throw.GROUP)
	c.set_mode("stone_form", "cannonball")
	var boulder := BendCast.cast(c, "stone_form", "cannonball")
	var th: FormEffects.Throw = null
	for x in get_nodes_in_group(FormEffects.Throw.GROUP):
		if not ths0.has(x):
			th = x as FormEffects.Throw
	_expect(boulder and th != null and th.caster is PlayerBendCaster and th.stone.kind == "cannonball", "trap: the boulder thrown by the player")
	if th == null:
		return
	var on_held: Array = []
	th.lift.struck.connect(func(who: Node, _d: float) -> void: on_held.append([who, n.feet_held]))
	await _secs(1.5)
	var hit_held := false
	for e in on_held:
		hit_held = hit_held or (e[0] == n and bool(e[1]))
	_expect(hit_held, "trap: the boulder lands on the bot while his feet are held (%s)" % str(on_held))
