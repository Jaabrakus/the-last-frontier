extends SceneTree
## The walls' boosts (the owner, 2026-10-12: "a fire spell going thru a fire wall can boost other fire spells", "water wall
## bigger or faster", "stone wall if a boulder hits it ... tears off a piece of the wall and it continues", "ice lance can
## slice thru win walls"; picked: water freezes to faster ice, the Boulder tears a piece off; rules.json stock.wall_boost), in a
## 1v1 Lives ring, the player 10 m from a held bot, his crosshair on its chest, the casts the game's own:
##   fire     his Punch through his own Fire Wall: boosted (faster, bigger, its info wall_boost), its % over the plain Punch's
##            by about d; through the bot's Fire Wall: not
##   water    his Lash through his own Ice Wall: frozen to ice, faster, the wall passed unworn; where it ends a frost patch of his
##   earth    his Boulder into his own Earth Wall: a piece torn off (the wall a hit worn), the Boulder on through it, bigger,
##            striking the bot with info wall_boost
##   ice      his Ice Spear through the bot's Wind Wall: on through and striking it; his Lash into the same wall: blown aside
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_wall_boosts.gd
## The last line "WALL BOOSTS PASSED (<n> checks)" or "WALL BOOSTS FAILED (<f> of <n>)".

const LIMIT_S := 200.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var foe: NpcFighter
var rm: RingMode
var pc: BendCaster
var home := Vector3.ZERO
var way := Vector3(0, 0, 1)
var pitch_sign := 1.0
var aim_on: Node3D = null


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("WALL BOOSTS FAILED (watchdog)")
		quit(2))
	MatchSetup.set_match()
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "fire"
	MatchSetup.foes = ["air"]
	MatchSetup.round_s = 600.0
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if fails.is_empty() and checks > 0:
		print("WALL BOOSTS PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("WALL BOOSTS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _aim() -> void:
	if aim_on == null or not is_instance_valid(aim_on) or p == null or p.camera == null:
		return
	var d := (NpcSenses.chest_of(aim_on) - p.camera.global_position).normalized()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


## Both 10 m apart on the deck's middle, still, his crosshair on the bot; every zone and wall cleared, the % at 0.
func _face_off(el: String) -> void:
	for z in get_nodes_in_group(BendZone.GROUP):
		(z as BendZone).end("test")
	for w in get_nodes_in_group(FormRaised.GROUP):
		if is_instance_valid(w):
			(w as Node).queue_free()
	Bending.of(p).element = el
	foe.global_position = home + way * 5.0
	p.global_position = home - way * 5.0
	for b: CharacterBody3D in [p, foe]:
		b.velocity = Vector3.ZERO
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	aim_on = foe
	RingRules.current().reset_pct(foe, 0.0)
	await _ticks(12)


## His own cast of m/md (BendEffects.apply, as the game casts it); the bolt it sent (null none).
func _cast(m: String, md: String) -> BendBolt:
	var before := {}
	for n in get_nodes_in_group(BendBolt.GROUP):
		before[n.get_instance_id()] = true
	BendEffects.apply(pc, m, md, (SwayMoves.move(m).bend as Dictionary)[md])
	for n in get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b != null and b.caster == p and not before.has(b.get_instance_id()):
			return b
	return null


## A zone of `by`'s of `kind` standing 3 m out from the player toward the bot, facing along the line.
func _zone_between(by: Node3D, kind: String, m: String, md: String) -> BendZone:
	var at := FormEffects.ground_at(p, p.global_position + way * 3.0)
	return BendZone.make(by, kind, at, (SwayMoves.move(m).bend as Dictionary)[md], way)


## A bolt watched to its end: {boosted, kind, max_v, ended_at}.
func _watch(b: BendBolt) -> Dictionary:
	var out := {"boosted": false, "kind": "", "max_v": 0.0, "at": Vector3.INF}
	if b == null:
		return out
	var v0 := b.velocity.length()
	out["v0"] = v0
	while is_instance_valid(b) and not b.spent:
		out["boosted"] = b.wall_boosted
		out["kind"] = b.kind
		out["max_v"] = maxf(float(out.max_v), b.velocity.length())
		out["r"] = b.radius
		out["at"] = b.global_position
		await physics_frame
	return out


func _hits_on(who: Node, tag: String) -> Array:
	return BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == who and String(e.tag) == tag)


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	rm = RingMode.find(self)
	foe = rm.foe as NpcFighter if rm != null else null
	_expect(p != null and foe != null, "the ring, the player and the bot")
	if p == null or foe == null:
		return _end()
	p.ignore_mouse_capture = true
	pc = BendCaster.of(p)
	await _until(func() -> bool: return rm.phase == "FIGHT", 12.0)
	foe.held = true
	RingRules.current().stale_off = true
	await _secs(3.5)
	home = foe.global_position
	home.y = p.global_position.y
	p.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-p.camera.global_basis.z).y > 0.0 else -1.0
	physics_frame.connect(_aim)
	var wb := RingRules.stock_block("wall_boost")
	# ---- fire
	await _face_off("fire")
	var plain := await _watch(_cast("fire_blast", "punch"))
	await _secs(0.5)
	var pct_plain := RingRules.current().pct_of(foe)
	await _face_off("fire")
	_zone_between(p, "fire_wall", "fire_wall", "wall")
	await _ticks(5)
	var boosted := await _watch(_cast("fire_blast", "punch"))
	await _secs(0.5)
	var pct_boost := RingRules.current().pct_of(foe)
	_expect(not bool(plain.boosted) and bool(boosted.boosted) and float(boosted.max_v) > float(plain.max_v) * 1.15
			and float(boosted.get("r", 0.0)) > float(plain.get("r", 1.0)) * 1.3,
			"fire: his Punch through his own Fire Wall comes out faster (%.0f vs %.0f m/s) and bigger (%.2f vs %.2f m)"
			% [boosted.max_v, plain.max_v, boosted.get("r", 0.0), plain.get("r", 0.0)])
	_expect(pct_plain > 1.0 and pct_boost > pct_plain * (float(wb.get("d", 1.25)) - 0.08),
			"fire: and hits harder (+%.1f%% vs +%.1f%%)" % [pct_boost, pct_plain])
	await _face_off("fire")
	_zone_between(foe, "fire_wall", "fire_wall", "wall")
	await _ticks(5)
	var through_foe := await _watch(_cast("fire_blast", "punch"))
	_expect(not bool(through_foe.boosted), "fire: through the bot's Fire Wall, no boost")
	# ---- water
	await _face_off("water")
	var iw := BendEffects.ice_wall(pc, way, (SwayMoves.move("water_shield").bend as Dictionary).ice_wall)
	await _secs(1.0)
	var before_patches := 0
	for z in get_nodes_in_group(BendZone.GROUP):
		if (z as BendZone).kind == "ice_patch" and (z as BendZone).owner_node == p:
			before_patches += 1
	var lash := _cast("water_whip", "whip")
	var lv0 := lash.velocity.length() if lash != null else 0.0
	var lw := await _watch(lash)
	await _ticks(5)
	var patches := 0
	for z in get_nodes_in_group(BendZone.GROUP):
		if (z as BendZone).kind == "ice_patch" and (z as BendZone).owner_node == p and not z.is_queued_for_deletion():
			patches += 1
	var wall_ok := iw != null and is_instance_valid(iw) and iw.hits == 0
	var past := Vector3(lw.at).is_finite() and iw != null and is_instance_valid(iw) \
			and (Vector3(lw.at) - iw.global_position).dot(way) > 0.5
	_expect(bool(lw.boosted) and String(lw.kind) == "ice" and float(lw.max_v) > lv0 * 1.15 and wall_ok and past,
			"water: his Lash through his own Ice Wall freezes to ice (%s), faster (%.0f vs %.0f m/s), the wall passed unworn (%s, past %s)"
			% [lw.kind, lw.max_v, lv0, wall_ok, past])
	_expect(patches > before_patches, "water: a frost patch of his where it ended (%d)" % patches)
	# (the Ice Wall where his crosshair puts it, 6 m out: a step before the bot; the frozen Lash still strikes him)
	await _face_off("water")
	BendEffects.ice_wall(pc, way, (SwayMoves.move("water_shield").bend as Dictionary).ice_wall)
	await _secs(1.0)
	BendR3.hits_log.clear()
	await _watch(_cast("water_whip", "whip"))
	await _ticks(5)
	var frozen_hits := BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == foe and String((e.info as Dictionary).get("wall_boost", "")) == "ice")
	_expect(not frozen_hits.is_empty(), "water: the frozen Lash strikes the bot just past the wall (%d)" % frozen_hits.size())
	# ---- earth
	await _face_off("earth")
	var ew := FormEffects.earth_wall(pc, FormEffects.ground_at(p, p.global_position + way * 3.5), SwayMoves.move("earth_wall"), "earth")
	await _secs(1.2)
	BendR3.hits_log.clear()
	var sc := SwayCaster.of(p)
	sc.set_mode("stone_form", "cannonball")
	var th := FormEffects.raise_stone(p, "stone_form", "cannonball") as FormEffects.Throw
	var lift: GustLift = th.lift if th != null else null
	var r0 := lift.radius if lift != null else 0.0
	if th != null:
		th.waiting = false
	var torn := await _until(func() -> bool: return lift != null and is_instance_valid(lift) and lift.wall_boosted, 3.0)
	var r1 := lift.radius if lift != null and is_instance_valid(lift) else 0.0
	await _secs(1.2)
	var bh := BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == foe and String((e.info as Dictionary).get("wall_boost", "")) == "earth")
	_expect(torn and ew != null and is_instance_valid(ew) and ew.hits >= 1 and r1 > r0 * 1.3,
			"earth: his Boulder tears a piece off his own Earth Wall (worn %d) and flies on bigger (%.2f vs %.2f m)"
			% [ew.hits if ew != null and is_instance_valid(ew) else -1, r1, r0])
	_expect(not bh.is_empty(), "earth: and strikes the bot through it (%d hits with wall_boost)" % bh.size())
	# ---- ice through wind
	await _face_off("water")
	_zone_between(foe, "wind_wall", "air_wall", "wall")
	await _ticks(5)
	BendR3.hits_log.clear()
	var sp := _cast("ice", "spear")
	var sw := await _watch(sp)
	await _ticks(5)
	_expect(not _hits_on(foe, "ice/spear").is_empty(), "ice: his Ice Spear slices through the bot's Wind Wall and strikes it")
	await _face_off("water")
	_zone_between(foe, "wind_wall", "air_wall", "wall")
	await _ticks(5)
	BendR3.hits_log.clear()
	await _watch(_cast("water_whip", "whip"))
	await _ticks(5)
	_expect(_hits_on(foe, "water_whip/whip").is_empty(), "ice: his Lash into the same wall is blown aside (no hit)")
	_end()
