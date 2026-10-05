extends SceneTree
## The duel's foe is a bender (NpcBending; the user, 2026-10-04: "remove the guns in 1v1 its just spells", an Avatar-style
## game): no gun and no axe; at the player in the open it raises and throws stone spikes that strike him; struck, it raises
## an earth wall between them; the player near, a gust throws him off his feet.
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_duel_bender.gd -- mode=duel

var fails := 0


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


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
		return quit(1)
	await _secs(DuelMode.COUNTDOWN_S + 0.5)
	var n := duel.npc
	var b: NpcBending = n.brain.bending if n != null and n.brain != null else null
	_expect(n != null and b != null and n.gun == null and n.axe == null and n.weapon == "" and n.label == DuelMode.FOE_LABEL,
			"the foe is a bender: no gun, no axe (%s)" % (n.label if n else "-"))
	if b == null:
		return quit(1)
	# the player in the open 13 m off, in his sight
	var way := (p.global_position - n.global_position)
	way.y = 0.0
	way = way.normalized()
	var at := n.global_position + way * 13.0
	var keep_alive := func() -> void:
		if p.health < 40.0:
			p.health = p.max_health
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO
	var h0 := p.health
	var t := await _until(func() -> bool: return b.spikes >= 1, 8.0, keep_alive)
	_expect(t < 8.0, "it raises a stone spike and throws it at him (%.1f s)" % t)
	t = await _until(func() -> bool: return b.hits >= 1, 12.0, keep_alive)
	_expect(t < 12.0, "its spikes strike him (%d thrown, %d struck; health %.0f of %.0f)" % [b.spikes, b.hits, p.health, h0])
	# struck by the player: an earth wall
	var w0 := b.walls
	n.apply_hit(15.0, NpcSenses.chest_of(n), -way, p, "body")
	t = await _until(func() -> bool: return b.walls > w0, 6.0, keep_alive)
	_expect(t < 6.0 and b.last_wall != null, "struck, it raises an earth wall between them (%.1f s)" % t)
	# the player close: a gust
	var g0 := b.gusts
	var near := n.global_position + way * 3.0
	p.health = p.max_health
	t = await _until(func() -> bool: return b.gusts > g0, 8.0, func() -> void:
		var q := n.global_position + way * 3.0
		if p.global_position.distance_to(q) > 1.5 and b.gusts == g0:
			p.global_position = Vector3(q.x, FrontierTerrain.height_at(q.x, q.z) + 0.1, q.z)
		keep_alive.call())
	_expect(t < 8.0, "him near, a gust throws him back (%.1f s)" % t)
	print("DUEL BENDER " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)
