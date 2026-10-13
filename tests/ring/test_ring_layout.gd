extends SceneTree
## The team arenas' raised pieces (RingArena THE LAYOUT, RingMoves._piece_guard / _drop_off; the owner, 2026-10-10: arena
## "C · Ruins", "Shift + Space drops"), on the bare ring (no match) of a team format, the player with a RingMoves on him:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_layout.gd -- [format=4v4]
##   the pieces   the format's layout built and turned half round (4v4: 10, 2v2: 8; a 1v1 none); floor_at 0 on the deck, h on
##                a perch, about half h half up its stairs; the colliders where the numbers are (a ray down finds the perch's
##                top, the ramp's slope, a wall's top within 0.15 m)
##   the ledge    on a perch, walking at its edge 1.5 s keeps him up on it (no fall)
##   the drop     Shift + Space there: down on the deck within 1.2 s, off the perch's footprint
##   the stairs   from the ramp's foot, walking up it 3 s: up on the perch
##   bots' goals  RingRules.clamp_for moves a place inside a piece off it (a bot on the deck is never sent into a wall)
## Last line "RING LAYOUT PASSED" or "RING LAYOUT FAILED".

const Rig := preload("res://tests/ring/r3_move_rig.gd")

var checks := 0
var fails: Array[String] = []
var fmt := "4v4"
var p: FrontierPlayer
var pm: RingMoves
var ring: RingArena
var rig: Rig


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("format=") and kv.get_slice("=", 1) in ["2v2", "4v4"]:
			fmt = kv.get_slice("=", 1)
	InputSetup.ensure()
	MatchSetup.incoming = false
	MatchSetup.set_match()
	MatchSetup.format = fmt
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingArena.set_format("1v1")
	if fails.is_empty() and checks > 0:
		print("RING LAYOUT PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("RING LAYOUT FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _run() -> void:
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	ring = lvl.ring if lvl != null else null
	_expect(p != null and ring != null and RingMode.find(self) == null, "the bare ring of %s (no match)" % fmt)
	if p == null or ring == null:
		return _end()
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	p.fall_safe_m = 1000.0
	for i in 60:
		await physics_frame
		if p.arena_element != "" and SwayCaster.of(p) != null:
			break
	BendKnock.ragdoll_mps = INF
	pm = RingMoves.install(p)
	rig = Rig.new(self)
	rig.p = p
	rig.pm = pm
	physics_frame.connect(rig._untap)
	_pieces()
	await _ledge_and_drop()
	await _stairs()
	_bot_goals()
	_end()


func _perch() -> Dictionary:
	for pc: Dictionary in ring.pieces():
		if String(pc.kind) == "perch" and pc.has("ramp") and not String(pc.id).ends_with("_t"):
			return pc
	return {}


func _w(x: float, z: float, y := 0.0) -> Vector3:
	return ring.to_global(Vector3(x, ring.top() + y, z))


func _ray_y(x: float, z: float) -> float:
	var from := _w(x, z, 10.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, 1, [p.get_rid()])
	var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
	return float((hit.get("position", Vector3(0, -99, 0)) as Vector3).y) - ring.deck_y()


func _pieces() -> void:
	var want := {"4v4": 10, "2v2": 8}
	_expect(ring.pieces().size() == int(want.get(fmt, 0)), "%s: %d pieces built, the turned copies with them (%d)"
			% [fmt, int(want.get(fmt, 0)), ring.pieces().size()])
	var pc := _perch()
	if pc.is_empty():
		_expect(false, "a perch with its ramp")
		return
	var r: Rect2 = pc.rect
	var h := float(pc.h)
	var rp: Dictionary = pc.ramp
	var rr: Rect2 = rp.rect
	var mid := rr.get_center()
	_expect(is_zero_approx(ring.floor_at(_w(0.0, 0.0))) and is_equal_approx(ring.floor_at(_w(r.get_center().x, r.get_center().y)), h)
			and absf(ring.floor_at(_w(mid.x, mid.y)) - h * 0.5) < 0.05,
			"floor_at: the deck 0, the perch %.1f, half up its stairs %.2f" % [h, ring.floor_at(_w(mid.x, mid.y))])
	var top := _ray_y(r.get_center().x, r.get_center().y)
	var slope := _ray_y(mid.x, mid.y)
	var wall_ok := true
	for w: Dictionary in ring.pieces():
		if String(w.kind) == "wall":
			wall_ok = wall_ok and _ray_y((w.rect as Rect2).get_center().x, (w.rect as Rect2).get_center().y) > 0.8
	_expect(absf(top - h) < 0.15 and absf(slope - h * 0.5) < 0.15 and wall_ok,
			"the colliders: the perch's top at %.2f (%.1f), the ramp half up at %.2f, every wall stands" % [top, h, slope])
	RingArena.set_format("1v1")
	var flat := (RingArena.data().get("layout", {}) as Dictionary).is_empty()
	RingArena.set_format(fmt)
	_expect(flat, "a 1v1 has no layout: its deck is flat")


## On the perch at its outer edge, walking into it; then Shift + Space.
func _ledge_and_drop() -> void:
	var pc := _perch()
	if pc.is_empty():
		return
	var r: Rect2 = pc.rect
	var h := float(pc.h)
	# (the outer long side: the one nearer the deck's lip)
	var outer_z := r.end.y if absf(r.end.y) > absf(r.position.y) else r.position.y
	var inward := -signf(outer_z)
	var at := _w(r.get_center().x, outer_z + inward * 1.2, h + 0.05)
	var to := _w(r.get_center().x, outer_z + signf(outer_z) * 5.0, h)
	rig.place(p, at, Rig.yaw_to(at, to))
	await rig.secs(0.3)
	rig.hold(&"move_forward", true)
	await rig.secs(1.5)
	rig.hold(&"move_forward", false)
	var up := p.global_position.y - ring.deck_y()
	_expect(up > h - 0.3 and ring.floor_at(p.global_position) > h - 0.3,
			"walking at the perch's edge 1.5 s keeps him up on it (feet %.2f m, h %.1f)" % [up, h])
	var pc2 := _perch()
	print("  (at the edge: %.2f m in from it, floor %.2f, on floor %s)" % [absf(absf(ring.to_local(p.global_position).z) - absf(outer_z)),
			ring.floor_at(p.global_position), p.is_on_floor()])
	rig.hold(&"sprint", true)
	await rig.ticks(2)
	rig.tap(&"jump")
	var t := await rig.until(func() -> bool: return p.global_position.y - ring.deck_y() < 0.3 and p.is_on_floor(), 1.2)
	rig.hold(&"sprint", false)
	rig.release_all()
	_expect(t < 1.2 and ring.floor_at(p.global_position) < 0.3,
			"Shift + Space at the edge: down on the deck in %.2f s, off the perch" % t)


## From the ramp's foot, walking up it.
func _stairs() -> void:
	var pc := _perch()
	if pc.is_empty():
		return
	var h := float(pc.h)
	var rp: Dictionary = pc.ramp
	var rr: Rect2 = rp.rect
	var up := String(rp.up)
	var foot := Vector2(rr.position.x - 1.0, rr.get_center().y) if up == "+x" else (Vector2(rr.end.x + 1.0, rr.get_center().y) if up == "-x" \
			else (Vector2(rr.get_center().x, rr.position.y - 1.0) if up == "+z" else Vector2(rr.get_center().x, rr.end.y + 1.0)))
	var head := Vector2(rr.end.x + 2.0, rr.get_center().y) if up == "+x" else (Vector2(rr.position.x - 2.0, rr.get_center().y) if up == "-x" \
			else (Vector2(rr.get_center().x, rr.end.y + 2.0) if up == "+z" else Vector2(rr.get_center().x, rr.position.y - 2.0)))
	var at := _w(foot.x, foot.y, 0.05)
	rig.place(p, at, Rig.yaw_to(at, _w(head.x, head.y)))
	await rig.secs(0.3)
	rig.hold(&"move_forward", true)
	var t := await rig.until(func() -> bool: return p.global_position.y - ring.deck_y() > h - 0.3, 3.0)
	rig.hold(&"move_forward", false)
	rig.release_all()
	_expect(t < 3.0, "walking up the stairs from their foot: up on the perch in %.2f s (feet %.2f m)"
			% [t, p.global_position.y - ring.deck_y()])


## RingRules.clamp_for: a bot's place inside a piece moved off it.
func _bot_goals() -> void:
	var r := RingRules.make(current_scene, ring)
	r.add(p, 0)
	r.set_ends(0)
	r.rule_set = "stock"
	rig.place(p, _w(0.0, 0.0, 0.05), 0.0)
	var bad: Array[String] = []
	for pc: Dictionary in ring.pieces():
		var c := (pc.rect as Rect2).get_center()
		var out := r.clamp_for(_w(c.x, c.y), p)
		if not ring.piece_at(out, 0.5).is_empty():
			bad.append(String(pc.id))
	_expect(bad.is_empty(), "a bot's place inside a piece is moved off it (%s)" % ", ".join(bad))
	r.queue_free()
