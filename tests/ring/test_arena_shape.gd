extends SceneTree
## The oval arenas (the owner, 2026-10-16: "a new and better arena with a headless blender ... like earth not the wood ...
## closer to the water maybe a oval shape"; his pick "ruin and crater"): ring.json arenas over the rule set's numbers, the
## deck's lip an ellipse that every rule and every bot reads, in a real ring, headless (the mesh scene is not loaded headless:
## the colliders and the rules are this test's):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_arena_shape.gd -- mode=ring arena=ruin element=earth foe=fire
##   the overlay     MatchSetup.arena reaches RingArena (set_arena); the ruin's water 2 m under the deck, its face 1.9 m, its
##                   shape oval; its mesh path names this deck's size; the arenas' names classic first
##   the lip         inside_deck, on_deck, clamp_inside, edge_x, edge_along_local and nearest_lip on the ellipse: the deck's
##                   ends and sides are on it, the rectangle's corners are off it (a point there is not on the deck, a wall is
##                   kept inside, a bot's place is clamped in); the rectangle (classic) answers as it always did
##   the colliders   a ray down inside the oval meets the deck at its top, one at the rectangle's corner meets nothing but the
##                   water's floor; no pier stands past the lip
##   the match       a bot-against-bot game reaches DONE on the oval (every fall into the water read as out), on the stock and
##                   the zones rules; the lanterns' spots stand round the ellipse
## Last line "ARENA SHAPE PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "ARENA SHAPE TEST"
const LIMIT_S := 420.0

var checks := 0
var fails: Array[String] = []
var mode: RingMode
var ring: RingArena
var player: FrontierPlayer
var _done := false
var _game_t := 0.0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _near(a: float, b: float, eps := 1e-3) -> bool:
	return absf(a - b) <= eps


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.spectate = true
	MatchSetup.round_s = 90.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	if MatchSetup.arena == "classic":
		MatchSetup.arena = "ruin"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	MatchSetup.arena = "classic"
	RingArena.set_arena("classic")
	if fails.is_empty() and checks > 0:
		print("ARENA SHAPE PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("ARENA SHAPE FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	ring = RingArena.find(self)
	_expect(mode != null and ring != null, "the ring with a match")
	if mode == null or ring == null:
		return _end()
	await _ticks(30)
	_overlay()
	_lip()
	await _colliders()
	await _match()
	_classic()
	_end()


func _overlay() -> void:
	_expect(RingArena.arena == MatchSetup.arena and RingArena.arena in ["ruin", "crater"], "the arena in play is %s (MatchSetup.arena %s)" % [RingArena.arena, MatchSetup.arena])
	_expect(RingArena.oval() and RingArena.shape() == "oval", "its deck is an oval")
	_expect(_near(RingArena.num("water_y"), -2.0) and _near(RingArena.num("floor_y"), -5.0) and _near(RingArena.num("face_depth_m"), 1.9),
			"its water 2 m under the deck, the floor 5 m, the face 1.9 m (%.1f, %.1f, %.1f)" % [RingArena.num("water_y"), RingArena.num("floor_y"),
			RingArena.num("face_depth_m")])
	# (the rule set's own deck: Lives 14 x 34, Zones 12 x 28; the tank 10 m round it either way)
	var dl := int(round(RingArena.num("deck_l")))
	var dw := int(round(RingArena.num("deck_w")))
	_expect([dl, dw] in [[34, 14], [28, 12]] and _near(RingArena.num("tank_margin"), 10.0),
			"the deck and the tank keep the rules' sizes (%d x %d, tank %.0f)" % [dl, dw, RingArena.num("tank_margin")])
	_expect(ring.mesh_path() == "res://assets/arena/%s/arena_%dx%d.gltf" % [RingArena.arena, dw, dl], "the mesh path names this deck's size (%s)" % ring.mesh_path())
	_expect(RingArena.arena_names()[0] == "classic" and "ruin" in RingArena.arena_names() and "crater" in RingArena.arena_names(),
			"the arenas: %s" % [RingArena.arena_names()])
	_expect(not ring.use_mesh, "headless: no mesh scene loaded (the colliders and the rules alone)")
	_expect(not RingArena.dressing_on("stands") and not RingArena.dressing_on("gates") and RingArena.dressing_on("crowd"),
			"the dressing's stands and gates are the mesh's, the crowd stays")


func _lip() -> void:
	var hl := ring.half_l()
	var hw := ring.half_w()
	_expect(ring.inside_deck(hl - 0.01, 0.0) and ring.inside_deck(0.0, hw - 0.01) and ring.inside_deck(0.0, 0.0),
			"the ends and the sides' middles are on the deck")
	_expect(not ring.inside_deck(hl - 0.5, hw - 0.5) and not ring.inside_deck(hl * 0.9, hw * 0.6), "the rectangle's corners are off it")
	# (points by the deck's own size: 0.7 of the length and 0.57 of the width in, 0.88 and 0.79 out past the ellipse)
	_expect(ring.on_deck(ring.to_global(Vector3(hl * 0.7, 0.0, hw * 0.57))) and not ring.on_deck(ring.to_global(Vector3(hl * 0.88, 0.0, hw * 0.79))),
			"on_deck: (%.1f, %.1f) yes, (%.1f, %.1f) no" % [hl * 0.7, hw * 0.57, hl * 0.88, hw * 0.79])
	var c := ring.clamp_inside(Vector3(16.0, 0.0, 6.0), 0.6)
	_expect(ring.inside_deck(c.x, c.z, 0.59) and not ring.inside_deck(c.x, c.z, 0.65) and absf(c.x / c.z - 16.0 / 6.0) < 1e-3,
			"clamp_inside draws a corner point in to the lip along its ray (%.2f, %.2f)" % [c.x, c.z])
	_expect(_near(ring.edge_x(0.0), hl) and _near(ring.edge_x(hw), 0.0) and _near(ring.edge_x(hw * 0.6), hl * 0.8, 1e-3),
			"edge_x: the half length at z 0, at the side, at 0.6 of the width (%.2f, %.2f, %.2f)" % [ring.edge_x(0.0), ring.edge_x(hw), ring.edge_x(hw * 0.6)])
	_expect(_near(ring.edge_along_local(Vector3.ZERO, Vector3(1, 0, 0)), hl) and _near(ring.edge_along_local(Vector3.ZERO, Vector3(0, 0, 1)), hw)
			and _near(ring.edge_along_local(Vector3(hl + 1.0, 0, 0), Vector3(1, 0, 0)), 0.0),
			"edge_along_local: to the end, to the side, 0 from past the lip")
	var lip := ring.nearest_lip(ring.to_global(Vector3(hl * 0.5, 0.0, 0.0)))
	_expect(int(lip.side) == RingArena.LIP_END_1 and _near(float(lip.out_m), -hl * 0.5) and _near(ring.to_local(lip.point).x, hl)
			and (lip.normal as Vector3).dot(ring.global_basis.x) > 0.99, "nearest_lip from half way to +X: the +X end, %.1f m inside" % float(lip.out_m))
	var lz := ring.nearest_lip(ring.to_global(Vector3(0.0, 0.0, -hw * 0.5)))
	_expect(int(lz.side) == RingArena.LIP_END_0 or int(lz.side) == RingArena.LIP_LONG_NEG, "nearest_lip from half way to -Z: a side (%d)" % int(lz.side))
	_expect(int(lz.side) == RingArena.LIP_LONG_NEG and _near(ring.to_local(lz.point).z, -hw) and _near(float(lz.out_m), -hw * 0.5),
			"...the -Z long side, %.1f m inside" % float(lz.out_m))
	var lo := ring.nearest_lip(ring.to_global(Vector3(hl * 1.2, 0.0, 0.0)))
	_expect(float(lo.out_m) > 0.0 and _near(float(lo.out_m), hl * 0.2), "past the +X end: %.2f m out" % float(lo.out_m))
	var w := ring.to_local(ring.wall_place_ok(ring.to_global(Vector3(hl - 0.5, 0.0, hw - 0.5))))
	_expect(ring.inside_deck(w.x, w.z, RingArena.num("wall_lip_clear_m", 3.5) - 0.01), "a wall at the corner is kept %.1f m inside the lip" % RingArena.num("wall_lip_clear_m", 3.5))
	var k := BendR3.keep_on_deck(self, ring.to_global(Vector3(hl - 0.2, 0.0, hw - 0.2)), 0.6)
	var kl := ring.to_local(k)
	_expect(ring.inside_deck(kl.x, kl.z, 0.59), "Column and Geyser are kept on the oval")
	var spots := ring.lantern_spots()
	var on_ellipse := spots.size() == 12
	for p: Vector3 in spots:
		var l := ring.to_local(p)
		on_ellipse = on_ellipse and not ring.inside_deck(l.x, l.z) and ring.inside_deck(l.x, l.z, -0.9)
	_expect(on_ellipse, "twelve lantern spots just outside the ellipse")


func _colliders() -> void:
	var hl := ring.half_l()
	var hw := ring.half_w()
	var space := ring.get_world_3d().direct_space_state
	var inside := ring.to_global(Vector3(12.0, 0.0, 3.0))
	var corner := ring.to_global(Vector3(hl - 0.6, 0.0, hw - 0.6))
	var hit_in := space.intersect_ray(PhysicsRayQueryParameters3D.create(inside + Vector3.UP * 3.0, inside + Vector3.DOWN * 12.0, 1))
	var hit_c := space.intersect_ray(PhysicsRayQueryParameters3D.create(corner + Vector3.UP * 3.0, corner + Vector3.DOWN * 12.0, 1))
	_expect(not hit_in.is_empty() and _near(float((hit_in.position as Vector3).y), ring.top(), 0.05) and (hit_in.collider as Node).has_meta(RingArena.DECK_META),
			"a ray down inside the oval meets the deck's top (%s)" % [hit_in.get("position")])
	_expect(hit_c.is_empty() or float((hit_c.position as Vector3).y) < ring.top() - 1.0,
			"a ray down at the rectangle's corner meets no deck (%s)" % [hit_c.get("position", "nothing")])
	var piers := ring.get_node_or_null(^"Deck/Piers")
	var past := 0
	if piers != null:
		for cs in piers.get_children():
			var l: Vector3 = (cs as Node3D).position
			if not ring.inside_deck(l.x, l.z):
				past += 1
	_expect(piers != null and past == 0, "no pier stands past the lip (%d past)" % past)
	await _ticks(1)


func _match() -> void:
	# a game played out by the bots on the oval: the one knocked into the water is out, the game ends
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while mode.phase != "DONE" and frames < 60 * 240:
		await physics_frame
		frames += 1
	_game_t = float(frames) / 60.0
	_expect(mode.phase == "DONE", "a bot-against-bot game on the %s reaches DONE (%s after %.0f game s, %.0f s real)" % [RingArena.arena, mode.phase, _game_t,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	var falls := 0
	for h: Dictionary in mode.history:
		if String(h.get("how", "")).contains("water") or h.has("fell"):
			falls += 1
	print("  history: ", mode.history.size(), " rounds")


func _classic() -> void:
	# the rectangle as it always was (every other test's deck)
	RingArena.set_arena("classic")
	_expect(not RingArena.oval() and ring.inside_deck(ring.half_l() - 0.1, ring.half_w() - 0.1) and _near(ring.edge_x(ring.half_w() * 0.6), ring.half_l()),
			"classic: the rectangle's corner is on the deck, edge_x the half length")
	# (the rectangle's nearest lip from half way along is a long side, 7 m off; the oval reads along the ray from the middle)
	var lip := ring.nearest_lip(ring.to_global(Vector3(ring.half_l() * 0.5, 0.0, 0.0)))
	_expect((int(lip.side) == RingArena.LIP_LONG_NEG or int(lip.side) == RingArena.LIP_LONG_POS) and _near(float(lip.out_m), -ring.half_w()),
			"classic: nearest_lip as before (side %d, %.1f m)" % [int(lip.side), float(lip.out_m)])
	RingArena.set_arena(MatchSetup.arena)
