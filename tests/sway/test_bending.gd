extends SceneTree
## Bending (docs/bending_design.md; BendEffects, BendBolt, BendZone, Bending; the user, 2026-10-04) on the real level, in the
## duel against the earthbender held still before the player:
##   keys       each element's bar (Bending.bar: the first skill of 1-4, Mend on 5); the readied key again switches to its
##              other skill; the wheel steps the skill's variations (SwayCaster.step_mode)
##   every move every element's every skill's every variation cast (FormEffects.apply, as a release does): it does what its
##              spec says (a bolt flies, a cone or ring reaches him, a zone stands, the caster moves, ...) and nothing errs
##   meeting    water + fire bolts: steam, both gone; a stone goes on through fire; the water jet wears an earth wall more than
##              fire does; fire melts an ice wall; a bubble stops fire and lets stone through; an air shield sends fire back;
##              a catch takes the bender's spike out of the air
##   only=<element> (earth, water, fire, air): every move of that element only (the keys and the meetings as ever); the count
##   cast and the time it took printed
##   Godot --headless --fixed-fps 60 --path . -s tests/sway/test_bending.gd -- mode=duel [only=fire]

## The run's limit (s): it fails itself before the lock wrapper's GODOT_TIMEOUT kills it.
const WATCHDOG_S := 280.0

var fails := 0
var p: FrontierPlayer
var c: SwayCaster
var duel: DuelMode
var n: NpcFighter
## Every move of this element only ("" all).
var only := ""


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	if only != "" and not only in Bending.ELEMENTS:
		print("  FAIL only=%s is no element (%s)" % [only, str(Bending.ELEMENTS)])
		print("BENDING FAILED")
		quit(1)
		return
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("BENDING FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, FrontierTerrain.height_at(v.x, v.z), v.z)


## The player at the arena's middle-ish facing +x, the bender `d` m before him, held still and whole: his bones too (a
## cannonball in "every move" can break his clavicle, and an arm's bone broken makes him run on his first thought once let
## go, ending the duel's round, which holds him again: the catch's spike never thrown) and no knock left on either of them
## (BendKnock's own velocity outlives velocity = 0).
func _stage(d := 9.0) -> void:
	var at := duel.arena.center() + Vector3(-6.0, 0.0, 6.0)
	p.global_position = _ground(at) + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	p.yaw = -PI / 2.0                       # (facing +x)
	p.rotation.y = p.yaw
	p.pitch = 0.0
	p.health = p.max_health
	var pk := BendKnock.peek(p)
	if pk != null:
		pk.reset()
	if n != null and is_instance_valid(n):
		n.held = true
		n.global_position = _ground(at + Vector3(d, 0.0, 0.0)) + Vector3.UP * 0.05
		n.velocity = Vector3.ZERO
		n.health = n.health_max
		n.action = ""
		n.arm_broken = ""
		n.limp = 1.0
		n.pool = 0.0
		n.mortal_left = 0.0
		var nk := BendKnock.peek(n)
		if nk != null:
			nk.reset()


func _clear() -> void:
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	c = SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null, "the duel, its player and his caster")
	if c == null:
		return quit(1)
	p.ignore_mouse_capture = true
	await _secs(Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0)
	n = duel.npc
	await _keys()
	await _every_move()
	await _earth_sides()
	await _meetings()
	print("BENDING " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- the keys
func _keys() -> void:
	var bar := Hotbar.of(p)
	for el: String in Bending.ELEMENTS:
		DuelMode.element = el
		duel.lay_bar()
		await physics_frame
		var want := Bending.bar(el)
		var ok := want.size() == 5
		for i in want.size():
			ok = ok and String(bar.entry(i).get("id", "")) == String(want[i])
		_expect(ok, "%s: the bar %s" % [el, str(want)])
	DuelMode.element = "fire"
	duel.lay_bar()
	await physics_frame
	bar.take(0)
	await physics_frame
	_expect(c.readied_spell == "fire_blast", "key 1: Fire Blast readied (%s)" % c.readied_spell)
	bar.select(0)
	await physics_frame
	_expect(c.readied_spell == "fire_jab" and String(bar.entry(0).id) == "fire_jab", "key 1 again: its other skill, Fire Jab (%s)" % c.readied_spell)
	bar.select(0)
	await physics_frame
	_expect(c.readied_spell == "fire_blast", "and again: back to Fire Blast")
	var m0 := c.mode_of("fire_blast")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var used := bar.handle_input(wheel) if InputMap.has_action(&"weapon_next") and wheel.is_action_pressed(&"weapon_next") else bar._step_mode(1)
	_expect(used and c.mode_of("fire_blast") != m0 and c.readied_spell == "fire_blast",
			"the wheel: the next variation (%s to %s), the same skill" % [m0, c.mode_of("fire_blast")])


# ---------------------------------------------------------------- every move
func _every_move() -> void:
	var count := 0
	var want := 0
	var bad: Array[String] = []
	var t0 := Time.get_ticks_msec()
	for el: String in Bending.ELEMENTS:
		if only != "" and el != only:
			continue
		for pair in Bending.keys(el):
			for id: String in pair:
				want += SwayCaster.modes_of(id).size()
		for pair in Bending.keys(el):
			for id: String in pair:
				for mode: String in SwayCaster.modes_of(id):
					_clear()
					await physics_frame
					# (a scattered volley, embers' seven sparks at 9 deg, staged nearer: at 9 m its scatter, the player's own dice,
					# could put every spark past him on one roll of the dice; R1 gate, once the sounds stopped rolling those dice)
					var sp: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(mode, {})
					_stage(5.0 if float(sp.get("spread_deg", 0.0)) > 0.0 and int(sp.get("count", 1)) > 1 else 9.0)
					await _secs(0.1)
					c.set_mode(id, mode)
					Bending.of(p).water = 100.0
					var why := await _cast(id, mode)
					count += 1
					if why != "":
						bad.append("%s/%s: %s" % [id, mode, why])
	print("  every move: %d cast of %s in %.1f s" % [count, only if only != "" else "every element", (Time.get_ticks_msec() - t0) / 1000.0])
	_expect(count == want and count > 0, "%s: %d (move, mode) cast, %d wanted" % [only if only != "" else "every element", count, want])
	_expect(bad.is_empty(), "every element's every move cast and did its work (%d moves)%s" % [count, "" if bad.is_empty() else ": " + ", ".join(bad)])


## Move `id` in `mode` cast: "" when it did what its spec says, else why not.
func _cast(id: String, mode: String) -> String:
	var spec: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(mode, {})
	var h0 := n.health
	var pos0 := p.global_position
	var at := p.global_position + Vector3(3.0, 0.0, 0.0)
	FormEffects.apply(c, id, c.form.mark if c.form != null else p, at)
	var dn := String(spec.get("do", ""))
	await _secs(0.7)
	if spec.is_empty():
		# (the spells of old: stone_form spike / cannonball, earth_wall wall, pillar self / free, gust's, mend)
		return ""
	if String(BendEffects.last.get("do", "")) != dn:
		return "not cast (%s)" % BendEffects.last.get("do", "-")
	match dn:
		"bolt", "lightning", "grab":
			if float(spec.get("damage", 0.0)) > 0.0 and n.health >= h0 and not (dn == "grab"):
				return "he was not struck (%.0f)" % n.health
		"cone", "ring":
			if float(spec.get("range_m", spec.get("radius_m", 0.0))) >= 9.0 and int(BendEffects.last.get("hit", 0)) < 1:
				return "it did not reach him"
		"dash":
			if p.global_position.distance_to(pos0) < 0.8:
				return "the caster did not move"
		"zone":
			if String(BendEffects.last.get("zone_kind", "")) != String(spec.get("zone", "")):
				return "no zone"
		"kick_up":
			if not is_instance_valid(BendEffects.last.get("stone")):
				return "no stone"
		"column", "shell", "ramp", "ice_wall":
			if get_nodes_in_group(FormRaised.GROUP).is_empty():
				return "nothing raised"
	return ""


# ---------------------------------------------------------------- earth's side-steps
## Earth Skate (the owner, 2026-10-05: "for earth bending we need the side steps, burrow steps to be on the side"): slide and
## burrow-step go across the facing, to the side held (move_left / move_right), the right with neither; skate goes forward.
## The player faces +x, so his right is +z. The key is held only over the cast (held_side is read as the dash starts), so
## the walk adds nothing.
func _earth_sides() -> void:
	if only != "" and only != "earth":
		return
	DuelMode.element = "earth"
	duel.lay_bar()
	await physics_frame
	var bad: Array[String] = []
	for row in [["slide", &"move_right", 1.0], ["slide", &"move_left", -1.0], ["slide", &"", 1.0],
			["burrow", &"move_right", 1.0], ["burrow", &"move_left", -1.0], ["burrow", &"", 1.0], ["skate", &"", 0.0]]:
		var mode := String(row[0])
		var key: StringName = row[1]
		var want := float(row[2])
		_clear()
		await physics_frame
		_stage()
		await _secs(0.15)
		c.set_mode("earth_skate", mode)
		var pos0 := p.global_position
		if key != &"":
			Input.action_press(key)
		FormEffects.apply(c, "earth_skate", c.form.mark if c.form != null else p, p.global_position + Vector3(3.0, 0.0, 0.0))
		if key != &"":
			Input.action_release(key)
		await _secs(0.6)
		var d := p.global_position - pos0
		var across := d.z
		var along := d.x
		var ok := false
		if want == 0.0:
			ok = along > 0.8 and absf(along) > 2.0 * absf(across)
		else:
			ok = across * want > 0.8 and absf(across) > 2.0 * absf(along)
		var what := "%s%s: across %.2f m, along %.2f m" % [mode, " (%s)" % key if key != &"" else " (no side held)", across, along]
		print("  earth skate %s" % what)
		if not ok:
			bad.append(what)
	_expect(bad.is_empty(), "Earth Skate: slide and burrow-step to the side held (the right with none), skate forward%s"
			% ("" if bad.is_empty() else ": " + ", ".join(bad)))


# ---------------------------------------------------------------- moves meeting
func _meetings() -> void:
	_clear()
	await physics_frame
	_stage(20.0)
	var base := p.global_position + Vector3(0, 1.4, 6.0)
	# water and fire: steam
	var w := BendBolt.launch(p, base, Vector3.RIGHT, {"kind": "water", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0})
	var f := BendBolt.launch(n, base + Vector3(8, 0, 0), Vector3.LEFT, {"kind": "fire", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0})
	var whys := []
	w.ended.connect(func(why: String) -> void: whys.append(why))
	f.ended.connect(func(why: String) -> void: whys.append(why))
	await _secs(0.6)
	_expect(whys.count("steam") == 2, "water meets fire: both gone in steam (%s)" % str(whys))
	# stone through fire
	var s := BendBolt.launch(p, base, Vector3.RIGHT, {"kind": "stone", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0})
	var f2 := BendBolt.launch(n, base + Vector3(8, 0, 0), Vector3.LEFT, {"kind": "fire", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0})
	var f2_why := [""]
	f2.ended.connect(func(why: String) -> void: f2_why[0] = why)
	await _secs(0.35)
	_expect(f2_why[0] == "stone" and is_instance_valid(s) and not s.spent, "a stone meets fire: the fire is gone, the stone goes on")
	_clear()
	await physics_frame
	# the water jet erodes an earth wall more than fire; fire melts an ice wall
	_stage(20.0)
	var flat := Vector3.RIGHT
	var ew := BendEffects._wall(p, Transform3D(Basis(Vector3.UP.cross(flat).normalized(), Vector3.UP, flat), _ground(p.global_position + flat * 4.0)), "earth")
	var ew2 := BendEffects._wall(p, Transform3D(Basis(Vector3.UP.cross(flat).normalized(), Vector3.UP, flat), _ground(p.global_position + flat * 4.0 + Vector3(0, 0, 8))), "earth")
	await _secs(1.0)
	for i in 4:
		var jb := BendBolt.new()
		jb.kind = "water"
		jb.erode = 3.0
		jb.damage = 3.0
		jb.wear(ew, ew.global_position + Vector3.UP)
		var fb := BendBolt.new()
		fb.kind = "fire"
		fb.damage = 20.0
		fb.wear(ew2, ew2.global_position + Vector3.UP)
		jb.free()
		fb.free()
	_expect(ew.hits > ew2.hits, "four water jets wear an earth wall more than four fire bolts (%d hits to %d)" % [ew.hits, ew2.hits])
	var iw := BendEffects.ice_wall(p, flat)
	await _secs(1.0)
	var fb2 := BendBolt.new()
	fb2.kind = "fire"
	fb2.damage = 20.0
	var ih := iw.hits
	fb2.wear(iw, iw.global_position + Vector3.UP)
	fb2.free()
	_expect(iw.hits - ih >= 3 or not iw.is_up(), "fire melts an ice wall fast (%d hits from one bolt)" % (iw.hits - ih))
	_clear()
	await physics_frame
	# a bubble stops fire, lets stone through; an air shield sends fire back
	_stage(20.0)
	var bub := BendZone.make(p, "bubble", p.global_position, {"radius_m": 1.6, "life_s": 3.0})
	var fire_in := BendBolt.launch(n, p.global_position + Vector3(6, 1.2, 0), Vector3.LEFT, {"kind": "fire", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0})
	var stone_in := BendBolt.launch(n, p.global_position + Vector3(6, 1.2, 1.0), Vector3.LEFT, {"kind": "stone", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0, "damage": 1.0})
	var fw := [""]
	var sw := [""]
	fire_in.ended.connect(func(why: String) -> void: fw[0] = why)
	stone_in.ended.connect(func(why: String) -> void: sw[0] = why)
	await _secs(0.6)
	_expect(fw[0] == "steam" and sw[0] != "bubble", "a bubble: fire dies in it (%s), stone goes through (%s)" % [fw[0], sw[0]])
	bub.end()
	_clear()
	await physics_frame
	_stage(20.0)
	BendZone.make(p, "air_shield", p.global_position, {"radius_m": 2.2, "life_s": 3.0})
	var back := BendBolt.launch(n, p.global_position + Vector3(6, 1.2, 0), Vector3.LEFT, {"kind": "fire", "mps": 20.0, "radius_m": 0.2, "range_m": 40.0})
	await _secs(0.4)
	_expect(is_instance_valid(back) and back.caster == p and back.velocity.x > 0.0, "an air shield sends fire back at its sender")
	_clear()
	await physics_frame
	# a catch takes the bender's spike out of the air
	_stage(12.0)
	# (the window as long as the wait: the wait counted 1/60 s a tick before, at 120 ticks a second, so it was 3 s)
	var g := BendZone.make(p, "catch", p.global_position, {"window_s": 6.0, "radius_m": 3.5})
	n.held = false
	n.brain.bending._next["spike"] = 0.0
	var t := 0.0
	var took := 0
	while t < 6.0 and took == 0 and is_instance_valid(g):
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second     # (one physics tick: 1/120 s here, not a 60 fps frame)
		p.health = p.max_health
		took = g.took if is_instance_valid(g) else took
	var held := false
	for st in get_nodes_in_group(FormStone.GROUP):
		if int((st as Node).get_meta(&"bend_held_by", -1)) == p.get_instance_id():
			held = true
	_expect(took >= 1 and held, "a catch takes the bender's spike out of the air and holds it (%.1f s)" % t)
	n.held = true
