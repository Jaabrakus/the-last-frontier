extends SceneTree
## Earth's Column has a way (BendVariants; the owner, 2026-10-12: "toggle ... where it can fire diagonally or horazantally on
## walls earth walls ... the column ramp left to shoot them right", picked "Scroll to pick", then "maybe hold the key and then
## hit a direction keey?"), in a 1v1 Lives ring, earth against a held bot 7 m off, the crosshair on its chest:
##   the pick   the Column readied: the wheel steps up > throw right > throw left > from a wall > up; key 2 held and A: throw
##              left, D: throw right, S: from a wall, W: up; the strip's name says it ("Column · throw right")
##   the casts  up: the bot thrown up (its class earth_shove/column); throw right: thrown to the caster's right, low
##              (earth_shove/column.lean); throw left: to his left; from a wall (an Earth Wall raised by the bot): out of the
##              wall's face, near flat (earth_shove/column.wall); from a wall with none near: up as ever
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_column_way.gd
## The last line "COLUMN WAY PASSED (<n> checks)" or "COLUMN WAY FAILED (<f> of <n>)".

const LIMIT_S := 160.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var foe: NpcFighter
var rm: RingMode
var pc: BendCaster
var c: SwayCaster
var home := Vector3.ZERO
var way := Vector3(0, 0, 1)
var pitch_sign := 1.0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("COLUMN WAY FAILED (watchdog)")
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
	if fails.is_empty() and checks > 0:
		print("COLUMN WAY PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("COLUMN WAY FAILED (%d of %d)" % [fails.size(), checks])
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
	var d := (NpcSenses.chest_of(foe) - p.camera.global_position).normalized()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


func _face_off() -> void:
	for w in get_nodes_in_group(FormRaised.GROUP):
		if is_instance_valid(w):
			(w as Node).queue_free()
	foe.global_position = home + way * 3.5
	p.global_position = home - way * 3.5
	for b: CharacterBody3D in [p, foe]:
		b.velocity = Vector3.ZERO
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	RingRules.current().reset_pct(foe, 30.0)
	await _ticks(15)


## The Column cast at the bot (the game's own cast); {tag, kv (the hit's), moved (the bot's flat move 0.6 s on), rose}.
func _column() -> Dictionary:
	var f0 := foe.global_position
	BendR3.hits_log.clear()
	BendEffects.apply(pc, "earth_shove", "column", (SwayMoves.move("earth_shove").bend as Dictionary).column)
	var got := await _until(func() -> bool: return not BendR3.hits_log.is_empty(), 2.0)
	var top := foe.global_position.y
	for i in 36:
		await physics_frame
		top = maxf(top, foe.global_position.y)
	var e: Dictionary = BendR3.hits_log[-1] if got else {}
	var mv := foe.global_position - f0
	return {"tag": String(e.get("tag", "")), "kv": e.get("kv", Vector3.ZERO), "moved": Vector3(mv.x, 0.0, mv.z), "rose": top - f0.y}


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
	# ---- the pick
	hb.ready_move(1, "earth_shove", "column")
	await _ticks(3)
	BendVariants.set_to(p, "earth_shove", "column", "up")
	var seen: Array = []
	for i in 4:
		hb.wheel(1)
		seen.append(BendVariants.of(p, "earth_shove", "column"))
	_expect(hb.spell == "earth_shove" and c.mode_of("earth_shove") == "column" and seen == ["right", "left", "wall", "up"],
			"the wheel steps the Column's way: %s" % str(seen))
	var ctl := PlayerControls.new(false)
	var was: PlayerControls = p.controls
	p.controls = ctl
	var held: Array = []
	for a: StringName in [&"move_left", &"move_right", &"move_back", &"move_forward"]:
		ctl.set_held(&"weapon_2", true)
		await _ticks(2)
		ctl.set_held(a, true)
		await _ticks(2)
		held.append(BendVariants.of(p, "earth_shove", "column"))
		ctl.release_all()
		await _ticks(2)
	p.controls = was
	_expect(held == ["left", "right", "wall", "up"], "key 2 held and A, D, S, W: %s" % str(held))
	BendVariants.set_to(p, "earth_shove", "column", "right")
	hb.ready_move(1, "earth_shove", "column")
	var strip: Variant = p.hud.get(&"bend_strip") if p.hud != null else null
	var col: Dictionary = (strip as BendStrip).column(1) if strip is BendStrip else {}
	_expect(String(col.get("label", "")).contains("throw right"), "the strip says it ('%s')" % col.get("label", ""))
	# ---- the casts
	var right := way.cross(Vector3.UP).normalized()        # (the player faces +z: his right)
	var res := {}
	for v: String in ["up", "right", "left"]:
		await _face_off()
		BendVariants.set_to(p, "earth_shove", "column", v)
		res[v] = await _column()
	var up_r: Dictionary = res.up
	var r_r: Dictionary = res.right
	var l_r: Dictionary = res.left
	_expect(String(up_r.tag) == "earth_shove/column" and float(up_r.rose) > 1.0 and Vector3(up_r.moved).length() < 1.0,
			"up: thrown up (%s, rose %.1f m, moved %.1f m)" % [up_r.tag, up_r.rose, Vector3(up_r.moved).length()])
	_expect(String(r_r.tag) == "earth_shove/column.lean" and Vector3(r_r.moved).dot(right) > 1.0,
			"throw right: thrown to his right (%s, %.1f m right)" % [r_r.tag, Vector3(r_r.moved).dot(right)])
	_expect(String(l_r.tag) == "earth_shove/column.lean" and Vector3(l_r.moved).dot(right) < -1.0,
			"throw left: thrown to his left (%s, %.1f m right)" % [l_r.tag, Vector3(l_r.moved).dot(right)])
	# from a wall: an Earth Wall of the bot's 1.4 m to its left (the player's view), its face along the line between them
	await _face_off()
	var wall_at := FormEffects.ground_at(p, foe.global_position - right * 1.4)
	var ew := FormEffects.earth_wall(BendCaster.of(foe), wall_at, SwayMoves.move("earth_wall"), "earth")
	if ew != null:
		ew.global_basis = Basis(way, Vector3.UP, -right)       # (its face toward the bot: its z along the player's right)
	await _secs(1.0)
	BendVariants.set_to(p, "earth_shove", "column", "wall")
	var w_r: Dictionary = await _column()
	_expect(String(w_r.tag) == "earth_shove/column.wall" and Vector3(w_r.moved).dot(right) > 1.8 and float(w_r.rose) < 1.6,
			"from a wall: punched out of the wall's face, near flat (%s, %.1f m away from it, rose %.1f m)" % [w_r.tag, Vector3(w_r.moved).dot(right), w_r.rose])
	await _face_off()
	var n_r: Dictionary = await _column()
	_expect(String(n_r.tag) == "earth_shove/column", "from a wall with none near: up as ever (%s)" % n_r.tag)
	_end()
