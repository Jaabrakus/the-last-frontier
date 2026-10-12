extends SceneTree
## The tracking meters (SwayCaster._tracks; the owner, 2026-10-12: "geiser wind prison and column should be tracking meters",
## picked: rumble, then erupt where they stood at the release), in a 1v1 Lives ring, the player 9 m from a held bot, the aim
## held (SwayCaster.held_override) with the crosshair set each frame on the bot or 4 m beside him:
##   the Column   off the bot the meter fills nothing (the ring flickering: track_off); on him it fills; full, the crosshair
##                turned away and let go at once: it erupts under him (earth_shove/column on him); the same with him stepping
##                3 m aside during its rumble: it misses (the dodge); half full and off him past the grace: the meter drains back
##   the Geyser   full on him, let go looking away: it erupts under him (wave/spout)
##   the Prison   the Wind Prison worn (air.wall.prison), the bot hanging in the air: tracked and let go, the wall rises round
##                him and holds him (BendStatus.floating)
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_tracking.gd
## The last line "TRACKING PASSED (<n> checks)" or "TRACKING FAILED (<f> of <n>)".

const LIMIT_S := 200.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var foe: NpcFighter
var rm: RingMode
var c: SwayCaster
var home := Vector3.ZERO
var way := Vector3(0, 0, 1)
var pitch_sign := 1.0
var look_off := false               ## the crosshair 4 m beside the bot instead of on him


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("TRACKING FAILED (watchdog)")
		quit(2))
	MatchSetup.set_match()
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 600.0
	MatchSetup.set_controls("full")
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if c != null:
		c.held_override = null
	if p != null:
		BendLoadout.clear(p)
	if fails.is_empty() and checks > 0:
		print("TRACKING PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("TRACKING FAILED (%d of %d)" % [fails.size(), checks])
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
	if foe == null or not is_instance_valid(foe) or p == null or p.camera == null:
		return
	var at := NpcSenses.chest_of(foe) + (way.cross(Vector3.UP).normalized() * 4.0 if look_off else Vector3.ZERO)
	var d := (at - p.camera.global_position).normalized()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


func _stage(el: String) -> void:
	c.held_override = false
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 3.0)
	for z in get_nodes_in_group(BendZone.GROUP):
		(z as BendZone).end("test")
	Bending.of(p).element = el
	BendStatus.unfloat(foe, true)
	foe.global_position = home + way * 4.5
	p.global_position = home - way * 4.5
	for b: CharacterBody3D in [p, foe]:
		b.velocity = Vector3.ZERO
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	RingRules.current().reset_pct(foe, 20.0)
	look_off = false
	await _ticks(20)


## The aim held until the lock is full (on the bot); false when it never filled.
func _fill_on_him(limit := 3.0) -> bool:
	look_off = false
	c.held_override = true
	return await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit)


func _hits_on_foe(tag: String) -> Array:
	return BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == foe and String(e.tag) == tag)


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
	c = SwayCaster.of(p)
	await _until(func() -> bool: return rm.phase == "FIGHT" and p.hotbar.spell != "", 12.0)
	foe.held = true
	RingRules.current().stale_off = true
	await _secs(3.5)
	home = foe.global_position
	home.y = p.global_position.y
	p.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-p.camera.global_basis.z).y > 0.0 else -1.0
	physics_frame.connect(_aim)
	var hb := p.hotbar
	# ---- the Column
	await _stage("earth")
	BendVariants.set_to(p, "earth_shove", "column", "up")
	hb.ready_move(1, "earth_shove", "column")
	await _ticks(3)
	_expect(c._tracks("earth_shove") and not c._tracks("stone_form"), "the Column tracks, the Spike does not")
	look_off = true
	c.held_override = true
	await _secs(1.0)
	_expect(c.state == SwayCaster.State.LOCKING and c.fill < 0.05 and c.track_off > 0.5,
			"looking beside him: the meter fills nothing (%.2f), off him %.1f s" % [c.fill, c.track_off])
	look_off = false
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	_expect(full, "on him: it fills (full)")
	look_off = true
	await _ticks(6)
	BendR3.hits_log.clear()
	c.held_override = false
	await _secs(1.0)
	_expect(not _hits_on_foe("earth_shove/column").is_empty(), "let go looking away: it erupts under him all the same")
	# the dodge
	await _stage("earth")
	hb.ready_move(1, "earth_shove", "column")
	full = await _fill_on_him()
	BendR3.hits_log.clear()
	c.held_override = false
	await _ticks(3)
	foe.global_position += way.cross(Vector3.UP).normalized() * 3.0      # (he steps aside in its rumble)
	await _secs(1.0)
	_expect(full and _hits_on_foe("earth_shove/column").is_empty(), "he steps 3 m aside in its rumble: it misses")
	# the drain
	await _stage("earth")
	hb.ready_move(1, "earth_shove", "column")
	c.held_override = true
	await _until(func() -> bool: return c.fill >= 0.5, 3.0)
	var half := c.fill
	look_off = true
	await _secs(0.9)
	var after := c.fill
	c.held_override = false
	_expect(half >= 0.5 and after < half - 0.2, "half full (%.2f), off him past the grace: it drains back (%.2f)" % [half, after])
	# ---- the Geyser
	await _stage("water")
	hb.ready_move(1, "wave", "spout")
	await _ticks(3)
	full = await _fill_on_him()
	look_off = true
	await _ticks(6)
	BendR3.hits_log.clear()
	c.held_override = false
	await _secs(1.0)
	_expect(full and not _hits_on_foe("wave/spout").is_empty(), "the Geyser: full on him, let go looking away: it erupts under him")
	# ---- the Wind Prison
	await _stage("air")
	var ov := BendLoadout.wear(p, ["air.wall.prison"], "", "air")
	_expect((ov.ids as Array).has("air.wall.prison"), "the Wind Prison worn (%s)" % str(ov.get("refused", [])))
	hb.ready_move(3, "air_wall", "wall")
	await _ticks(3)
	_expect(c._tracks("air_wall"), "the Wind Wall tracks with the Prison worn")
	# (he hangs 2.5 m up while the meter fills, held there, and drops as it is let go: a jump's or a knock's fall)
	var hang := foe.global_position + Vector3.UP * 2.5
	var pin := func() -> void:
		foe.global_position = hang
		foe.velocity = Vector3.ZERO
	physics_frame.connect(pin)
	full = await _fill_on_him()
	physics_frame.disconnect(pin)
	c.held_override = false                  # (let go as he drops from 2.5 m: in the air for 0.7 s)
	var walled := await _until(func() -> bool:
		for z in get_nodes_in_group(BendZone.GROUP):
			var bz := z as BendZone
			if bz.kind == "wind_wall" and bz.owner_node == p and Vector2(bz.global_position.x - foe.global_position.x, bz.global_position.z - foe.global_position.z).length() < 2.0:
				return true
		return false, 2.0)
	await _ticks(6)
	var held_up := BendStatus.floating(foe) and not foe.is_on_floor()
	_expect(full and walled, "tracked and let go: the prison rises round him (full %s, by him %s)" % [full, walled])
	_expect(held_up, "and holds him in the air (%.1f m up)" % (foe.global_position.y - home.y))
	BendLoadout.clear(p)
	_end()
