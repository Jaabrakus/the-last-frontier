extends SceneTree
## Climbing a tree with the grip (user 2026-09-27: "these grips should allow us to climb up trees now"), headless, on
## the real level: a sturdy tree near the fort (a trunk collider 0.22 m or more across and 5 m or more to its crown).
##   grab     G facing the trunk grabs it (the trunks are GripSurface "bark")
##   up       W climbs the bare trunk to where the crown starts (the collider's top): no pulling up onto the trunk's
##            top, the climber pulls up onto a branch there and crouches on it (PerchBranches)
##   perch    the move keys and a tap of Space keep the climber on the branch; the grip refills there; the player's
##            own weapon is in hand and aims (the camera in nearer, the body faded); G again takes hold of the trunk
##   round    D crawls round the trunk, staying on its bark
##   down     S climbs down; near the ground the climber lets go and drops onto it
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


func _angle(v: Vector3) -> float:
	var d := v - axis
	return atan2(d.x, d.z)


func _climb() -> void:
	var to_open := Vector3(0, 0, -30) - axis
	to_open.y = 0.0
	var at := axis + to_open.normalized() * (radius + 0.55)
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO
	var to := axis - p.global_position
	p.yaw = atan2(-to.x, -to.z)
	await _fr(90)
	Input.action_press("grip")
	await _fr(150)
	var g := p.grip
	_expect(g.state == PlayerGrip.HOLD and g.gripped != null and g.gripped.is_in_group(&"trees"),
			"grab: G at the trunk grips it (state %d, %s)" % [g.state, g.gripped.name if g.gripped else "-"])
	if g.state == PlayerGrip.OFF:
		Input.action_release("grip")
		return
	# up to the crown
	Input.action_press("move_forward")
	var last := -INF
	var still := 0
	var went_up := false
	for i in 120 * 20:
		await physics_frame
		if g.state == PlayerGrip.UP:
			went_up = true
		if g.state == PlayerGrip.OFF:
			break
		var y := g.anchor.global_position.y
		still = still + 1 if y < last + 0.002 else 0
		last = maxf(last, y)
		if still > 120:
			break
	Input.action_release("move_forward")
	await _fr(60)
	_expect(g.perched and p.perch == g and g.state == PlayerGrip.OFF,
			"up: at the crown, pulled up onto a branch (perched %s, state %d)" % [g.perched, g.state])
	if g.perched:
		var spot := p.global_position
		_expect(p.is_crouching and p.is_on_floor(), "perch: crouched on the branch's floor (crouch %s, floor %s)" % [p.is_crouching, p.is_on_floor()])
		_expect(spot.y > top - 0.6 and spot.y < top + 0.5, "perch: at the crown's start (%.2f m, crown %.2f m)" % [spot.y, top])
		var d := Vector2(spot.x - axis.x, spot.z - axis.z).length()
		_expect(d > radius + 0.2 and d < radius + 0.8, "perch: out on the branch (%.2f m from the axis)" % d)
		# the move keys do not walk off it; a tap of Space does not jump off
		Input.action_press("move_forward")
		Input.action_press("move_right")
		await _fr(120)
		Input.action_release("move_forward")
		Input.action_release("move_right")
		Input.action_press("jump")
		await _fr(12)
		Input.action_release("jump")
		await _fr(60)
		_expect(g.perched and p.global_position.distance_to(spot) < 0.15, "perch: the move keys and a tap of Space keep it on the branch (moved %.2f m)" % p.global_position.distance_to(spot))
		# resting, and a weapon in hand works there
		Input.action_release("grip")
		g.stamina = 30.0
		await _fr(240)
		_expect(g.perched and g.stamina > 60.0, "rest: crouched on the branch the grip refills (%.0f)" % g.stamina)
		_expect(p.weapon != null and not p.climbing, "perch: the player's own weapon in hand (%s)" % p.weapon_key)
		var fov0 := p.camera.fov
		Input.action_press("aim")
		await _fr(60)
		_expect(p.weapon.aim > 0.5, "perch: aiming from the branch (aim %.2f)" % p.weapon.aim)
		var body := p.visual.find_children("*", "GeometryInstance3D", true, false)
		var faded := body.filter(func(m: Node) -> bool: return (m as GeometryInstance3D).transparency > 0.4).size()
		_expect(p.spring_arm.spring_length < 1.8 and faded > 0, "perch: aiming, the camera comes in (%.2f m) and the body fades (%d of %d meshes)" %
				[p.spring_arm.spring_length, faded, body.size()])
		Input.action_release("aim")
		await _fr(60)
		_expect(p.spring_arm.spring_length > 1.9 and p.spring_arm.spring_length < 2.6, "perch: not aiming, the branch's nearer camera (%.2f m)" % p.spring_arm.spring_length)
		# back onto the trunk: G again
		Input.action_press("grip")
		await _fr(150)
		_expect(g.state == PlayerGrip.HOLD and g.gripped != null and g.gripped.is_in_group(&"trees") and not g.perched,
				"leave: G takes hold of the trunk again (state %d)" % g.state)
	# round the trunk
	var a0 := _angle(g.anchor.global_position)
	Input.action_press("move_right")
	await _fr(240)
	Input.action_release("move_right")
	await _fr(30)
	var a1 := _angle(g.anchor.global_position)
	var turned := rad_to_deg(absf(wrapf(a1 - a0, -PI, PI)))
	var off := Vector2(g.anchor.global_position.x - axis.x, g.anchor.global_position.z - axis.z).length()
	_expect(g.state == PlayerGrip.HOLD and turned > 25.0, "round: crawled round the trunk (%.0f deg)" % turned)
	_expect(absf(off - radius) < 0.08, "round: on the bark all the way (%.2f m from the axis, radius %.2f)" % [off, radius])
	# down
	Input.action_press("move_back")
	for i in 120 * 25:
		await physics_frame
		if g.state == PlayerGrip.OFF:
			break
	Input.action_release("move_back")
	await _fr(120)
	var ground := FrontierTerrain.height_at(p.global_position.x, p.global_position.z)
	_expect(g.state == PlayerGrip.OFF and p.is_on_floor() and p.global_position.y < ground + 0.3,
			"down: climbed down and dropped onto the ground (y %.2f, ground %.2f)" % [p.global_position.y, ground])
	Input.action_release("grip")
