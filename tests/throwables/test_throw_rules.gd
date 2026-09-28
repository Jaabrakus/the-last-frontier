extends "res://tests/throwables/harness.gd"
## Headless test of the thrown weapons' rules, on the player in the real level (player.gd
## registers the throwables in the roster on keys 4-6; the harness installs the kit again, which
## reuses them, and drives them directly with scripted input):
##   roster      install again leaves player.weapons / weapon_order and player.gd's weapon alone;
##               the throwables are in the roster (keys 4-6) as child weapons under player/Throwables
##   clips       every clip the throwables name exists in the Actor_B library
##   models      the primitive fallbacks carry the same markers as the GLBs
##   phases      idle -> aiming -> throwing -> recovering -> idle; cancel; empty; carry limit
##   damage      exact Hit.deliver damage (x speed falloff x weak spot) on the dummy torso
##               and head, on a wooden board (source = player), blunt on stone
##   surfaces    sticks in wood (a board, a real tree), straw (dummy) and the dirt lane
##               (a long lob); bounces off stone and lies on the ground; flies point first
##   tomahawk    spins end over end at spin_rate and sticks blade first in wood
##   removed     a target that is freed drops its stuck spear to the ground as a pickup
##   pickup key  E (interact) picks up out of walking reach; require_interact; HUD prompt
##   pipe        the pipe tomahawk variant builds, flies, sticks and goes back to itself
##   anim event  wait_for_anim_release waits for release_from_animation(), with a timeout (the
##               player's animation, which calls it on the throw's release frame, is told not to)
##   unequip     switching away mid-wind-up keeps the spear
##   audio       ThrowableAudio cues for windup / release / draw / cancel / pickup / equip /
##               empty; a throw never startles the birds (no gunshot path)
##
##   Godot --headless --path . -s tests/throwables/test_throw_rules.gd -- --no-capture

const LIB_PATH := "res://animations/Actor_B.res"

var cues := {}                   ## "event:key" -> count (ThrowableAudio.cue)
var scares := 0


func _initialize() -> void:
	if not await _boot():
		print("THROW RULES TEST FAILED")
		quit(1)
		return
	var audio := player.get_node_or_null("ThrowableAudio") as ThrowableAudio
	if audio:
		audio.cue.connect(func(event: StringName, key: String) -> void:
			var k := "%s:%s" % [event, key]
			cues[k] = int(cues.get(k, 0)) + 1)
	_add_scare_counter()
	for k in kit:
		_no_spread(kit[k])
	_test_roster()
	_test_clips()
	_test_fallback_models()
	await _test_phases_and_limits()
	await _test_dummy_damage()
	await _test_wood_and_stone()
	await _test_tree()
	await _test_ground_lob()
	await _test_tomahawk_wood()
	await _test_removed_target()
	await _test_pickup_key()
	await _test_pipe_variant()
	await _test_anim_release_event()
	await _test_unequip_mid_windup()
	_test_audio(audio)
	var left := _thrown_in_world()
	_expect(left.is_empty(), "every thrown weapon was picked up again (%d left in the world)" % left.size())
	_finish("THROW RULES TEST")


# --- Fixtures ------------------------------------------------------------------------------

func _add_scare_counter() -> void:
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc _ready():\n\tadd_to_group('ambience')\nfunc scare():\n\tget_meta('test').scares += 1\n"
	s.reload()
	var n := Node.new()
	n.set_script(s)
	n.set_meta("test", self)
	current_scene.add_child(n)


## Records the first hit of `p`: collider, stuck, impact speed, launch speed, surface.
## `hit` is emitted after Hit.deliver and before the projectile sticks or bounces, so its
## velocity is still the impact velocity then.
func _record(p: ThrownProjectile) -> Dictionary:
	var rec := {}
	p.impact_sfx.connect(func(surface: String, _pt: Vector3, _sp: float, _st: bool) -> void:
		if not rec.has("surface"):
			rec["surface"] = surface)
	p.hit.connect(func(c: Object, pt: Vector3, stuck: bool) -> void:
		if rec.has("collider"):
			return
		rec["collider"] = c
		rec["point"] = pt
		rec["stuck"] = stuck
		rec["speed"] = p.velocity.length()
		rec["start"] = p._start_speed
		rec["damage"] = p.damage
		rec["blunt"] = p.blunt_damage)
	return rec


## Damage ThrownProjectile deals for the recorded hit, before the collider's weak-spot mult.
func _expected(rec: Dictionary) -> float:
	var falloff := clampf(float(rec.speed) / float(rec.start), 0.35, 1.0)
	return (float(rec.damage) if rec.stuck else float(rec.blunt)) * falloff


func _throw_at(w: Throwable, stand: Vector3, target: Vector3) -> Array:
	await _stand_and_aim(stand, target)
	var p := await _full_throw()
	if p == null:
		return [null, {}]
	return [p, _record(p)]


## After a release: the object leaves the hand, the arm follows through, the next is taken.
func _settle_next(w: Throwable) -> void:
	await _frames(int((w.release_time + w.follow_time + w.draw_time) * 120) + 10)


# --- Tests ---------------------------------------------------------------------------------

func _test_roster() -> void:
	print("roster")
	_expect(player.weapons.keys() == roster_before.weapons and player.weapon_order == roster_before.order,
			"install leaves player.weapons %s and weapon_order %s unchanged" % [player.weapons.keys(), player.weapon_order])
	var holder := player.get_node_or_null("Throwables")
	var all_under := true
	for k in kit:
		var w: Throwable = kit[k]
		all_under = all_under and w.get_parent() == holder and w.is_in_group(&"throwables") and w.player == player
		_expect(player.weapons.get(k) == w and player.weapon_order.find(k) == 3 + ThrowableKit.KEYS.find(k),
				"%s is in the roster on key %d (player.gd, THROW)" % [k, player.weapon_order.find(k) + 1])
	_expect(all_under, "the throwables are extra child weapons under player/Throwables")
	_expect(not (player.weapon is Throwable), "the player's own weapon is still %s" % player.weapon_key)


func _test_clips() -> void:
	print("clips")
	# The library the player's character plays from (Actor_B.res, library "actor_b").
	var lib: AnimationLibrary = null
	for ap in player.find_children("*", "AnimationPlayer", true, false):
		if (ap as AnimationPlayer).has_animation_library(&"actor_b"):
			lib = (ap as AnimationPlayer).get_animation_library(&"actor_b")
			break
	if lib == null:
		lib = load(LIB_PATH) as AnimationLibrary
	_expect(lib != null, "Actor_B animation library found")
	if lib == null:
		return
	var dirs := ["fw", "fw-lt", "fw-rt", "bw", "bw-lt", "bw-rt"]
	for k in kit:
		var w: Throwable = kit[k]
		var missing := PackedStringArray()
		for key: String in ["aim", "aim_crouch", "up", "down", "up_crouch", "down_crouch", "hands", "raise",
				"raise_crouch", "throw", "throw_crouch", "throw_end", "throw_end_crouch", "recover",
				"recover_crouch", "equip", "draw", "aim_walk", "aim_walk_crouch", "blocked_crouch"]:
			if not w.clips.has(key):
				missing.append("key " + key)
		for key: String in w.clips:
			var clip: String = w.clips[key]
			if key.begins_with("aim_walk"):
				for d: String in dirs:
					if not lib.has_animation(clip + "-" + d):
						missing.append(clip + "-" + d)
			elif not lib.has_animation(clip):
				missing.append(clip)
		for key: String in w.relaxed:
			var clip: String = w.relaxed[key][0]
			if not lib.has_animation(clip):
				missing.append(clip)
		_expect(missing.is_empty(), "%s: every clip key the design proposes is set and every clip exists %s" % [k, missing])


func _test_fallback_models() -> void:
	print("fallback models")
	var fallbacks := {
		"spear": ThrowableModels._spear(), "tomahawk": ThrowableModels._tomahawk(),
		"tomahawk_pipe": ThrowableModels._tomahawk(), "atlatl": ThrowableModels._atlatl(),
		"atlatl_dart": ThrowableModels._atlatl_dart(),
	}
	for kind: String in fallbacks:
		var glb := ThrowableModels.build(kind)
		var fb: Node3D = fallbacks[kind]
		var worst := 0.0
		var compared := 0
		for m: String in ThrowableModels.MARKERS:
			var a := glb.get_node_or_null(m) as Node3D
			var b := fb.get_node_or_null(m) as Node3D
			if a and b:
				compared += 1
				worst = maxf(worst, a.position.distance_to(b.position))
		_expect(compared >= 2 and worst < 0.01, "%s: stand-in markers match the GLB (%d compared, worst %.4f m)" % [kind, compared, worst])
		glb.free()
		fb.free()


func _test_phases_and_limits() -> void:
	print("phases and carry limit")
	var w := await _use("spear")
	var seq: Array = []
	var rec := func(ph: int) -> void: seq.append(Throwable.PHASE_NAMES[ph])
	w.phase_changed.connect(rec)
	var board := _board(10.0, -32.0, "wood")
	_expect(w.throw_phase_name() == "idle", "ready spear is idle")
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -24.0), -24.0), board.global_position)
	# Cancel: aiming -> idle.
	_fire(true)
	await _frames(20)
	_expect(w.throw_phase() == Throwable.Phase.AIMING, "LMB held: aiming")
	_cancel()
	await _frames(2)
	_fire(false)
	await _frames(4)
	_expect(seq == ["aiming", "idle"], "cancel: aiming -> idle %s" % [seq])
	# A full throw: aiming -> throwing -> recovering -> idle.
	seq.clear()
	_fire(true)
	for i in 240:
		await _frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	_fire(false)
	await _frames(2)
	_expect(w.throw_phase() == Throwable.Phase.THROWING and w.count == 2, "released: throwing, still in hand for release_time")
	await _settle_next(w)
	_expect(seq == ["aiming", "throwing", "recovering", "idle"], "throw: %s" % [seq])
	var first := w.last_thrown
	# Carry limit: full again (one picked up elsewhere) -> the thrown one stays where it is.
	_expect(w.add_items(1) == 1 and w.count == 2, "add_items fills up to max_count")
	_expect(w.add_items(3) == 0 and w.count == 2 and not w.can_take("spear"), "no more than max_count (2) are carried")
	await _wait_rest(first)
	var at := first.global_position
	player.global_position = Vector3(at.x, _ground_at(at.x, at.z + 1.0), at.z + 1.0) + Vector3.UP * 0.3
	await _frames(90)
	_expect(is_instance_valid(first) and not first.is_queued_for_deletion() and w.count == 2,
			"a full carrier walks past a thrown spear without taking it")
	w.count = 1                        # Undo the simulated pickup: two spears in all again.
	# Throw the other: the last one leaves the weapon empty.
	seq.clear()
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -24.0), -24.0), board.global_position + Vector3(-0.4, 0.0, 0.0))
	var p1 := await _full_throw()
	await _frames(int(w.follow_time * 120) + 10)
	_expect(w.count == 0 and w.throw_phase_name() == "empty" and seq.back() == "empty", "none left: empty %s" % [seq])
	var c0 := int(cues.get("empty:spear", 0))
	_fire(true)
	await _frames(3)
	_fire(false)
	await _frames(3)
	_expect(int(cues.get("empty:spear", 0)) == c0 + 1 and w.count == 0, "LMB with none left: the empty cue, nothing thrown")
	# Picking one up while empty takes it straight into the hand.
	seq.clear()
	for q in [first, p1]:
		await _wait_rest(q)
	_expect(await _pick_up(first), "picked up while empty")
	await _frames(int(w.draw_time * 120) + 10)
	_expect(seq.size() >= 2 and seq[0] == "recovering" and seq.back() == "idle" and w.count >= 1,
			"empty -> recovering (taking it) -> idle %s" % [seq])
	await _pick_up(p1)
	_expect(w.count == 2, "all spears back (%d)" % w.count)
	w.phase_changed.disconnect(rec)
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)


func _test_dummy_damage() -> void:
	print("damage on the straw dummy")
	var w := await _use("spear")
	var dummy: TargetDummy = null
	for d in current_scene.find_children("*", "TargetDummy", true, false):
		var td := d as TargetDummy
		if td.move_offset == Vector3.ZERO and absf(td.global_position.z + 30.0) < 0.5:
			dummy = td
	_expect(dummy != null, "10 m dummy found")
	if dummy == null:
		return
	var base := dummy.global_position
	# Torso: damage x speed falloff, x1.
	var h0 := dummy.health
	var stand := Vector3(base.x, _ground_at(base.x, base.z + 8.0), base.z + 8.0)
	var r: Array = await _throw_at(w, stand, base + Vector3(0, 1.2, 0))
	var p: ThrownProjectile = r[0]
	var rec: Dictionary = r[1]
	await _wait_rest(p)
	var dealt := h0 - dummy.health
	_expect(not rec.is_empty() and rec.stuck and _dummy_of(rec.collider) == dummy and absf(dealt - _expected(rec)) < 0.01,
			"torso: sticks and deals %.2f = damage %.1f x falloff (expected %.2f)" % [dealt, rec.get("damage", 0.0),
			_expected(rec) if not rec.is_empty() else 0.0])
	_expect(rec.get("surface", "") == "straw", "the dummy reads as straw (%s)" % rec.get("surface", "?"))
	_expect(float(rec.get("damage", 0.0)) > w.min_damage + 0.5 * (w.max_damage - w.min_damage), "full wind-up: near max damage (%.1f)" % rec.get("damage", 0.0))
	await _settle_next(w)
	# Head: x2 (hit_part "head", damage_mult 2).
	h0 = dummy.health
	r = await _throw_at(w, stand, base + Vector3(0, 1.68, 0))
	var ph: ThrownProjectile = r[0]
	var rh: Dictionary = r[1]
	await _wait_rest(ph)
	dealt = h0 - dummy.health
	var head_node := rh.get("collider") as Node
	var head: bool = head_node != null and head_node.get_meta("hit_part", "") == "head"
	_expect(head and absf(dealt - 2.0 * _expected(rh)) < 0.01,
			"head: deals %.2f = 2 x %.2f" % [dealt, _expected(rh) if not rh.is_empty() else 0.0])
	for q in [p, ph]:
		await _pick_up(q)
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back from the dummy")


func _test_wood_and_stone() -> void:
	print("wood and stone")
	var w := await _use("spear")
	var wood := _board(10.0, -32.0, "wood")
	var stand := Vector3(10.0, _ground_at(10.0, -22.0), -22.0)
	var r: Array = await _throw_at(w, stand, wood.global_position + Vector3(0, -0.4, 0))
	var p: ThrownProjectile = r[0]
	var rec: Dictionary = r[1]
	var phase := await _wait_rest(p)
	var hl: Array = wood.get("hit_log")
	_expect(phase == ThrownProjectile.Phase.STUCK and rec.get("collider") == wood and p.get_parent() == wood,
			"sticks in a wooden board and hangs from it")
	_expect(hl.size() == 1 and absf(float(hl[0].damage) - _expected(rec)) < 0.01 and hl[0].source == player
			and hl[0].part == "body", "wood board: one Hit.deliver of %.2f from the player" % (float(hl[0].damage) if hl.size() else -1.0))
	if phase == ThrownProjectile.Phase.STUCK:
		var nose := -p.global_basis.z
		var depth := wood.global_position.z + 0.15 - p.tip_position().z
		_expect(nose.dot(Vector3.FORWARD) > 0.9 and absf(depth - p.depth_for("wood") * nose.dot(Vector3.FORWARD)) < 0.01
				and p.depth_for("wood") < p.depth_for("straw"),
				"point first, %.3f m into the wood (straw %.2f m)" % [depth, p.depth_for("straw")])
	await _settle_next(w)
	var stone := _board(13.5, -32.0, "stone")
	stand = Vector3(13.5, _ground_at(13.5, -24.0), -24.0)
	r = await _throw_at(w, stand, stone.global_position + Vector3(0, -0.4, 0))
	var ps: ThrownProjectile = r[0]
	var rs: Dictionary = r[1]
	phase = await _wait_rest(ps, 900)
	hl = stone.get("hit_log")
	_expect(not rs.is_empty() and not rs.stuck and rs.get("surface", "") == "stone", "stone never holds a spear: it skips off")
	_expect(hl.size() == 1 and absf(float(hl[0].damage) - _expected(rs)) < 0.01 and float(hl[0].damage) <= rs.blunt,
			"stone: blunt damage only (%.2f of %.0f)" % [float(hl[0].damage) if hl.size() else -1.0, rs.get("blunt", 0.0)])
	_expect(phase == ThrownProjectile.Phase.LYING and ps.global_position.y < 0.3 + _ground_at(ps.global_position.x, ps.global_position.z),
			"it comes to rest lying on the ground")
	for q in [p, ps]:
		_expect(await _pick_up(q), "picked up again")
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)


## A real tree trunk of the forest (group "trees", reads as wood).
func _test_tree() -> void:
	print("tree")
	var w := await _use("spear")
	var pick := _find_tree()
	_expect(not pick.is_empty(), "a tree with a clear throw found")
	if pick.is_empty():
		return
	var r: Array = await _throw_at(w, pick.stand, pick.aim)
	var p: ThrownProjectile = r[0]
	var rec: Dictionary = r[1]
	var phase := await _wait_rest(p)
	var body := rec.get("collider") as Node
	_expect(phase == ThrownProjectile.Phase.STUCK and body and body.is_in_group(&"trees") and rec.get("surface", "") == "wood",
			"sticks in a tree trunk (%s, %s)" % [body.name if body else "nothing", rec.get("surface", "?")])
	_expect(await _pick_up(p), "pulled out of the tree again")
	await _frames(int(w.draw_time * 120) + 10)


func _test_ground_lob() -> void:
	print("ground")
	var w := await _use("spear")
	var x := -1.25                    # Between the 10 m and 25 m lanes, clear of the dummies.
	var stand := Vector3(x, _ground_at(x, -21.0), -21.0)
	var target := Vector3(x, _ground_at(x, -57.0), -57.0)
	await _stand_and_aim(stand, target)
	var p := await _full_throw()
	_expect(p != null, "lobbed a spear 36 m down the lane")
	if p == null:
		return
	var rec := _record(p)
	await _frames(40)
	var along := (-p.global_basis.z).dot(p.velocity.normalized()) if p.phase == ThrownProjectile.Phase.FLYING else 0.0
	_expect(along > 0.9999, "in flight it points along its velocity (%.5f)" % along)
	var phase := await _wait_rest(p)
	_expect(phase == ThrownProjectile.Phase.STUCK and rec.get("surface", "") in ["dirt", "grass"],
			"it sticks in the ground at the end of a lob (%s)" % rec.get("surface", "?"))
	if phase == ThrownProjectile.Phase.STUCK:
		var g := _ground_at(p.tip_position().x, p.tip_position().z)
		_expect(p.tip_position().y < g and p.tail_position().y > g + 0.3, "point in the ground, butt up")
	_expect(await _pick_up(p), "pulled out of the ground")
	await _frames(int(w.draw_time * 120) + 10)


func _test_tomahawk_wood() -> void:
	print("tomahawk on wood")
	var w := await _use("tomahawk") as ThrowableTomahawk
	var wood := _board(10.0, -32.0, "wood")
	var stand := Vector3(10.0, _ground_at(10.0, -26.5), -26.5)
	await _stand_and_aim(stand, wood.global_position + Vector3(0, -0.3, 0))
	var p := await _full_throw()
	_expect(p != null and p.flight == ThrownProjectile.Flight.SPINNING, "tomahawk thrown, spinning")
	if p == null:
		return
	var rec := _record(p)
	# Measure the spin: the blade's turn about the model X per physics step.
	await _frames(1)
	var b0 := p.global_basis.orthonormalized()
	await _frames(6)
	var turned := 0.0
	if p.phase == ThrownProjectile.Phase.FLYING:
		var b1 := p.global_basis.orthonormalized()
		turned = (b0.inverse() * b1).get_rotation_quaternion().get_angle()
	var expect := absf(p.spin_rate) * 6.0 * DT
	_expect(absf(turned - expect) < 0.02 * expect + 0.01, "spins end over end at spin_rate (%.3f of %.3f rad in 6 steps)" % [turned, expect])
	var phase := await _wait_rest(p)
	var hl: Array = wood.get("hit_log")
	_expect(phase == ThrownProjectile.Phase.STUCK and (-p.global_basis.z).dot(Vector3.FORWARD) > cos(deg_to_rad(55.0)),
			"sticks blade first in the wood")
	_expect(hl.size() == 1 and rec.get("stuck", false) and absf(float(hl[0].damage) - _expected(rec)) < 0.01,
			"tomahawk: edge damage %.2f" % (float(hl[0].damage) if hl.size() else -1.0))
	_expect(await _pick_up(p), "tomahawk pulled out of the wood")
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)


func _test_removed_target() -> void:
	print("removed target")
	var w := await _use("spear")
	var wood := _board(10.0, -32.0, "wood")
	var stand := Vector3(10.0, _ground_at(10.0, -24.0), -24.0)
	var r: Array = await _throw_at(w, stand, wood.global_position + Vector3(0, 0.2, 0))
	var p: ThrownProjectile = r[0]
	var phase := await _wait_rest(p)
	_expect(phase == ThrownProjectile.Phase.STUCK and p.get_parent() == wood, "stuck in the board")
	var before := _spears_in_world()
	_clear_boards()
	await _frames(10)
	var copy: ThrownProjectile = null
	for q: ThrownProjectile in _spears_in_world():
		if not before.has(q):
			copy = q
	_expect(not is_instance_valid(p) and copy != null and copy.phase == ThrownProjectile.Phase.LYING and copy.kind == "spear",
			"the board is gone; its spear dropped to the ground as a pickup")
	if copy:
		_expect(absf(copy.global_position.x - 10.0) < 1.5 and copy.global_position.y < _ground_at(copy.global_position.x, copy.global_position.z) + 0.3,
				"lying below where it was stuck")
		await _frames(70)
		_expect(await _pick_up(copy), "the dropped spear is picked up")
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back (%d)" % w.count)


func _thrown_in_world() -> Array:
	var out: Array = []
	for n in current_scene.find_children("*", "ThrownProjectile", true, false):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _spears_in_world() -> Array:
	var out: Array = []
	for n in current_scene.find_children("*", "ThrownProjectile", true, false):
		if not n.is_queued_for_deletion():
			out.append(n)
	return out


func _test_pickup_key() -> void:
	print("pickup key")
	ThrownPickup.ensure_input()
	_expect(InputMap.has_action(&"interact"), "the interact action exists (E)")
	var w := await _use("spear")
	var wood := _board(10.0, -32.0, "wood", 1.6, 4.0)
	var stand := Vector3(10.0, _ground_at(10.0, -24.0), -24.0)
	var g := _ground_at(10.0, -31.0)
	# Stuck high: out of walking reach, inside the key's reach.
	var r: Array = await _throw_at(w, stand, Vector3(10.0, g + 2.65, wood.global_position.z))
	var p: ThrownProjectile = r[0]
	await _wait_rest(p)
	var mid := (p.tip_position() + p.tail_position()) * 0.5
	player.global_position = Vector3(mid.x + 0.3, g + 0.3, mid.z)
	player.velocity = Vector3.ZERO
	await _frames(90)
	var reach := p.pickup.distance_from(player.global_position + Vector3.UP * 0.9) if is_instance_valid(p) and p.pickup else -1.0
	_expect(is_instance_valid(p) and w.count == 1 and reach > p.pickup.radius and reach < p.pickup.interact_radius,
			"stuck %.2f m from the chest: walking under it does not take it" % reach)
	var near := ThrownPickup.nearest_for(player)
	_expect(near != null and near == p.pickup and "pick up Throwing Spear" in near.prompt(player),
			"HUD prompt: \"%s\"" % (near.prompt(player) if near else ""))
	_face(mid)
	Input.action_press(&"interact")
	await _frames(20)
	Input.action_release(&"interact")
	await _frames(2)
	_expect(not is_instance_valid(p) or p.is_queued_for_deletion(), "E takes it down")
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spear count back to 2")
	# require_interact: walking over it is not enough.
	r = await _throw_at(w, stand, wood.global_position + Vector3(0, -0.6, 0))
	var q: ThrownProjectile = r[0]
	await _wait_rest(q)
	q.pickup.require_interact = true
	var at := q.global_position
	player.global_position = Vector3(at.x + 0.4, _ground_at(at.x, at.z) + 0.3, at.z + 0.5)
	await _frames(90)
	_expect(is_instance_valid(q) and not q.is_queued_for_deletion(), "require_interact: walking into it does not take it")
	_face(at)
	Input.action_press(&"interact")
	await _frames(3)
	Input.action_release(&"interact")
	await _frames(20)
	_expect(not is_instance_valid(q) or q.is_queued_for_deletion(), "a tap of E does")
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)


func _test_pipe_variant() -> void:
	print("pipe tomahawk")
	var keys: Array[String] = ["tomahawk_pipe"]
	var extra := ThrowableKit.install(player, keys)
	var pw := extra.get("tomahawk_pipe") as ThrowableTomahawk
	_expect(pw != null and pw.pipe and pw.display_name == "Pipe Tomahawk" and pw.ammo_kind == "tomahawk"
			and pw.model_kind == "tomahawk_pipe", "ThrowableKit.create(\"tomahawk_pipe\") makes the pipe variant")
	if pw == null:
		return
	var trade := kit["tomahawk"] as ThrowableTomahawk
	_expect(trade.display_name == "Tomahawk" and trade.model_kind == "tomahawk", "the default tomahawk is the trade (spike) tomahawk")
	_expect(pw.model.get_node_or_null("Mouthpiece") is Marker3D and pw.model.get_node_or_null("TomahawkPipe") != null
			and pw.model.get_node_or_null("Tomahawk") == null, "the pipe model has its bowl mesh and mouthpiece")
	pw.use_scripted_input = true
	_no_spread(pw)
	kit["tomahawk_pipe"] = pw
	var w := await _use("tomahawk_pipe")
	var wood := _board(10.0, -32.0, "wood")
	var r: Array = await _throw_at(w, Vector3(10.0, _ground_at(10.0, -27.0), -27.0), wood.global_position + Vector3(0, -0.3, 0))
	var p: ThrownProjectile = r[0]
	var phase := await _wait_rest(p)
	_expect(phase == ThrownProjectile.Phase.STUCK and p.model_kind == "tomahawk_pipe"
			and p.find_child("Mouthpiece", true, false) != null, "the pipe tomahawk flies and sticks as itself")
	trade.count = 1                     # Both have room: it must go back to the pipe tomahawk.
	_expect(await _pick_up(p), "picked up")
	_expect(pw.count == 2 and trade.count == 1, "it goes back to the pipe tomahawk (pipe %d, trade %d)" % [pw.count, trade.count])
	trade.count = 2
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)


func _test_anim_release_event() -> void:
	print("animation release event")
	var w := await _use("spear")
	var was_waiting := w.wait_for_anim_release
	w.wait_for_anim_release = true
	# The player's animation lets go on the throw's release frame (THROW); this checks the weapon's
	# own contract, so the animation only reports the frame here.
	player.anim.drive_throw_release = false
	var wood := _board(10.0, -32.0, "wood")
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -24.0), -24.0), wood.global_position + Vector3(-0.3, 0, 0))
	_fire(true)
	for i in 240:
		await _frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	var before := w.last_thrown
	_fire(false)
	await _frames(int((w.release_time + 0.1) * 120))
	_expect(w.state == Throwable.State.RELEASING and w.last_thrown == before, "waits for the animation past release_time")
	w.release_from_animation()
	await _frames(1)
	var p1 := w.last_thrown
	_expect(p1 != before and w.state == Throwable.State.RECOVER, "release_from_animation() lets go on that tick")
	await _settle_next(w)
	await _stand_and_aim(Vector3(10.0, _ground_at(10.0, -24.0), -24.0), wood.global_position + Vector3(0.3, 0, 0))
	_fire(true)
	for i in 240:
		await _frames(1)
		if w.state == Throwable.State.HOLDING:
			break
	before = w.last_thrown
	_fire(false)
	var ticks := 0
	for i in 120:
		await _frames(1)
		ticks += 1
		if w.last_thrown != before:
			break
	var t := ticks * DT
	_expect(w.last_thrown != before and absf(t - (w.release_time + w.anim_release_timeout)) < 3.5 * DT,
			"no event: the timer lets go after release_time + anim_release_timeout (%.3f s)" % t)
	w.wait_for_anim_release = was_waiting
	player.anim.drive_throw_release = true
	var p2 := w.last_thrown
	for q in [p1, p2]:
		await _wait_rest(q)
		await _pick_up(q)
	_clear_boards()
	await _frames(int(w.draw_time * 120) + 10)
	_expect(w.count == 2, "spears back (%d)" % w.count)


func _test_unequip_mid_windup() -> void:
	print("unequip mid-wind-up")
	var w := await _use("spear")
	var cancelled := [0]
	var on_cancel := func() -> void: cancelled[0] += 1
	w.action_cancelled.connect(on_cancel)
	var before := w.last_thrown
	_fire(true)
	await _frames(30)
	_expect(w.is_winding(), "winding up")
	w.unequip()
	await _frames(5)
	_expect(w.state == Throwable.State.READY and w.count == 2 and w.last_thrown == before and cancelled[0] >= 1
			and not w.model.visible, "switching away keeps the spear, nothing thrown, the action is cancelled")
	w.action_cancelled.disconnect(on_cancel)
	_fire(false)
	w.equip()
	await _frames(int(w.equip_time * 120) + 10)
	_expect(w.state == Throwable.State.READY and w.model.visible, "equipped again, ready")


func _test_audio(audio: ThrowableAudio) -> void:
	print("audio")
	_expect(audio != null, "ThrowableAudio installed on the player")
	for c: String in ["windup:spear", "release:spear", "draw_spear:spear", "cancel:spear", "pickup:spear",
			"equip:spear", "empty:spear", "release:tomahawk", "draw_tomahawk:tomahawk"]:
		var n := int(cues.get(c, 0))
		if c == "equip:spear":
			# In the roster the switch sound is WeaponAudio's spear_equip (THROW; design 4.5).
			n += int(cues.get("equip_switch:spear", 0))
		_expect(n > 0, "cue %s played (%d)" % [c, n])
	_expect(scares == 0, "throws never startle the birds (%d scares)" % scares)
