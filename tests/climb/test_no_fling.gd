extends SceneTree
## Nothing made far off flings a player standing in the middle of the world (the fort's middle). A moving body
## (AnimatableBody3D) made at the world's origin and moved to its place after takes that jump as its first physics
## step, and flings whatever stood at the origin: a chopped-off mammoth leg once threw a player in the fort at some
## 26 km/s, out of the world (user 2026-09-27: "fix the fall out the world"). On the climbing yard, headless:
##
##   Godot --headless --path . -s tests/climb/test_no_fling.gd
##
##   limb      the player at the fort's middle; the mammoth, 160 m off, killed and a leg chopped off: he stays put
##   mammoth   a new mammoth built 40 m off while he stands there: he stays put; its bodies collide once in place
## Ends with "NO FLING TEST PASSED (<n> checks)" or "NO FLING TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var gi: StandInGiant


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	gi = (current_scene.get("yard") as ClimbYard).giant
	gi.paces = false
	_stand()
	await _fr(60)
	await _limb()
	await _mammoth()
	if fails.is_empty():
		print("NO FLING TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("NO FLING TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


## The player at the world's middle (the fort's).
func _stand() -> void:
	p.global_position = Vector3(0.0, FrontierTerrain.height_at(0.0, 0.0) + 0.1, 0.0)
	p.velocity = Vector3.ZERO


## Over `n` frames: the furthest the player got from where he stood, and his fastest.
func _watch(n: int) -> Vector2:
	var at := p.global_position
	var most := Vector2.ZERO
	for i in n:
		await physics_frame
		most.x = maxf(most.x, p.global_position.distance_to(at))
		most.y = maxf(most.y, p.velocity.length())
	return most


func _limb() -> void:
	gi.die("L")
	await _fr(int(3.5 * 120))
	var b := gi.butchery
	if b == null:
		_expect(false, "limb: the mammoth dead, its butchery")
		return
	_stand()
	await _fr(30)
	b.axe_strike({"key": "foreleg_r"}, 100.0)
	var limb: LimbCarcass = b.dropped.get("foreleg_r")
	var most := await _watch(120)
	_expect(limb != null and is_instance_valid(limb), "limb: the mammoth 160 m off, a leg chopped off it")
	_expect(most.x < 0.3 and most.y < 1.0, "limb: the player in the fort's middle stays put (moved %.2f m, at most %.1f m/s)" % [most.x, most.y])
	if limb:
		var d := Vector2(limb.global_position.x - gi.torso.global_position.x, limb.global_position.z - gi.torso.global_position.z).length()
		_expect(d < 8.0, "limb: the leg lies by the carcass (%.1f m from its middle)" % d)


func _mammoth() -> void:
	_stand()
	await _fr(30)
	var g2 := StandInGiant.new()
	g2.name = "Mammoth2"
	g2.player = p
	g2.paces = false
	current_scene.add_child(g2)
	var at := Vector3(0.0, 0.0, -40.0)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	g2.build(Transform3D(Basis(), at))
	var most := await _watch(120)
	_expect(most.x < 0.3 and most.y < 1.0, "mammoth: one built 40 m off while he stands there: he stays put (moved %.2f m, at most %.1f m/s)" % [most.x, most.y])
	# its bodies collide again once in place: a ray down onto its back hits it
	var top := g2.torso.global_position + Vector3.UP * 6.0
	var q := PhysicsRayQueryParameters3D.create(top, g2.torso.global_position)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	_expect(not hit.is_empty() and hit.collider == g2.torso and g2.torso.collision_layer != 0,
			"mammoth: in place, its body collides (a ray onto its back hits %s)" % (str(hit.collider.name) if hit else "nothing"))
