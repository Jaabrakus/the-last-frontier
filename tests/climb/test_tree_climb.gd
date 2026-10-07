extends SceneTree
## Climbing a tree (user 2026-09-27: "these grips should allow us to climb up trees now"; branch to branch with E since 2026-10-03:
## "its easy to go up and down the tree like that but they should have to press e to climb up to the next branch or something"),
## headless, on the real level: a sturdy tree near the fort (a trunk collider 0.22 m or more across and 5 m or more to its crown).
##   G        G at a tree's trunk grips nothing: it says "E to climb" (the trunks are GripSurface "bark")
##   up       looking up the trunk the prompt is "Climb up" (TreeClimb); E shinnies up the bare trunk to where the crown starts
##            (the collider's top) and pulls up onto a branch there, crouched on it (PerchBranches)
##   perch    the look is free (it turns all the way round to the trunk); the move keys and a tap of Space keep the climber on the
##            branch; the grip refills there; the player's own weapon is in hand and aims (the camera in nearer, the body faded); G
##            there says how to climb
##   higher   E climbs to the branch above (the reach and the pull-up), and again to the next
##   lower    "Climb down" (E's hold list) and C each come down a branch
##   no crawl the move keys do not crawl a tree's trunk (rock faces and giants still do: test_grip, the mammoth tests)
##   down     C from the first branches: down the trunk, the last of it a drop onto the ground
##   felled   felling the tree takes its branches with it: no perch left standing in the air where it was
##   fade     up the tree the shaders keep the tree climbed whole (veg_clear_d: its base) and clear the other trees round
##            the climber; looking down from a branch its crown under the climber clears for the ground; down again,
##            nothing is cleared (user 2026-10-03: "also when we keep climbing up trees fade the other ones not the tree we
##            are climbing up")
##
##   Godot --headless --path . -s tests/climb/test_tree_climb.gd -- --no-capture
## "TREE CLIMB TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

var p: FrontierPlayer
var failures := PackedStringArray()
var checks := 0
var axis := Vector3.ZERO
var radius := 0.0
var top := 0.0
var tree_i := -1


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	p = current_scene.get_node_or_null("Player")
	if p == null:
		print("TREE CLIMB TEST FAILED (no player)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	await _fr(240)
	if not _pick_tree():
		print("TREE CLIMB TEST FAILED (no tree found)")
		quit(1)
		return
	print("tree at %s r %.2f crown at %.2f m" % [axis.snappedf(0.01), radius, top])
	await _climb()
	if failures.is_empty():
		print("TREE CLIMB TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("TREE CLIMB TEST FAILED (%d of %d)" % [failures.size(), checks])
		quit(1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


## The climb fade's shader global `name` as PlayerGrip last set it (Vector4.ZERO when never).
func _clear(name: StringName) -> Vector4:
	return p.grip.clear_globals.get(name, Vector4.ZERO)


## Whether the clear keeps the tree at `at` whole (veg_clear_d names it, the fade on).
func _keeps(at: Vector3) -> bool:
	var d := _clear(&"veg_clear_d")
	return d.w == 1.0 and absf(d.x - at.x) < 0.01 and absf(d.z - at.z) < 0.01 and _clear(&"veg_clear_b").w > 0.99


## The nearest sturdy tree to the fort's north gate, on level ground, with room round it (as vegetation.gd sizes it).
func _pick_tree() -> bool:
	var veg = current_scene.get("vegetation")
	var lay = veg.layout
	var best := INF
	for i in lay.tree_pos.size():
		if lay.tree_collider[i] == 0:
			continue
		var info := Assets.tree(lay.tree_kind[i], lay.tree_variant[i])
		var s: float = lay.tree_scale[i]
		var r := clampf(float(info.get("trunk_radius", 0.3)) * s * 0.92, 0.1, 0.75)
		var h := maxf(float(info.get("collider_height", 6.0)) * s, 3.3)
		var pos: Vector3 = lay.tree_pos[i]
		if r < 0.22 or h < 5.0 or absf(pos.y - FrontierTerrain.height_at(pos.x, pos.z)) > 0.05:
			continue
		var d := pos.distance_to(Vector3(0, 0, -30))
		if d < best and _clear_round(pos, r):
			best = d
			axis = pos
			radius = r
			top = pos.y + h - 0.3
			tree_i = i
	return best < INF


func _clear_round(pos: Vector3, r: float) -> bool:
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	q.shape = cap
	var to_open := Vector3(0, 0, -30) - pos
	to_open.y = 0.0
	var at := pos + to_open.normalized() * (r + 0.6)
	q.transform = Transform3D(Basis(), Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.95, at.z))
	return space.intersect_shape(q, 4).is_empty()


## E tapped (the interactor acts on its target when E is let go of before a hold).
func _tap_e() -> void:
	Input.action_press(ThrownPickup.INTERACT)
	await _fr(8)
	Input.action_release(ThrownPickup.INTERACT)
	await _fr(4)


## Runs until `done` is true or `max_s` passes (physics frames at 120 per second).
func _until(done: Callable, max_s: float) -> void:
	for i in int(max_s * 120.0):
		if done.call():
			return
		await physics_frame


func _tier(g: PlayerGrip) -> int:
	return int(g._perch_cur.get("tier", -1)) if g.perched else -1


func _climb() -> void:
	var to_open := Vector3(0, 0, -30) - axis
	to_open.y = 0.0
	var at := axis + to_open.normalized() * (radius + 0.55)
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO
	var to := axis - p.global_position
	p.yaw = atan2(-to.x, -to.z)
	p.pitch = 0.0
	await _fr(90)
	var g := p.grip
	var it := p.interactor
	# G: a tree is not gripped any more, E climbs it
	Input.action_press("grip")
	await _fr(30)
	Input.action_release("grip")
	await _fr(10)
	_expect(g.state == PlayerGrip.OFF and not g.perched and it._notice.text == "E to climb",
			"G: at a tree's trunk G grips nothing and says E climbs (state %d, \"%s\")" % [g.state, it._notice.text])
	# up: looking up the trunk, E's prompt is the climb; E shinnies up to the first branches
	p.pitch = 0.45
	await _fr(30)
	_expect(it.target == g.tree_climb and it._label.text.ends_with("Climb up"),
			"up: looking up the trunk the prompt is Climb up (\"%s\")" % it._label.text)
	await _tap_e()
	await _fr(60)
	_expect(g.state != PlayerGrip.OFF and g.gripped != null and g.gripped.is_in_group(&"trees") and g._auto == 1,
			"up: E takes hold of the trunk to shinny up it (state %d, auto %d)" % [g.state, g._auto])
	# fade: on its trunk, the tree climbed is the one kept whole (the trunk under the grip looked up)
	_expect(_keeps(axis) and g.climbed_tree.distance_to(axis) < 0.01 and _clear(&"veg_clear_c").w > 4.0,
			"fade: on its trunk the tree climbed is kept whole, the others clear round the climber (d %s, c.w %.1f)" %
			[_clear(&"veg_clear_d"), _clear(&"veg_clear_c").w])
	await _until(func() -> bool: return g.perched or g.state == PlayerGrip.OFF, 20.0)
	await _fr(60)
	_expect(g.perched and p.perch == g and g.state == PlayerGrip.OFF and _tier(g) == 0,
			"up: E from the ground reaches the first branch (perched %s, state %d, tier %d)" % [g.perched, g.state, _tier(g)])
	if not g.perched:
		return
	var spot := p.global_position
	_expect(p.is_crouching and p.is_on_floor(), "perch: crouched on the branch's floor (crouch %s, floor %s)" % [p.is_crouching, p.is_on_floor()])
	_expect(spot.y > top - 0.6 and spot.y < top + 0.5, "perch: at the crown's start (%.2f m, crown %.2f m)" % [spot.y, top])
	var d := Vector2(spot.x - axis.x, spot.z - axis.z).length()
	_expect(d > radius + 0.2 and d < radius + 0.8, "perch: out on the branch (%.2f m from the axis)" % d)
	# fade: on the branch the same tree is kept whole; level its crown under the climber stays, looking down it clears
	var pitch0 := p.pitch
	p.pitch = 0.0
	await _fr(6)
	var level := _clear(&"veg_clear_d")
	p.pitch = -1.0
	await _fr(6)
	var looking_down := _clear(&"veg_clear_d")
	p.pitch = pitch0
	await _fr(6)
	_expect(_keeps(axis) and level.y == 0.0 and looking_down.y > 0.95,
			"fade: perched, the tree climbed kept whole; its crown under the climber clears only looking down (%.2f level, %.2f down)" %
			[level.y, looking_down.y])
	# the move keys do not walk off it (nor climb: W and S do nothing on a branch); a tap of Space does not jump off
	for k: String in ["move_right", "move_forward", "move_back"]:
		Input.action_press(k)
		await _fr(90)
		Input.action_release(k)
	Input.action_press("jump")
	await _fr(12)
	Input.action_release("jump")
	await _fr(60)
	_expect(g.perched and _tier(g) == 0 and p.global_position.distance_to(spot) < 0.15,
			"perch: the move keys and a tap of Space keep it on its branch (moved %.2f m, tier %d)" % [p.global_position.distance_to(spot), _tier(g)])
	# the look is free on the branch: round to face the trunk (the way back along the branch's way out) and it stays
	var toward: Vector3 = -g._perch_dir
	p.yaw = atan2(-toward.x, -toward.z)
	await _fr(30)
	var seen := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	_expect(g.perched and seen.dot(toward) > 0.98, "perch: the look can turn all the way round to face the trunk (%.2f)" % seen.dot(toward))
	# G on a branch says how to climb, and keeps it there
	Input.action_press("grip")
	await _fr(30)
	Input.action_release("grip")
	await _fr(10)
	_expect(g.perched and g.state == PlayerGrip.OFF and it._notice.text.begins_with("E to climb up"),
			"perch: G keeps it on the branch and says how to climb (\"%s\")" % it._notice.text)
	# resting, and a weapon in hand works there
	g.stamina = 30.0
	await _fr(240)
	_expect(g.perched and g.stamina > 60.0, "rest: crouched on the branch the grip refills (%.0f)" % g.stamina)
	_expect(p.weapon != null and not p.climbing, "perch: the player's own weapon in hand (%s)" % p.weapon_key)
	Input.action_press("aim")
	await _fr(60)
	_expect(p.weapon.aim > 0.5, "perch: aiming from the branch (aim %.2f)" % p.weapon.aim)
	var body := p.visual.find_children("*", "GeometryInstance3D", true, false)
	var faded := body.filter(func(m: Node) -> bool: return (m as GeometryInstance3D).transparency > 0.4).size()
	var cam_d := p.camera.global_position.distance_to(p.spring_arm.global_position)      # (round 4: the camera sits under CameraTilt)
	_expect(p.spring_arm.spring_length < 1.8 and faded > 0, "perch: aiming, the camera comes in (%.2f m, %.2f m drawn) and the body fades (%d of %d meshes)" %
			[p.spring_arm.spring_length, cam_d, faded, body.size()])
	Input.action_release("aim")
	await _fr(60)
	cam_d = p.camera.global_position.distance_to(p.spring_arm.global_position)
	_expect(p.spring_arm.spring_length > 1.9 and p.spring_arm.spring_length < 2.6 and cam_d < 2.7,
			"perch: not aiming, the branch's nearer camera (%.2f m, %.2f m drawn)" % [p.spring_arm.spring_length, cam_d])
	# higher: E climbs to the branch above (the prompt there is Climb up), and again
	p.pitch = 0.0
	await _fr(20)
	_expect(it.target == g.tree_climb and it._label.text.ends_with("Climb up"),
			"higher: on a branch the prompt is Climb up (\"%s\")" % it._label.text)
	var y0 := p.global_position.y
	g.stamina = g.stamina_max
	await _tap_e()
	await _until(func() -> bool: return g.perched and _tier(g) == 1, 4.0)
	await _fr(30)
	var y1 := p.global_position.y
	_expect(g.perched and _tier(g) == 1 and y1 > y0 + 1.2, "higher: E climbs to the branch above (tier %d, %.2f -> %.2f m)" % [_tier(g), y0, y1])
	await _tap_e()
	await _until(func() -> bool: return g.perched and _tier(g) == 2, 4.0)
	await _fr(30)
	var y2 := p.global_position.y
	_expect(g.perched and _tier(g) == 2 and y2 > y1 + 1.2, "higher: E again, the next one (tier %d, %.2f -> %.2f m)" % [_tier(g), y1, y2])
	_expect(_keeps(axis), "fade: up in the crown the tree climbed is still the one kept whole (d %s)" % _clear(&"veg_clear_d"))
	print("two branches up at %.2f m" % y2)
	# lower: "Climb down" from E's hold list, then C
	var acts: Array = g.tree_climb.interact_actions(p)
	var ids := acts.map(func(a: Dictionary) -> String: return String(a.id))
	_expect("down" in ids and "Climb down" in acts.map(func(a: Dictionary) -> String: return String(a.text)),
			"lower: E's hold list has Climb down on a branch (%s)" % str(acts))
	g.tree_climb.interact_action(p, "down")
	await _until(func() -> bool: return g.perched and _tier(g) == 1, 4.0)
	await _fr(30)
	_expect(g.perched and _tier(g) == 1 and absf(p.global_position.y - y1) < 0.3,
			"lower: Climb down comes down to the branch below (tier %d, %.2f m, was %.2f)" % [_tier(g), p.global_position.y, y1])
	Input.action_press("crouch")
	await _fr(6)
	Input.action_release("crouch")
	await _until(func() -> bool: return g.perched and _tier(g) == 0, 4.0)
	await _fr(30)
	_expect(g.perched and _tier(g) == 0 and absf(p.global_position.y - y0) < 0.3,
			"lower: C comes down to the first branches (tier %d, %.2f m, first %.2f)" % [_tier(g), p.global_position.y, y0])
	# down: C from the first branches, down the trunk and the drop onto the ground
	var hp0 := p.health
	Input.action_press("crouch")
	await _fr(6)
	Input.action_release("crouch")
	await _fr(30)
	_expect(not g.perched and g.state != PlayerGrip.OFF and g._auto == -1, "down: C off the first branches takes hold of the trunk to go down it (state %d)" % g.state)
	await _until(func() -> bool: return g.state == PlayerGrip.OFF and p.is_on_floor(), 12.0)
	await _fr(120)
	var ground := FrontierTerrain.height_at(p.global_position.x, p.global_position.z)
	_expect(g.state == PlayerGrip.OFF and not g.perched and p.is_on_floor() and p.global_position.y < ground + 0.3 and p.health >= hp0 - 0.01,
			"down: down the trunk and dropped onto the ground, unhurt (y %.2f, ground %.2f, health %.0f -> %.0f)" % [p.global_position.y, ground, hp0, p.health])
	# fade: off the tree everything is whole again (the clear off, no tree named)
	_expect(_clear(&"veg_clear_b").w == 0.0 and _clear(&"veg_clear_d") == Vector4.ZERO and not g.climbed_tree.is_finite(),
			"fade: down from the tree nothing is cleared (b.w %.2f, d %s)" % [_clear(&"veg_clear_b").w, _clear(&"veg_clear_d")])
	# no crawl: held on a tree's trunk (as the shinny holds it), the move keys do not move the climber up, down or round it
	var hit: Dictionary = g._trunk_hit({"axis": axis, "r": radius}, p.global_position.y + PlayerGrip.BODY_BELOW_PELVIS)
	_expect(not hit.is_empty() and g._begin(hit.collider, hit.position, hit.normal, Vector3.UP, "hang"), "no crawl: held on the trunk")
	await _fr(150)
	var a0: Vector3 = g.anchor.global_position if g.anchor else Vector3.ZERO
	for k: String in ["move_forward", "move_back", "move_right"]:
		Input.action_press(k)
		await _fr(180)
		Input.action_release(k)
	var moved := g.anchor.global_position.distance_to(a0) if g.anchor else -1.0
	_expect(g.state == PlayerGrip.HOLD and moved >= 0.0 and moved < 0.05,
			"no crawl: W, S and D do not crawl a tree's trunk (moved %.2f m, state %d)" % [moved, g.state])
	Input.action_press("grip")
	await _fr(6)
	Input.action_release("grip")
	await _fr(120)
	# felled: its branches go with it (user 2026-09-28: "when we fell a tree, the climbable branches are still there")
	var pb := p.get_node_or_null("PerchBranches") as PerchBranches
	var near_top := Vector3(axis.x, top, axis.z)
	_expect(pb != null and not pb.perch_at(near_top).is_empty(), "felled: the standing tree has its perch")
	VegHarvest.find(self).remove_tree(tree_i)
	await _fr(2)
	var left := 0
	for c in pb.get_children() if pb else []:
		var n := c as Node3D
		if n and not n.is_queued_for_deletion() and Vector2(n.global_position.x - axis.x, n.global_position.z - axis.z).length() < 2.2:
			left += 1
	_expect(pb != null and pb.perch_at(near_top).is_empty() and left == 0,
			"felled: no branch or perch floor left where the tree stood (%d)" % left)
