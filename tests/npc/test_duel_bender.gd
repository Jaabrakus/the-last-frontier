extends SceneTree
## The duel's foe is an element bot (NpcBending; the user, 2026-10-04: "remove the guns in 1v1 its just spells", the ring
## sport's bots casting the player's own moves): no gun and no axe, of the ring's other side (DuelMode.RING_FACTION), called by
## its element's competitor name (MatchSetup.competitor: no show word on the screen), of DuelMode.foe_element (earth unless
## foe= says), in its element's dress and with no words over its head; at the player in the open it casts its element's moves
## (several of them) and they strike him; struck, it loses the lock it was filling (any hurt, as the player's); the old
## forcing (_next["spike"]) still has it throw a stone spike first.
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_duel_bender.gd -- mode=duel [foe=water]
## Last line "DUEL BENDER PASSED" or "DUEL BENDER FAILED"; exit 0 only on a pass; the watchdog (LIMIT_S) fails it first.

const LIMIT_S := 200.0

var fails := 0


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("DUEL BENDER FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _end() -> void:
	print("DUEL BENDER " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _until(cond: Callable, limit: float, keep: Callable = Callable()) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		if keep.is_valid():
			keep.call()
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _go() -> void:
	for i in 20:
		await process_frame
	var p := current_scene.get_node_or_null("Player") as FrontierPlayer
	var duel := DuelMode.find(self)
	_expect(p != null and duel != null, "the duel")
	if duel == null:
		return _end()
	p.no_death = true
	await _secs(DuelMode.COUNTDOWN_S + 0.5)
	var n := duel.npc
	var b: NpcBending = n.brain.bending if n != null and n.brain != null else null
	var el := DuelMode.foe_element
	var name_ok := n != null and n.label == MatchSetup.competitor(el) and n.label != "" and not "bender" in n.label.to_lower()
	_expect(n != null and b != null and n.gun == null and n.axe == null and n.weapon == "" and name_ok,
			"the foe is an element bot: no gun, no axe, called %s (%s)" % [MatchSetup.competitor(el), n.label if n else "-"])
	if b == null:
		return _end()
	_expect(b.element == el and n.element == el and Bending.of(n).element == el and n.faction == DuelMode.RING_FACTION,
			"of %s, its own water meter, the ring's other side (%s, %s)" % [el, b.element, n.faction])
	var shirt: Dictionary = ((n.look.get("outfit", {}) as Dictionary).get("shirt", {}) as Dictionary).get("colors", {})
	_expect(String(shirt.get("0", "")).begins_with("#"), "dressed in its element's colours (%s)" % str(shirt))
	# the player in the open 11 m off, in its sight
	var way := (p.global_position - n.global_position)
	way.y = 0.0
	way = way.normalized()
	var at := n.global_position + way * 11.0
	var keep_alive := func() -> void:
		p.health = p.max_health
		duel.phase_t = minf(duel.phase_t, 10.0)
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO
	var t := await _until(func() -> bool: return b.distinct() >= 3 and b.hits >= 1, 25.0, keep_alive)
	print("  casts %d %s, hits %d" % [b.casts, str(b.casts_by), b.hits])
	_expect(t < 25.0, "it casts its element's moves at him, several of them, and they strike him (%d distinct, %d hits, %.1f s)" % [b.distinct(), b.hits, t])
	var labels := n.find_children("*", "Label3D", true, false)
	_expect(labels.is_empty() and n.last_bark == "", "no words over its head (%d Label3D, '%s')" % [labels.size(), n.last_bark])
	# struck in a lock: lost
	await _until(func() -> bool: return b.casting == "", 3.0, keep_alive)
	var l0 := b.lost
	b.begin("earth_wall", "column")
	await _secs(0.1)
	var locking := b.casting == "earth_wall"
	n.apply_hit(2.0, NpcSenses.chest_of(n), -way, p, "body")
	await _secs(0.05)
	_expect(locking and b.lost == l0 + 1 and b.casting == "" and b.lost_why == "hit", "struck in its lock, it loses the lock (%s, lost %d)" % [b.lost_why, b.lost])
	# the old forcing (an earth bot): a stone spike thrown first
	if el == "earth":
		var s0 := b.spikes
		b._next["spike"] = 0.0
		t = await _until(func() -> bool: return b.spikes > s0, 8.0, keep_alive)
		_expect(t < 8.0, "told to (_next spike), it raises a stone spike and throws it (%.1f s)" % t)
	_end()
