extends SceneTree
## Any body bends (BendCaster; the owner, 2026-10-04: the ring's bots cast the same moves as the player), on the real level in
## the duel, the earthbender held still (his mind off) and wrapped in a BodyBendCaster aimed at the player:
##   the source   no bending helper types its caster as the player (bend_effects, bend_bolt, bend_zone, bend_motion, bending)
##   wrap         BendCaster.wrap takes a BendCaster, a SwayCaster and a body; the player's is a PlayerBendCaster, kept
##   the player   his aim through PlayerBendCaster is the aim as it was (the crosshair's point, the chest, the bolt's start)
##   every move   the bot casts every (move, mode) with a bend spec of all four elements, and Patch, through BendEffects:
##                last_of(its caster).do is the spec's do, it does its work on the player (struck, reached, a zone, it moves),
##                and BendEffects.last (the local player's) is never written by it
##   its bolts    a bolt from the bot's chest does not strike the bot's own hit parts
##   return       Air Redirect's "redirect" (a return zone) on the player sends the bot's fire bolt back at the bot
##   catch        Catch's catch zone on the player takes the bot's stone disc and pebbles (stone bolts) and holds a stone; the
##                player's Earth Shove (push) then sends it back at the bot
##   tornado      a tornado over a raised deck (a StaticBody3D 2 m up) goes along the deck, not the terrain under it
##   near         whom a bend reaches finds the player through his group "player" (not by the scene's "Player" name)
##   spray        Water Jet's spray (put_out) puts out a fire wall it is cast over
## (The old modes, stone_form spike / cannonball, earth_wall wall, pillar self / free, gust's and mend, are cast through
## BendCast with T1b; not here.)
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_bend_caster.gd -- mode=duel

const WATCHDOG_S := 280.0

var fails := 0
var p: FrontierPlayer
var c: SwayCaster
var duel: DuelMode
var n: NpcFighter
var bc: BodyBendCaster


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("BEND_CASTER FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, FrontierTerrain.height_at(v.x, v.z), v.z)


## The player at the arena's middle-ish facing +x, the bot `d` m before him (at +x), held still and whole, the player anchored
## (the bot's knocks leave him where he stands), both whole and full of water.
func _stage(d := 9.0) -> void:
	var at := duel.arena.center() + Vector3(-6.0, 0.0, 6.0)
	p.global_position = _ground(at) + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	p.yaw = -PI / 2.0
	p.rotation.y = p.yaw
	p.pitch = 0.0
	p.health = p.max_health
	n.held = true
	n.global_position = _ground(at + Vector3(d, 0.0, 0.0)) + Vector3.UP * 0.05
	n.velocity = Vector3.ZERO
	n.health = n.health_max
	n.action = ""
	n.rotation.y = PI / 2.0                     # (facing -x: the player)
	Bending.of(n).water = 100.0
	Bending.of(p).water = 100.0


func _clear() -> void:
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	for k: StringName in [&"bend_root", &"bend_slow", &"bend_anchor"]:
		if n.has_meta(k):
			n.remove_meta(k)


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	c = SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null, "the duel, its player and his caster")
	if c == null:
		print("BEND_CASTER FAILED")
		return quit(1)
	p.ignore_mouse_capture = true
	await _secs(Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0)
	n = duel.npc
	_expect(n != null and is_instance_valid(n), "the bot")
	if n == null:
		print("BEND_CASTER FAILED")
		return quit(1)
	n.held = true
	_source()
	_wrap()
	await _player_aim()
	bc = BodyBendCaster.new(n, p, 0.8, 0.0)
	bc.side = 1.0
	bc.bind()
	await _every_move()
	await _own_bolt()
	await _return()
	await _catch()
	await _tornado()
	await _near_and_spray()
	print("BEND_CASTER " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- the source
func _source() -> void:
	var bad: Array[String] = []
	var re := RegEx.create_from_string("(\\(|,\\s*)\\w+\\s*:\\s*FrontierPlayer\\b|var\\s+\\w+\\s*:\\s*FrontierPlayer\\b")
	for f: String in ["bend_effects.gd", "bend_bolt.gd", "bend_zone.gd", "bend_motion.gd", "bending.gd"]:
		var src := FileAccess.get_file_as_string("res://scripts/bending/" + f)
		for m in re.search_all(src):
			bad.append("%s: %s" % [f, m.get_string().strip_edges()])
	_expect(bad.is_empty(), "no bending helper types its caster as the player%s" % ("" if bad.is_empty() else ": " + ", ".join(bad)))


func _wrap() -> void:
	var pc := BendCaster.wrap(c)
	_expect(pc is PlayerBendCaster and pc.body == p, "wrap(the SwayCaster): the player's PlayerBendCaster")
	_expect(BendCaster.wrap(p) == pc and BendCaster.of(p) == pc, "wrap(the player) and of(the player): the same one, kept")
	_expect(BendCaster.wrap(pc) == pc, "wrap(a BendCaster): itself")
	var nb := BendCaster.wrap(n)
	_expect(nb is BodyBendCaster and nb.body == n and not nb.is_local(), "wrap(a fighter): a BodyBendCaster, not local")
	var plain := Node.new()
	_expect(BendCaster.wrap(null) == null and BendCaster.wrap(plain) == null, "wrap(null) and wrap(a plain node): null")
	plain.free()


## The player's aim through his caster: as BendEffects.aim was before the caster (FormEffects.aim_point, the aim's help on a
## fighter near the crosshair, his chest 1.35 m up, the bolt's start 0.6 m along).
func _player_aim() -> void:
	_clear()
	await physics_frame
	_stage(20.0)
	n.global_position += Vector3(0.0, 0.0, 6.0)          # (off the crosshair: the plain aim)
	await _secs(0.3)
	var a := BendEffects.aim(c)
	var point := FormEffects.aim_point(c)
	var cam := p.camera
	var t := FormEffects.assist_target(c, cam.global_position, -cam.global_basis.z)
	if t != null:
		point = NpcSenses.chest_of(t)
	var chest := p.global_position + Vector3.UP * 1.35
	var flat := point - p.global_position
	flat.y = 0.0
	flat = flat.normalized()
	var from := chest + flat * 0.6
	_expect((a.point as Vector3).distance_to(point) < 1e-3 and (a.from as Vector3).distance_to(from) < 1e-3 and a.target == t,
			"the player's aim as before (point %s, from %s)" % [str(a.point), str(a.from)])
	_stage(12.0)
	await _secs(0.3)
	var a2 := BendEffects.aim(c)
	_expect(a2.target == n, "the aim's help: the bot on the crosshair is the target (%s)" % str(a2.target))


# ---------------------------------------------------------------- every move, by the bot
func _every_move() -> void:
	var player_last := BendEffects.last
	var count := 0
	var bad: Array[String] = []
	var skipped: Array[String] = []
	var dash_m := 0.0
	BendStatus.anchor(p, 10000.0)
	var ids: Array[String] = []
	for el: String in Bending.ELEMENTS:
		for pair in Bending.keys(el):
			for id: String in pair:
				if not ids.has(id):
					ids.append(id)
		for extra: Dictionary in [Bending.jab(el), Bending.guard(el)]:   # (round 2: the jab on LMB, the guard on E)
			if not ids.has(String(extra.get("id", ""))):
				ids.append(String(extra.get("id", "")))
	var want := 0
	for id in ids:
		for mode: String in SwayCaster.modes_of(id):
			if not ((SwayMoves.move(id).get("bend", {}) as Dictionary).get(mode, {}) as Dictionary).is_empty():
				want += 1
	for id in ids:
		for mode: String in SwayCaster.modes_of(id):
			var spec: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(mode, {})
			if spec.is_empty():
				skipped.append("%s/%s" % [id, mode])
				continue
			_clear()
			await physics_frame
			_stage()
			await _secs(0.1)
			if id == "earth_shove":
				BendEffects.kick_up(bc, Vector3.LEFT, {})          # (a stone before the bot to shove)
				await _secs(0.35)
			bc.modes[id] = mode
			var why := await _bot_cast(id, mode, spec)
			if String(spec.do) == "dash" and id == "fire_jets" and mode == SwayCaster.modes_of("fire_jets")[0]:
				dash_m = float(BendEffects.last_of(bc).get("moved", 0.0))
			count += 1
			if why != "":
				bad.append("%s/%s: %s" % [id, mode, why])
			if not is_same(BendEffects.last, player_last):
				bad.append("%s/%s: wrote BendEffects.last" % [id, mode])
				player_last = BendEffects.last
	p.remove_meta(&"bend_anchor")
	print("  (the old modes, with T1b: %s)" % ", ".join(skipped))
	var patched := String(BendEffects.last_of(bc).get("move", "")) == "patch" or ids.has("patch")
	_expect(count == want and count >= 25 and skipped.size() <= 8 and patched and bad.is_empty(),
			"the bot cast every bend (move, mode) of the four kits, their jabs and guards, and Patch (%d of %d)%s" % [count, want,
			"" if bad.is_empty() else ": " + ", ".join(bad)])
	_expect(dash_m >= 2.0, "a bot's Fire Jets dash carries it %.1f m (at least 2)" % dash_m)


## The bot casts `id` in `mode`: "" when it did what its spec says, else why not.
func _bot_cast(id: String, mode: String, spec: Dictionary) -> String:
	var h0 := p.health
	var n0 := n.global_position
	BendEffects.apply(bc, id, mode, spec)
	var dn := String(spec.get("do", ""))
	var rec := BendEffects.last_of(bc)
	if String(rec.get("do", "")) != dn:
		return "not cast (%s)" % rec.get("do", "-")
	# (now: a shoved stone is gone after, a bolt; round 2's empty case kicks one up and pushes it: its stone)
	var shoved := rec.get("target") != null or rec.get("stone") != null
	var whys: Array[String] = []
	for b in get_nodes_in_group(BendBolt.GROUP):
		if (b as BendBolt).caster == n:
			(b as BendBolt).ended.connect(func(w: String) -> void: whys.append(w))
	await _secs(0.7)
	rec["moved"] = n.global_position.distance_to(n0)
	match dn:
		"bolt", "lightning":
			if float(spec.get("damage", 0.0)) > 0.0 and p.health >= h0:
				return "the player was not struck (%.0f; its bolts ended %s)" % [p.health, str(whys)]
		"cone", "ring":
			if float(spec.get("range_m", spec.get("radius_m", 0.0))) >= 9.0 and int(rec.get("hit", 0)) < 1:
				return "it did not reach the player"
		"dash":
			if float(spec.get("fwd_mps", 10.0)) < 1.0:
				# (straight up: the bot's own floor snap takes the lift away until the knock model lets a launched fighter
				# leave the floor (T2's BendKnock); the dash itself is checked: its velocity given)
				if not (rec.get("v", Vector3.ZERO) as Vector3).y > 0.0:
					return "no lift given"
			elif n.global_position.distance_to(n0) < 0.8:
				return "the bot did not move (%.2f m)" % n.global_position.distance_to(n0)
		"zone":
			if String(rec.get("zone_kind", "")) != String(spec.get("zone", "")):
				return "no zone"
		"kick_up":
			if not is_instance_valid(rec.get("stone")):
				return "no stone"
		"column", "shell", "ramp", "ice_wall":
			if get_nodes_in_group(FormRaised.GROUP).is_empty():
				return "nothing raised"
		"shove":
			if not shoved:
				return "nothing shoved"
	return ""


# ---------------------------------------------------------------- its bolts, return, catch, the tornado
func _own_bolt() -> void:
	_clear()
	await physics_frame
	_stage(9.0)
	await _secs(0.2)
	var whys: Array[String] = []
	for dir: Vector3 in [Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.DOWN * 0.3 + Vector3.RIGHT]:
		var b := BendBolt.launch(n, NpcSenses.chest_of(n), dir.normalized(), {"kind": "fire", "mps": 30.0, "radius_m": 0.25, "range_m": 30.0})
		var why := [""]
		b.ended.connect(func(w: String) -> void: why[0] = w)
		await _secs(0.15)
		whys.append(why[0])
	_expect(not "hit" in whys, "bolts from the bot's chest do not strike its own hit parts in 0.15 s (%s)" % str(whys))


func _return() -> void:
	_clear()
	await physics_frame
	_stage(10.0)
	await _secs(0.2)
	var spec: Dictionary = (SwayMoves.move("air_redirect").get("bend", {}) as Dictionary).get("redirect", {})
	BendEffects.apply(c, "air_redirect", "redirect", spec)
	_expect(String(BendEffects.last.get("zone_kind", "")) == "return", "Air Redirect's redirect: a return zone on the player (%s)" % BendEffects.last.get("zone_kind", "-"))
	var fb := BendBolt.launch(n, NpcSenses.chest_of(n) + Vector3.LEFT * 0.8, Vector3.LEFT, {"kind": "fire", "mps": 20.0, "radius_m": 0.2, "range_m": 40.0, "damage": 5.0})
	await _secs(0.45)
	var ok := is_instance_valid(fb) and not fb.spent and fb.caster == p and fb.velocity.dot(n.global_position - fb.global_position) > 0.0
	_expect(ok, "the bot's fire bolt sent back toward the bot (%s)" % ("gone" if not is_instance_valid(fb) else str(fb.velocity)))


func _catch() -> void:
	for mode: String in ["disc", "pebbles"]:
		var id := "stone_form" if mode == "disc" else "rock_jab"
		_clear()
		await physics_frame
		_stage(12.0)
		await _secs(0.2)
		var cspec: Dictionary = (SwayMoves.move("stone_catch").get("bend", {}) as Dictionary).get("catch", {})
		var g_spec := cspec.duplicate()
		g_spec["window_s"] = 2.0
		BendEffects.apply(c, "stone_catch", "catch", g_spec)
		var g: BendZone = BendEffects.last.get("zone")
		var spec: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(mode, {})
		bc.modes[id] = mode
		BendEffects.apply(bc, id, mode, spec)
		var t := 0.0
		while t < 1.5 and (g == null or not is_instance_valid(g) or g.took == 0):
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			p.health = p.max_health
		await _secs(0.2)
		var held_all: Array = []
		for st in get_nodes_in_group(FormStone.GROUP):
			if int((st as Node).get_meta(&"bend_held_by", -1)) == p.get_instance_id():
				held_all.append(st)
		_expect(g != null and g.took >= 1 and not held_all.is_empty(), "Catch takes the bot's %s (stone bolt) and holds a stone (%.2f s, %d held)" % [mode, t, held_all.size()])
		if held_all.is_empty():
			continue
		# the player's Earth Shove (push): a held stone sent back
		var h0 := n.health
		var sspec: Dictionary = (SwayMoves.move("earth_shove").get("bend", {}) as Dictionary).get("push", {})
		c.set_mode("earth_shove", "push")
		BendEffects.apply(c, "earth_shove", "push", sspec)
		var held := BendEffects.last.get("target") as FormStone
		var thrown := held != null and held_all.has(held)
		if not thrown:
			_expect(false, "Earth Shove takes a held stone (%s)" % str(BendEffects.last.get("target")))
			continue
		var d0 := held.global_position.distance_to(NpcSenses.chest_of(n))
		var best := d0
		for i in int(1.2 * Engine.physics_ticks_per_second):
			await physics_frame
			if is_instance_valid(held):
				best = minf(best, held.global_position.distance_to(NpcSenses.chest_of(n)))
		_expect(thrown and (d0 - best >= 2.0 or n.health < h0),
				"Earth Shove sends the caught stone back at the bot (%.1f m nearer, his health %.0f to %.0f)" % [d0 - best, h0, n.health])


func _tornado() -> void:
	_clear()
	await physics_frame
	_stage(20.0)
	var o := duel.arena.center() + Vector3(10.0, 0.0, -14.0)
	var hi := -INF
	for i in 9:
		for j in 5:
			var q := o + Vector3(-4.0 + i * 2.0, 0.0, -4.0 + j * 2.0)
			hi = maxf(hi, FrontierTerrain.height_at(q.x, q.z))
	var top := hi + 2.0
	var deck := StaticBody3D.new()
	deck.name = "TestDeck"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24.0, 0.4, 14.0)
	cs.shape = box
	deck.add_child(cs)
	current_scene.add_child(deck)
	deck.global_position = Vector3(o.x, top - 0.2, o.z)
	await _secs(0.1)
	var z := BendZone.make(n, "tornado", Vector3(o.x - 6.0, top, o.z), {"radius_m": 1.8, "life_s": 3.0, "mps": 6.0, "damage_s": 0.0}, Vector3.RIGHT)
	var worst := 0.0
	for i in int(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if is_instance_valid(z):
			worst = maxf(worst, absf(z.global_position.y - top))
	var went := is_instance_valid(z) and z.global_position.x - (o.x - 6.0) > 5.0
	_expect(worst < 0.3 and went, "a tornado goes along a deck 2 m up (off by %.2f m at most; went %s)" % [worst, str(went)])
	if is_instance_valid(z):
		z.end()
	deck.queue_free()


func _near_and_spray() -> void:
	_clear()
	await physics_frame
	_stage(9.0)
	await _secs(0.2)
	# the player renamed for a moment: BendStatus.near looks for "Player" by name; BendCaster.near also by his group
	var was := p.name
	p.name = "PlayerRenamedForTest"
	var found := false
	for e in BendCaster.near(n, p.global_position, 2.0):
		found = found or e[0] == p
	var once := 0
	for e in BendCaster.near(n, p.global_position, 2.0):
		once += 1 if e[0] == p else 0
	p.name = was
	_expect(found and once == 1, "whom a bend reaches: the player found by his group, once (renamed: %s)" % str(found))
	# spray over a fire wall
	var at := FormEffects.ground_at(p, p.global_position + Vector3.RIGHT * 2.5)
	var fw := BendZone.make(n, "fire_wall", at, {"width_m": 3.0, "height_m": 2.0, "thick_m": 0.6, "life_s": 6.0, "damage_s": 0.0}, Vector3.LEFT)
	await _secs(0.1)
	var spec: Dictionary = (SwayMoves.move("water_jet").get("bend", {}) as Dictionary).get("spray", {})
	BendEffects.apply(c, "water_jet", "spray", spec)
	await _secs(0.1)
	_expect(String(BendEffects.last.get("zone_kind", "")) == "spray" and int(BendEffects.last.get("put_out", 0)) >= 1 and
			(not is_instance_valid(fw) or fw.is_queued_for_deletion()), "Water Jet's spray puts out the fire wall it is cast over (%s)" % str(BendEffects.last.get("put_out", "-")))
