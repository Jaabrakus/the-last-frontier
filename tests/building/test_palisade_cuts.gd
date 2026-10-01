extends SceneTree
## Windows cut in the BUILT palisade (PalisadeCuts; user 2026-09-28: the fort is built from pieces, windows are cut in
## pieces "from belly height up, measured from where the player stands"), without the level (a bare scene with a BuildWorld,
## one palisade section and rays for the aim):
##   * the first cut's base is the feet's height + 1.0 m; from the ground a piece is two stakes wide and 1.0 m tall and each
##     further cut takes the next piece up (the third takes the top off); nothing below belly height is a target
##   * from the firing step's deck (top 2.275 m) the first cut takes everything from belly height to the top in one go, over
##     the collider's top too (the crosshair is above it from the deck)
##   * halfway up a ramp the base rises with the feet
##   * a cut opens the collider (a ray passes it, beside and over it still stops) and shows the stakes as pieces
##   * the WORK strokes of the axe cut a piece; the cuts are saved with the building and come back (SaveParts)
##   * an opening can be filled in again: repaired (stakes stand) or covered (logs across it, the collider closes);
##     cutting into a cover knocks it out
##
##   Godot --headless --fixed-fps 120 --path . -s tests/building/test_palisade_cuts.gd
## "PALISADE CUTS TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var world: BuildWorld
var sec: BuiltPiece
var scene: Node3D


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


## The section at the origin, its outside toward -Z (yaw 180: the inside, where the player stands, is +Z), flat ground.
func _make() -> BuiltPiece:
	for q in world.pieces():
		world.remove_piece(q)
	var g := PackedFloat32Array()
	for i in BuildGeometry.STAKES:
		g.append(0.0)
	return world.add_piece("palisade", Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), true, -1, g)


## The aim of a player standing at (x, feet, 1.0) looking -Z at height `y` on the wall (pair k's middle).
func _aim(k: int, y: float, feet: float) -> Dictionary:
	var xr := PalisadeCuts.x_range(k)
	# (the section is turned about Y: its local +X is world -X)
	var wx := -0.5 * (xr.x + xr.y)
	var eye := Vector3(wx, y, 1.6)
	return PalisadeCuts.aim(world, eye, Vector3(0, 0, -1), Vector3(wx, feet, 1.0))


func _ray_stops(k: int, y: float) -> bool:
	var xr := PalisadeCuts.x_range(k)
	var wx := -0.5 * (xr.x + xr.y)
	var q := PhysicsRayQueryParameters3D.create(Vector3(wx, y, 1.0), Vector3(wx, y, -1.0))
	return not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _stroke(c: Dictionary) -> void:
	var done := 0.0
	var n := 0
	while done < 1.0 and n < 100:
		done = PalisadeCuts.strike(world, c, 1.0)
		n += 1


func _initialize() -> void:
	await process_frame          # (the root is in the tree from the first frame)
	scene = Node3D.new()
	scene.name = "Level"
	root.add_child(scene)
	current_scene = scene
	world = BuildWorld.of(self)
	sec = _make()
	await _ticks(4)

	# --- anywhere (user 2026-09-30, "no rules"): the 1.0 m piece round the crosshair's height, any height, any order ---
	var c1 := _aim(1, 1.6, 0.0)
	_check(not c1.is_empty() and absf(float(c1.h0) - 1.1) < 0.001 and absf(float(c1.h1) - 2.1) < 0.001 and int(c1.k) == 1,
			"the piece round the crosshair (1.6 m) is 1.1 - 2.1 m (%s)" % str([c1.get("h0"), c1.get("h1")]))
	_check(not c1.is_empty() and str(c1.name) == "palisade" and str(c1.type) == "wall", "it is the gathering target 'wall' named palisade")
	_check(PalisadeCuts.WORK == 8.0 and PalisadeCuts.PIECE_H == 1.0, "constants: 8 strokes, 1.0 m pieces")
	var d1 := PalisadeCuts.describe(world, str(c1.key), Vector3(-0.5 * (PalisadeCuts.x_range(1).x + PalisadeCuts.x_range(1).y), 0.0, 1.0))
	_check(not d1.is_empty() and str(d1.key) == str(c1.key), "the target key describes it again")
	# strokes
	for i in 7:
		PalisadeCuts.strike(world, c1, 1.0)
	_check(sec.cuts.is_empty() and PalisadeCuts.progress(world, str(c1.key)) > 0.8, "7 strokes are not enough (%.2f)" % PalisadeCuts.progress(world, str(c1.key)))
	var done := PalisadeCuts.strike(world, c1, 1.0)
	await _ticks(4)
	_check(done >= 1.0 and sec.cuts.size() == 1, "the 8th stroke cuts the piece (%d holes)" % sec.cuts.size())
	_check(not _ray_stops(1, 1.5) and _ray_stops(1, 0.8) and _ray_stops(1, 2.5), "a ray passes the opening; under it and over it the wall stops it")
	_check(_ray_stops(0, 1.5) and _ray_stops(2, 1.5) and _ray_stops(0, 3.8), "beside the opening the wall stops it, up to its points")
	var stakes := 0
	var cut_stakes := 0
	for c in sec.get_children():
		if c is MultiMeshInstance3D and not c.is_queued_for_deletion():
			var m := (c as MultiMeshInstance3D).multimesh.mesh
			if m == BuildGeometry.stake_mesh(0) or m == BuildGeometry.stake_mesh(1) or m == BuildGeometry.stake_mesh(2):
				stakes += (c as MultiMeshInstance3D).multimesh.instance_count
			else:
				cut_stakes += 1
	_check(stakes == 6 and cut_stakes >= 2 and cut_stakes <= 4, "6 stakes stand whole, the 2 cut ones show pieces (%d whole, %d pieces)" % [stakes, cut_stakes])
	_check(_aim(1, 1.6, 0.0).is_empty(), "aimed into the opening: nothing to cut (air)")
	# under it, down to the ground (what is left under the opening is less than a piece and goes with it)
	var c2 := _aim(1, 0.5, 0.0)
	_check(not c2.is_empty() and float(c2.h0) <= PalisadeCuts.FOOT + 0.001 and absf(float(c2.h1) - 1.1) < 0.001,
			"aimed low: the piece goes down to the ground and up to the opening (%s)" % str([c2.get("h0"), c2.get("h1")]))
	_stroke(c2)
	await _ticks(4)
	# near the points: the top comes off with the piece
	var c3 := _aim(1, 3.2, 0.0)
	_check(not c3.is_empty() and absf(float(c3.h0) - 2.7) < 0.001 and float(c3.h1) >= PalisadeCuts.TOP + 0.4,
			"aimed near the points: the top comes off with the piece (%s)" % str([c3.get("h0"), c3.get("h1")]))
	_stroke(c3)
	await _ticks(4)
	var open := PalisadeCuts.removed(sec.cuts, 1, false)
	_check(open.size() == 2 and float(open[0][0]) <= PalisadeCuts.FOOT + 0.001 and absf(float(open[0][1]) - 2.1) < 0.001,
			"a gap from the ground to 2.1 m and the top off over 2.7 m (%s)" % str(open))
	_check(not _ray_stops(1, 0.3) and _ray_stops(1, 2.4) and not _ray_stops(1, 3.5), "a ray passes at the foot and over the stub; the stub between stops one")
	var c4 := _aim(2, 1.6, 0.0)
	_check(not c4.is_empty() and absf(float(c4.h0) - 1.1) < 0.001, "the pair beside it is whole (%s)" % str(c4.get("h0", "-")))

	# --- from the firing step's deck: the same rule, the crosshair's height ---
	sec = _make()
	await _ticks(4)
	var deck := _aim(2, 3.6, 2.275)
	_check(not deck.is_empty() and float(deck.h1) >= PalisadeCuts.TOP + 0.4,
			"from the deck, aimed near the points: the top comes off (%s)" % str([deck.get("h0"), deck.get("h1")]))
	_check(not _aim(2, 3.9, 2.275).is_empty(), "from the deck the crosshair at the points (3.9 m) still finds the stakes")
	if not deck.is_empty():
		_stroke(deck)
	await _ticks(4)
	_check(_aim(2, 3.6, 2.275).is_empty(), "one cut was all it took for the notch")
	_check(not _ray_stops(2, 3.3) and _ray_stops(2, float(deck.get("h0", 3.0)) - 0.2), "a shot over the deck passes the notch; the wall under it stops one")

	# --- filling an opening in again ---
	sec = _make()
	await _ticks(4)
	_check(PalisadeCuts.cut(world, sec.piece_id, 1, 1.0, 2.0), "a piece is cut")
	await _ticks(4)
	var eye := Vector3(-0.5 * (PalisadeCuts.x_range(1).x + PalisadeCuts.x_range(1).y), 1.5, 2.0)
	var fpos := Vector3(eye.x, 0.0, 1.0)
	var op := PalisadeCuts.opening_at(world, eye, Vector3(0, 0, -1), fpos, "repair")
	_check(bool(op.get("ok", false)) and (op.size as Vector3).is_equal_approx(Vector3(0.75, 1.0, PalisadeCuts.THICK)), "the opening is found for a repair (%s)" % str(op.get("reason", op.get("size", ""))))
	_check(not bool(PalisadeCuts.opening_at(world, Vector3(eye.x, 2.6, 2.0), Vector3(0, 0, -1), fpos, "cover").get("ok", false)),
			"looking at the whole wall over the opening finds no opening")
	var cov := PalisadeCuts.opening_at(world, eye, Vector3(0, 0, -1), fpos, "cover")
	_check(bool(cov.get("ok", false)), "the opening is found for a cover")
	PalisadeCuts.cover(world, cov)
	await _ticks(4)
	_check(_ray_stops(1, 1.5) and sec.cuts.size() == 1 and int(sec.cuts[0][3]) == 1, "covered: the collider closes, the cut stays a cut")
	var cover_mesh := false
	for c in sec.get_children():
		if c is MeshInstance3D and String(c.name).contains("Cover"):
			cover_mesh = true
	_check(cover_mesh, "logs lie across the opening")
	_check(str(PalisadeCuts.opening_at(world, eye, Vector3(0, 0, -1), fpos, "cover").get("reason", "")) == "Logs cover it already", "a covered opening takes no second cover")
	# the aim at a cover: the piece under belly's next is the cut region (the cover is solid)
	var ac := _aim(1, 1.5, 0.0)
	_check(not ac.is_empty() and absf(float(ac.h0) - 1.0) < 0.001, "the axe at a cover has a target (chopping into it knocks it out)")
	PalisadeCuts.cut(world, sec.piece_id, 1, 1.0, 2.0)
	await _ticks(4)
	_check(sec.cuts.size() == 1, "cutting the covered opening again makes no second hole (%d)" % sec.cuts.size())
	var uncovered := true
	for c: Array in sec.cuts:
		if int(c[3]) != 0:
			uncovered = false
	_check(uncovered and not _ray_stops(1, 1.5), "chopping into the cover knocks it out: open again")
	var rep := PalisadeCuts.opening_at(world, eye, Vector3(0, 0, -1), fpos, "repair")
	_check(bool(rep.get("ok", false)), "the opening is found again")
	PalisadeCuts.repair(world, rep)
	await _ticks(4)
	_check(sec.cuts.is_empty() and _ray_stops(1, 1.5), "repaired: the stakes stand there again, the wall stops the ray")

	# --- saved with the building ---
	sec = _make()
	world.fort_built = true
	PalisadeCuts.cut(world, sec.piece_id, 0, 1.0, 2.0)
	PalisadeCuts.cut(world, sec.piece_id, 3, 2.0, 3.0)
	PalisadeCuts.cover(world, {"piece": sec.piece_id, "k": 3, "h0": 2.0, "h1": 3.0})
	await _ticks(2)
	var want: Array = sec.cuts.duplicate(true)
	var saved := SaveParts.save_building(scene)
	var json: Variant = JSON.parse_string(JSON.stringify(saved))      # as a file
	_check(json is Dictionary and (json as Dictionary).pieces.size() == 1 and (json as Dictionary).pieces[0].has("cuts"), "the cuts are in the building's save")
	SaveParts.load_building(scene, json as Dictionary)
	await _ticks(4)
	var back: BuiltPiece = null
	for q in world.pieces():
		if q.type == "palisade":
			back = q
	_check(back != null and back.cuts.size() == want.size(), "the loaded section has its cuts (%d)" % (back.cuts.size() if back else -1))
	var same := back != null and back.cuts.size() == want.size()
	if same:
		for i in want.size():
			for j in 4:
				if absf(float((back.cuts[i] as Array)[j]) - float((want[i] as Array)[j])) > 0.002:
					same = false
	_check(same, "with the same holes and covers (%s)" % str(back.cuts if back else []))
	_check(back != null and not _ray_stops(0, 1.5) and _ray_stops(3, 2.5), "and the same collider: the open hole passes, the covered one stops")

	if _fails.is_empty():
		print("PALISADE CUTS TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("PALISADE CUTS TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
