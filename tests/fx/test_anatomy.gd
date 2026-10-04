extends SceneTree
## The skeleton map (Anatomy; user 2026-09-30): built on the player's rig and an animal's, riding the bones, and a shot's channel
## named through it. Headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/fx/test_anatomy.gd -- wildlife=on
##
##   built    the human: bones, 24 vertebrae, ribs, the cord and the organs (the fitted body, BodyModel: 2026-10-03), in metres
##   follows  a part goes with its bone: move the bone's pose and the part moves with it
##   wound    a ball through the chest names the heart or a lung; through the head the skull; through the back the cord
##   animal   the same on a deer (its armature is 38x): the parts are the size of the animal's, not 38 times
##   toggle   N: shown for all, hidden again
## Ends with "ANATOMY TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var p := current_scene.get_node("Player") as FrontierPlayer
	await _fr(60)
	var an := Anatomy.attach_to(p.skeleton)
	_expect(an != null, "the player's rig has an anatomy")
	if an == null:
		_end()
		return
	var names := an.parts.map(func(d: Dictionary) -> String: return String(d.name))
	_expect(names.has("T10 vertebra") and names.has("Skull") and names.has("Heart") and names.has("Left rib 3") and names.has("Right rib 3"),
			"bones, vertebrae, skull, ribs, heart (%d parts)" % an.parts.size())
	_extent(an, "human", 0.9, 2.2)
	# a ball through the chest, front to back
	var chest: Vector3 = _part(an, "Heart").global_position
	var fwd := -p.global_basis.z
	var lines := an.add_wound(chest - fwd * 0.3, fwd, 80.0)
	print("   chest: ", lines)
	_expect(lines.any(func(l: String) -> bool: return l.begins_with("Heart") or l.begins_with("Lung")), "a ball through the chest goes through the heart or a lung")
	var sk_head: Vector3 = _part(an, "Skull").global_position
	lines = an.add_wound(sk_head - fwd * 0.4, fwd, 80.0, 0.8)
	print("   head: ", lines)
	_expect(lines.has("Skull, fractured") or lines.any(func(l: String) -> bool: return l.begins_with("Brain")), "through the head: the skull or the brain")
	var t10: Vector3 = _part(an, "T10 vertebra").global_position
	lines = an.add_wound(t10 + fwd * 0.4, -fwd, 80.0, 0.8)
	print("   back: ", lines)
	_expect(lines.any(func(l: String) -> bool: return l.contains("T10")), "through the back at T10: the cord and the vertebra at T10")
	# the part follows its bone
	var heart_node := _part(an, "Heart")
	var before := heart_node.global_position
	p.global_position += Vector3(3.0, 0.0, 0.0)
	await _fr(2)
	_expect(heart_node.global_position.distance_to(before) > 2.5, "the heart goes with the body when it moves")
	# an animal
	var w := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	if w:
		var a: WildAnimal = null
		for x: WildAnimal in w.animals():
			if x.species == "deer" and not x.is_dead():
				a = x
				break
		if a:
			var sk: Skeleton3D = a.get("_skel")
			var dn := Anatomy.attach_to(sk)
			_expect(dn != null, "a deer has an anatomy")
			if dn:
				_extent(dn, "deer", 0.5, 2.6)
				var heart := _part(dn, "Heart").global_position
				lines = dn.add_wound(heart + Vector3(0, 0, 0.5), Vector3(0, 0, -1), 90.0)
				print("   deer: ", lines)
				_expect(lines.size() >= 1, "a shot into a deer's side names what it passes through")
	# toggle
	Anatomy.set_shown(true, self)
	_expect(an.visible, "N: shown")
	Anatomy.set_shown(false, self)
	_expect(not an.visible, "N: hidden again")
	_end()


func _part(an: Anatomy, nm: String) -> MeshInstance3D:
	for d in an.parts:
		if d.name == nm:
			return d.node
	return null


## The whole's size in metres: its parts spread over `lo` .. `hi` m (the skeleton's scale is out of it).
func _extent(an: Anatomy, who: String, lo: float, hi: float) -> void:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for d in an.parts:
		var g := (d.node as Node3D).global_position
		mn = mn.min(g)
		mx = mx.max(g)
	var size := (mx - mn).length()
	_expect(size >= lo and size <= hi, "%s: the parts spread %.2f m (%.1f .. %.1f)" % [who, size, lo, hi])


func _end() -> void:
	if fails.is_empty():
		print("ANATOMY TEST PASSED (%d checks)" % checks)
	else:
		print("ANATOMY TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
