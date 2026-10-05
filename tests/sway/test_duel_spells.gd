extends SceneTree
## The duel's spells as the user asked for them (2026-10-04): Stone Form aimed once ("its hard to aim the stone spike": its
## lock at the caster like the pillar's self mode, no range; the throw's aim help on a fighter near the crosshair), and Gust
## tearing a piece out of a raised wall or pillar and hurling it ("use gust to push certain parts of the rock wall and
## pillar"). On the real level, in the duel.
##   Godot --headless --fixed-fps 60 --path . -s tests/sway/test_duel_spells.gd -- mode=duel

var fails := 0


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _go() -> void:
	for i in 20:
		await process_frame
	var p := current_scene.get_node_or_null("Player") as FrontierPlayer
	var duel := DuelMode.find(self)
	var c := SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null, "the duel, its player and his caster")
	if c == null:
		return _end()
	p.collision_layer = 0
	await _secs(DuelMode.COUNTDOWN_S + 1.0)
	var n := duel.npc
	n.held = true                                  # (he stands for the test)
	# --- Stone Form: aimed once, at the caster
	_expect(c._self_cast("stone_form") and c._self_cast("pillar") == (c.mode_of("pillar") == "self"),
			"Stone Form locks at the caster (no range), as the pillar's self mode")
	var fc: FormCast = c.form
	var pk := fc.pick("stone_form", {})
	var foot := fc.self_point("stone_form")
	_expect(bool(pk.get("self", false)) and NpcBrain._flat(foot, p.global_position) < 2.5,
			"its circle before the caster's feet (%.1f m off), whatever the aim" % NpcBrain._flat(foot, p.global_position))
	# --- the aim's help: a fighter a little off the crosshair is taken, one well off is not (he is set in the open 9 m off,
	# the way the player looks, to the side of the wall raised below)
	var look := -p.global_basis.z
	look.y = 0.0
	look = look.normalized().rotated(Vector3.UP, deg_to_rad(-40.0))
	var spot := p.global_position + look * 9.0
	n.global_position = Vector3(spot.x, FrontierTerrain.height_at(spot.x, spot.z) + 0.05, spot.z)
	await _secs(0.3)
	var eye := p.global_position + Vector3.UP * 1.6
	var to := NpcSenses.chest_of(n) - eye
	var side := to.cross(Vector3.UP).normalized()
	var near := to.rotated(Vector3.UP, deg_to_rad(4.0)).normalized()
	var far := to.rotated(Vector3.UP, deg_to_rad(15.0)).normalized()
	var clear := get_root().get_world_3d() != null
	var a_near := FormEffects.assist_target(c, eye, near)
	var a_far := FormEffects.assist_target(c, eye, far)
	# (he may stand behind a crate from the spawn: the help only takes a fighter in plain sight)
	var seen := (p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + to, 1, [p.get_rid(), n.get_rid()]))).is_empty()
	if seen:
		_expect(a_near == n and a_far == null, "the aim's help: 4 deg off takes him, 15 deg off does not (%s, %s)" % [a_near, a_far])
		# (the setting: light takes him only right by the crosshair, off never; the owner, 2026-10-05: "the auto aim is to strong")
		MatchSetup._aim_help = "light"
		var pbc := BendCaster.wrap(c)
		var l_4 := pbc.assist_target(eye, near)
		var l_1 := pbc.assist_target(eye, to.rotated(Vector3.UP, deg_to_rad(1.0)).normalized())
		MatchSetup._aim_help = "off"
		var o_1 := pbc.assist_target(eye, to.rotated(Vector3.UP, deg_to_rad(1.0)).normalized())
		MatchSetup._aim_help = "strong"
		_expect(l_4 == null and l_1 == n and o_1 == null, "aim help light: 4 deg off not taken, 1 deg off taken; off: never (%s, %s, %s)" % [l_4, l_1, o_1])
	else:
		_expect(a_near == null, "the aim's help: he is behind cover from here, not taken")
	# --- Gust on an Earth Wall: a piece torn out and hurled through it
	var way := -p.global_basis.z
	way.y = 0.0
	way = way.normalized()
	var w := FormEffects.earth_wall(c, p.global_position + way * 3.0, SwayMoves.move("earth_wall"))
	await _secs(1.5)
	_expect(w != null and w.is_up(), "an Earth Wall raised 3 m before him")
	var hit_at := w.global_position + Vector3.UP * 1.0 - way * (w.size.z * 0.5)
	_expect(c.kind_of(w) == "raised" and "raised" in (SwayMoves.move("gust").get("targets", []) as Array), "Gust takes a raised wall")
	var hits0 := w.hits
	SwayEffects.gust(c, w, hit_at)
	var stones := get_nodes_in_group(FormStone.GROUP)
	var chunk: FormStone = null
	for s in stones:
		if (s as FormStone).kind == "cannonball" and (s as Node3D).global_position.distance_to(hit_at) < 1.0:
			chunk = s
	_expect(chunk != null and w.hits == hits0 + 1, "a ball of %s torn out where the aim was, the wall a hit the worse (%d)" % [w.matter, w.hits])
	await _secs(0.6)
	if chunk != null and is_instance_valid(chunk):
		var past := (chunk.global_position - w.global_position).dot(way)
		_expect(past > 2.0, "hurled on through the wall along the aim (%.1f m past it)" % past)
	print("DUEL SPELLS " + ("PASSED" if fails == 0 else "FAILED"))
	_end()


func _end() -> void:
	quit(0 if fails == 0 else 1)
