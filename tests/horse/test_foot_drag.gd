extends SceneTree
## Headless tests of dragging a dead animal on foot (scripts/horse/foot_drag.gd; data/horse/haul.json "foot"), in the
## real level with the real keys:
##
##   Godot --headless --path . -s tests/horse/test_foot_drag.gd
##
##   data     the walk cap falls as the pull grows, never to a stand; a doe and a buck drag, a 200 kg animal very slowly
##   drag     E at a doe's neck ("Drag the deer"): the musket goes on the back, the rope from the left hand; walking
##            with W (and Shift) drags it at the pull's cap (no sprint), on its rope, the left hand reaching back
##   torch    T while dragging: a lit torch in the RIGHT hand, still dragging, the same pace
##   let go   E ("Let go of the deer"): it lies there, a carcass to skin again, and the musket comes back to the hands;
##            also a jump, drawing a weapon (2) and a heavy hit let go
##   buck     a buck (80 kg) drags slower than a doe
##   horse    with the horse's hitch by the neck, E there is the horse's
##
## The animals are CC0 stand-in models.

var checks := 0
var fails: Array[String] = []
var report := {}
var player: FrontierPlayer
var fd: FootDrag
var it: PlayerInteractor
var horse: Horse


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	_test_data()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	check(player != null and player.foot_drag != null, "the player has a FootDrag")
	if player == null or player.foot_drag == null:
		_end()
		return
	player.ignore_mouse_capture = true
	fd = player.foot_drag
	it = player.interactor
	await frames(60)
	var hs := current_scene.find_children("*", "Horse", true, false)
	horse = hs[0] as Horse if not hs.is_empty() else null
	if horse:
		horse.global_position = _ground(-60.0, 60.0)       # out of the way (its hitch offers carcasses near it)
	await _test_drag()
	await _test_buck()
	await _test_horse()
	_end()


func _end() -> void:
	print("REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("FOOT DRAG TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("FOOT DRAG TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func _test_data() -> void:
	var last := INF
	var mono := true
	for i in 70:
		var c := FootDrag.cap_for(float(i))
		mono = mono and c <= last + 1e-6
		last = c
	check(mono and FootDrag.cap_for(0.0) > 2.0 and FootDrag.cap_for(100.0) > 0.0 and FootDrag.cap_for(1000.0) <= 0.051,
			"the walk cap falls as the pull grows, never to a stand: an extreme crawl (%.2f m/s at 100 kgf)" % FootDrag.cap_for(100.0))
	check(not FootDrag.very_heavy(55.0) and not FootDrag.very_heavy(80.0) and FootDrag.very_heavy(200.0), "a doe and a buck drag, 200 kg very slowly")


func _dead(species: String, at: Vector3, head_dir: Vector3) -> WildAnimal:
	var a := WildAnimal.new()
	a.setup(species, null, null, 11)
	a.name = "Dead_%s" % species
	current_scene.add_child(a)
	a.global_position = at
	a.rotation.y = atan2(-head_dir.x, -head_dir.z)
	a._yaw = a.rotation.y
	await frames(2)
	a.apply_hit(9999.0, a.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await frames(int(1.7 * 120))
	return a


func _put(at: Vector3, look: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := look - at
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-15.0)


func _tap(action: StringName, n := 4) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(3)


## A key's action as an input event (the weapon keys are read in _unhandled_input).
func _key(action: StringName) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(3)


## Faces the neck of `a` from a little to its side and starts the drag with E (once a draw under way is done).
func _grab(a: WildAnimal) -> void:
	for i in 360:
		if not player.is_switching():
			break
		await physics_frame
	var neck := CarcassLoad.neck_point(a)
	var fwd := neck - a.global_position              # from the body out past the head
	fwd.y = 0.0
	_put(neck + fwd.normalized() * 1.2 + a.global_basis.x * 0.4, neck)
	await frames(8)
	await _tap(&"interact")
	for i in 200:
		await physics_frame
		if fd.load != null:
			break
	await frames(10)


## Walks forward (the body's facing) for `secs`, holding Shift too; {moved, vmax, over, sprinted}.
func _walk(a: WildAnimal, secs: float, dir := Vector3.ZERO) -> Dictionary:
	if dir != Vector3.ZERO:
		player.yaw = atan2(-dir.x, -dir.z)
	var p0 := a.global_position
	var vmax := 0.0
	var over := 0.0
	var sprinted := false
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in int(secs * 120.0):
		await physics_frame
		if i > 120:
			vmax = maxf(vmax, player.horizontal_speed())
		sprinted = sprinted or player.is_sprinting
		if i > 120 and fd.load and is_instance_valid(fd.load):
			over = maxf(over, fd.load.front.distance_to(fd.hitch_point()) - fd.load.chain_len)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await frames(30)
	var d := a.global_position - p0
	return {"moved": Vector2(d.x, d.z).length(), "vmax": vmax, "over": over, "sprinted": sprinted}


func _test_drag() -> void:
	var at := _ground(30.0, -40.0)
	var doe := await _dead("deer", at, Vector3.FORWARD)
	check(CarcassLoad.haulable(doe), "a shot doe lies ready")
	var neck := CarcassLoad.neck_point(doe)
	_put(neck + Vector3(0.0, 0.0, -1.3), neck)
	await frames(8)
	check(it.target == fd and it._label.text.ends_with("Drag the deer"), "at its neck: %s" % it._label.text)
	check(not player.hands_free, "the musket in the hands before")
	await _tap(&"interact")
	await frames(40)
	check(fd.load != null and fd.load.animal == doe, "E takes it on the rope")
	check(player.hands_free, "the musket goes on the back")
	check(doe.get_meta(&"on_chain", false) and not doe.is_in_group(PlacedWeapon.GROUP), "on the rope it is no Skin target")
	check(it.target == fd and it._label.text.ends_with("Let go of the deer"), "dragging, E says: %s" % it._label.text)
	# away from where it lay, the body's facing: walk (Shift held: no sprint)
	var w := await _walk(doe, 6.0, Vector3(1.0, 0.0, -1.0).normalized())
	var cap := fd.cap
	report["doe"] = {"moved": snappedf(w.moved, 0.1), "vmax": snappedf(w.vmax, 0.01), "cap": snappedf(cap, 0.01),
			"pull_kgf": snappedf(fd.load.pull_kgf if fd.load else -1.0, 0.1), "over": snappedf(w.over, 0.01)}
	check(w.moved > 3.5, "walking drags it (%.1f m in 6 s)" % w.moved)
	check(cap > 0.6 and cap < 1.6 and w.vmax <= cap + 0.15, "at the pull's pace: at most %.2f m/s under a cap of %.2f" % [w.vmax, cap])
	check(not w.sprinted, "no sprint while dragging")
	check(w.over < 0.35, "on its rope (at most %.2f m over)" % w.over)
	# the left hand back along the rope
	var sk := player.skeleton
	var lh := fd.hand_final
	var fwd := -player.global_basis.z
	var back_m := (lh - player.global_position).dot(-fwd)
	check(fd._ik_w > 0.99 and fd._ik.last_offset["l"].length() >= 0.0, "the left arm reaches along the rope")
	check(back_m > 0.15, "the left hand is behind the body (%.2f m)" % back_m)
	var inv := sk.global_transform.affine_inverse()
	# T: a torch into the right hand, still dragging
	await _tap(&"torch")
	await frames(90)
	check(player.torch.holding() and player.torch.held.lit, "T: a lit torch in the hand")
	check(player.anim.torch_ik.side == "r", "in the right hand (%s)" % player.anim.torch_ik.side)
	check(fd.load != null, "and the deer still on the rope")
	var w2 := await _walk(doe, 4.0)
	check(w2.moved > 2.0 and fd.load != null, "dragging on with the torch (%.1f m)" % w2.moved)
	# E lets go: it lies there; the musket comes back
	await _tap(&"interact")
	await frames(90)
	check(fd.load == null and fd.last_let_go == "e", "E lets go (%s)" % fd.last_let_go)
	check(not doe.get_meta(&"on_chain", false) and doe.is_in_group(PlacedWeapon.GROUP), "it lies there, to skin again")
	check(not player.hands_free, "the musket back in the hands")
	check(player.drag_speed_cap == INF, "the pace is free again")
	# a weapon key lets go
	await _grab(doe)
	check(fd.load != null, "E takes it again")
	await _key(&"weapon_2")
	for i in 240:
		await physics_frame
		if fd.load == null:
			break

	check(fd.load == null and fd.last_let_go == "weapon", "drawing a weapon lets go (%s)" % fd.last_let_go)
	await frames(90)
	# a jump lets go
	await _grab(doe)
	check(fd.load != null, "and again")
	await _tap(&"jump")
	check(fd.load == null and fd.last_let_go == "jump", "a jump lets go (%s)" % fd.last_let_go)
	await frames(90)
	# a heavy hit lets go
	await _grab(doe)
	player.health = player.max_health
	player.apply_hit(player.heavy_hit_damage + 1.0, player.global_position + Vector3.UP, Vector3.FORWARD, null, "body")
	await frames(3)
	check(fd.load == null and fd.last_let_go == "hit", "a heavy hit lets go (%s)" % fd.last_let_go)
	player.health = player.max_health
	if player.torch.holding():
		player.torch.put_away()
	await frames(60)
	doe.queue_free()


func _test_buck() -> void:
	var doe := await _dead("deer", _ground(40.0, -60.0), Vector3.FORWARD)
	var buck := await _dead("stag", _ground(46.0, -60.0), Vector3.FORWARD)
	await _grab(doe)
	await _walk(doe, 3.0, Vector3(0.0, 0.0, -1.0))
	var cap_doe := fd.cap
	await _tap(&"interact")
	await frames(60)
	await _grab(buck)
	check(fd.load != null and fd.load.animal == buck, "a buck on the rope")
	await _walk(buck, 3.0, Vector3(0.0, 0.0, -1.0))
	var cap_buck := fd.cap
	report["caps"] = {"doe": snappedf(cap_doe, 0.01), "buck": snappedf(cap_buck, 0.01)}
	check(cap_buck < cap_doe - 0.1, "the buck drags slower (%.2f vs %.2f m/s)" % [cap_buck, cap_doe])
	await _tap(&"interact")
	await frames(60)
	doe.queue_free()
	buck.queue_free()


func _test_horse() -> void:
	if horse == null:
		check(false, "the level has its horse")
		return
	var doe := await _dead("deer", _ground(20.0, -70.0), Vector3.FORWARD)
	var neck := CarcassLoad.neck_point(doe)
	# the horse's hitch just by the neck
	var back := horse.global_basis.z
	back.y = 0.0
	horse.global_position += neck - horse.get_hitch_point() - back.normalized() * 2.0
	horse.global_position.y = FrontierTerrain.height_at(horse.global_position.x, horse.global_position.z)
	await frames(10)
	var side := back.cross(Vector3.UP).normalized()
	_put(neck + side * 1.3, neck)
	await frames(10)
	check(it.target is HorseHaul and it._label.text.ends_with("Hitch the deer to the horse"), "the horse by it: %s" % it._label.text)
	check(fd._offer.is_empty(), "no drag on foot offered then")
	doe.queue_free()
