extends SceneTree
## The falling ship and the wreck (WreckFall; docs/main_story.md mission 11, Two Fires) on the real level, survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_wreck.gd -- survival=on
##   fall     begin() puts the intact galleon high in the sky far back along its heading, burning (its FireFx, trails), the
##            one light on it; it comes down and nearer, quickening, and lands (`landed`) at its end
##   wreck    the wreck model lies on the ground at `at` (its frame on the terrain, tilted at most MAX_TILT_DEG); a ray
##            down onto its deck meets its collider; no tree stands in its footprint (the harvest record), and the swath
##            behind it was snapped
##   spar     the spar is a frozen RigidBody3D in group sway_targets, meta sway_move = "first_lock", lying across the
##            stranger's thighs a little over him
##   rook     the stranger (Rook) is an NpcBody lying on the ground whose meshes all cast no shadow
##   ithel    Captain Ithel is an NpcBody sat against the hull bottom (within reach of it), with a StoryContact named
##            "Captain Ithel"
##   budget   one light for the whole wreck (no shadow), 1.2 m over the KeelGlow empty; the Burn_* parts burn (a FireFx
##            each, a smoke column); WingSails cast no shadow
##   lift     lift_spar(): the spar unfrozen and off him, `spar_lifted`; then he gets up (`stranger_freed`, animated)
##   load     place_wreck() at the same place and heading: landed at once (no streak), the same frame and the spar on
##            the same man
## Ends with "WRECK TEST PASSED (<n> checks)" or "WRECK TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var landed_n := 0
var lifted := false
var freed := false
## The wreck's place: the head of the open land (docs/main_story.md 10.1, "wreck" about [1100, -380]).
var at := Vector3(1100.0, 0.0, -380.0)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _on_landed() -> void:
	landed_n += 1


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	paused = false
	var level := current_scene
	var player := level.get_node_or_null("Player") as FrontierPlayer if level else null
	_expect(level != null and player != null, "the level is up with the player")
	if level == null:
		_end()
		return
	if player:
		player.ignore_mouse_capture = true
	at.y = FrontierTerrain.height_at(at.x, at.z)
	await _test_fall(level)
	var wf := WreckFall.find(self)
	if wf == null or not wf.is_landed():
		_end()
		return
	await _test_wreck(wf)
	await _test_lift(wf)
	await _test_load(level, wf)
	await _test_woods(level)
	_end()


func _test_fall(level: Node) -> void:
	print("-- fall")
	var wf := WreckFall.begin(level, at)
	_expect(wf != null and WreckFall.find(self) == wf, "begin() makes the fall (found by its group)")
	if wf == null:
		return
	wf.landed.connect(_on_landed)
	wf.speed = 2.5
	await _frames(2)
	_expect(wf.phase == WreckFall.Phase.FALLING and wf.ship != null, "the intact galleon is falling")
	if wf.ship == null:
		return
	var p0 := wf.ship.global_position
	var d0 := Vector2(p0.x - at.x, p0.z - at.z).length()
	_expect(p0.y - at.y > 400.0 and d0 > 1200.0, "it starts high (%.0f m up) and far back (%.0f m)" % [p0.y - at.y, d0])
	_expect(wf.ship.find_child("FireFx", true, false) != null and wf.ship.find_child("FireTrail", true, false) != null
			and wf.ship.find_child("SmokeTrail", true, false) != null, "it burns: its fire and its fire and smoke trails")
	_expect(wf.light != null and wf.light.get_parent() == wf.ship and not wf.light.shadow_enabled, "the one light rides on it, no shadow")
	var steps: Array[float] = []
	var heights: Array[float] = []
	var last := p0
	var n := 0
	while wf.phase == WreckFall.Phase.FALLING and n < 2000:
		await process_frame
		n += 1
		if wf.ship != null and n % 20 == 0:
			var p := wf.ship.global_position
			steps.append(p.distance_to(last))
			heights.append(p.y)
			last = p
	_expect(wf.phase == WreckFall.Phase.LANDED and landed_n == 1, "it lands (after %d frames), `landed` once" % n)
	var down := heights.size() > 3
	for i in range(1, heights.size()):
		down = down and heights[i] <= heights[i - 1] + 0.5
	_expect(down, "it only comes down (%d samples)" % heights.size())
	_expect(steps.size() > 4 and steps[steps.size() - 2] > steps[1] * 1.2, "and quickens as it falls (%.0f m then %.0f m in 20 frames)"
			% [steps[1] if steps.size() > 1 else 0.0, steps[steps.size() - 2] if steps.size() > 2 else 0.0])
	_expect(wf.ship == null or not is_instance_valid(wf.ship), "the intact ship is gone at the landing")


func _test_wreck(wf: WreckFall) -> void:
	print("-- wreck")
	await _physics(3)
	_expect(wf.wreck != null and wf.wreck.find_child("Hull_Fore", true, false) != null, "the wreck model is there (its Hull_Fore)")
	var o := wf.wreck.global_position
	var ground := FrontierTerrain.height_at(o.x, o.z)
	_expect(Vector2(o.x - at.x, o.z - at.z).length() < 0.01 and absf(o.y - ground) < 0.8, "it lies on the ground at `at` (%.2f m off the terrain)" % (o.y - ground))
	var tilt := rad_to_deg(wf.wreck.global_basis.y.angle_to(Vector3.UP))
	_expect(tilt <= WreckFall.MAX_TILT_DEG + 0.1, "on the land's slope (%.1f deg)" % tilt)
	var fwd := -wf.wreck.global_basis.z
	_expect(Vector2(fwd.x, fwd.z).normalized().dot(Vector2(-sin(wf.heading), -cos(wf.heading))) > 0.97, "its bow along the heading")
	var deck := wf.wreck.find_child("Deck", true, false) as Node3D
	var space := wf.get_world_3d().direct_space_state
	var hit := {}
	if deck:
		var q := PhysicsRayQueryParameters3D.create(deck.global_position + Vector3.UP * 12.0, deck.global_position - Vector3.UP * 4.0)
		hit = space.intersect_ray(q)
	_expect(not hit.is_empty() and wf.wreck.is_ancestor_of(hit.collider), "a ray down onto its deck meets its collider (%s)" % (hit.get("collider") if not hit.is_empty() else "nothing"))
	var h := VegHarvest.find(self)
	var standing := 0
	if h:
		var inv := wf.frame.affine_inverse()
		for d: Dictionary in h.near(o, 25.0):
			if String(d.type) != "tree":
				continue
			var l := inv * (d.pos as Vector3)
			if WreckFall.FOOTPRINT.has_point(Vector2(l.x, l.z)):
				standing += 1
	_expect(h != null and standing == 0, "no tree stands in its footprint (%d cleared, %d snapped, %d saplings, %d rocks)"
			% [wf.cleared.trees, wf.cleared.snapped, wf.cleared.saplings, wf.cleared.rocks])
	# the spar and the stranger
	var spar := wf.spar()
	var rook := wf.rook()
	_expect(spar is RigidBody3D and spar.freeze, "the spar is a RigidBody3D, frozen")
	_expect(spar != null and spar.is_in_group(&"sway_targets") and String(spar.get_meta(&"sway_move", "")) == "first_lock",
			"in group sway_targets, meta sway_move = first_lock")
	_expect(spar != null and spar.find_child("Spar", true, false) is MeshInstance3D and spar.find_child("Shape", true, false) is CollisionShape3D,
			"with its own mesh and a collider")
	_expect(rook is NpcBody and rook.mesh != null, "the stranger (Rook) is an NpcBody")
	if rook and spar:
		var pelvis := rook.bone_pos("pelvis")
		var g := FrontierTerrain.height_at(pelvis.x, pelvis.z)
		_expect(pelvis.y - g < 0.45, "lying on the ground (pelvis %.2f m up)" % (pelvis.y - g))
		var axis := spar.global_basis.x
		var rel := pelvis - spar.global_position
		var along := rel.dot(axis)
		var off := (rel - axis * along)
		var flat_off := Vector2(off.x, off.z).length()
		var over := (spar.global_position + axis * along).y - pelvis.y
		_expect(flat_off < 0.7 and absf(along) < SPAR_HALF and over > 0.0 and over < 0.6,
				"the spar lies across him (%.2f m off his hips, %.2f m over them)" % [flat_off, over])
		var casting := 0
		var meshes := 0
		for gi in rook.find_children("*", "GeometryInstance3D", true, false):
			meshes += 1
			if (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				casting += 1
		_expect(meshes > 0 and casting == 0, "Rook casts no shadow (%d meshes, %d casting)" % [meshes, casting])
		await _frames(2)
		_expect(not rook.animate, "and rests (nothing runs for him)")
	# Ithel
	var it := wf.ithel()
	_expect(it is NpcBody and wf.contact != null and wf.contact.who == "Captain Ithel" and wf.contact.is_in_group(&"story_contacts"),
			"Captain Ithel is an NpcBody with his StoryContact")
	if it:
		var q2 := PhysicsRayQueryParameters3D.create(it.global_position + Vector3.UP * 0.6, it.global_position + Vector3.UP * 0.6 - wf.frame.basis.x * 3.0)
		var h2 := space.intersect_ray(q2)
		_expect(not h2.is_empty() and wf.wreck.is_ancestor_of(h2.collider) and (h2.position as Vector3).distance_to(it.global_position + Vector3.UP * 0.6) < 1.2, "sat against the hull (it is %.2f m behind him)" % (
				(h2.position as Vector3).distance_to(it.global_position + Vector3.UP * 0.6) if not h2.is_empty() else -1.0))
	# the budget
	var lights := wf.find_children("*", "Light3D", true, false).filter(func(l: Node) -> bool: return (l as Node3D).is_visible_in_tree())
	_expect(lights.size() == 1 and lights[0] == wf.light and not wf.light.shadow_enabled, "one light for all of it, no shadow (%d)" % lights.size())
	var kg := wf.wreck.find_child("KeelGlow", true, false) as Node3D
	_expect(kg != null and wf.light.global_position.distance_to(kg.global_position + Vector3.UP * 1.2) < 0.05, "1.2 m over the KeelGlow")
	var burns := wf.wreck.find_children("Burn_*", "MeshInstance3D", true, false).size()
	_expect(burns >= 4 and wf.fires.size() == burns and wf.column != null and wf.burn > 0.9, "the Burn_* parts burn (%d fires) under a smoke column" % wf.fires.size())
	var ws := wf.wreck.find_child("WingSails", true, false) as GeometryInstance3D
	_expect(ws != null and ws.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "WingSails cast no shadow")


const SPAR_HALF := 3.0


func _test_lift(wf: WreckFall) -> void:
	print("-- lift")
	wf.spar_lifted.connect(func() -> void: lifted = true)
	wf.stranger_freed.connect(func() -> void: freed = true)
	var spar := wf.spar()
	var p0 := spar.global_position
	wf.lift_spar()
	_expect(not spar.freeze and lifted, "lift_spar(): unfrozen, `spar_lifted`")
	await _physics(30)
	_expect(spar.global_position.distance_to(p0) > 0.3, "it is thrown off him (%.2f m)" % spar.global_position.distance_to(p0))
	var n := 0
	while not freed and n < 900:
		await process_frame
		n += 1
	_expect(freed and wf.rook().animate, "he gets up (`stranger_freed` after %d frames)" % n)


func _test_load(level: Node, old: WreckFall) -> void:
	print("-- load")
	var xf := old.frame
	var rook_at := old.rook().global_position
	var wf := WreckFall.place_wreck(level, at)
	_expect(wf != null and wf.is_landed() and wf.ship == null and WreckFall.find(self) == wf, "place_wreck(): landed at once, no streak")
	if wf == null:
		return
	_expect(wf.frame.is_equal_approx(xf), "the same frame as the fall left")
	_expect(wf.rook().global_position.distance_to(rook_at) < 0.05 and wf.spar().freeze, "the stranger in the same place, pinned again")
	await _frames(3)
	_expect(not is_instance_valid(old), "the first wreck is gone")


## In the woods: the spot round the fort with the most trees; the wreck laid there takes the trees out of its footprint
## and under its fallen tops, and snaps those in the swath behind it.
func _test_woods(level: Node) -> void:
	print("-- woods")
	var h := VegHarvest.find(self)
	if h == null:
		_expect(false, "the forest's harvest record is there")
		return
	var best := Vector3.ZERO
	var most := -1
	for r: float in [70.0, 110.0, 150.0]:
		for k in 16:
			var a := TAU * k / 16.0
			var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
			var n := h.near(p, 12.0).filter(func(d: Dictionary) -> bool: return String(d.type) == "tree").size()
			if n > most:
				most = n
				best = p
	best.y = FrontierTerrain.height_at(best.x, best.z)
	var wf := WreckFall.place_wreck(level, best)
	var inv := wf.frame.affine_inverse()
	var standing := 0
	for d: Dictionary in h.near(best, 25.0):
		if String(d.type) != "tree":
			continue
		var l := inv * (d.pos as Vector3)
		if WreckFall.FOOTPRINT.has_point(Vector2(l.x, l.z)):
			standing += 1
	var stumps := wf.find_children("Snapped_*", "StaticBody3D", false, false).size()
	_expect(most > 0 and int(wf.cleared.trees) > 0 and standing == 0,
			"laid in the woods (%d trees within 12 m there): %d trees out of its way, none left in its footprint" % [most, wf.cleared.trees])
	_expect(stumps == int(wf.cleared.snapped), "the swath's trees snapped: %d stumps" % stumps)
	await _frames(2)


func _end() -> void:
	if fails.is_empty():
		print("WRECK TEST PASSED (%d checks)" % checks)
	else:
		print("WRECK TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
