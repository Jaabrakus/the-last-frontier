extends SceneTree
## Pins the engine behaviour the traversal hand-back relies on (design: source/graph_analysis/traversal/
## traversal_design.md, 8.6):
##   1. CharacterBody3D.is_on_floor() goes stale while the body is moved by move_and_collide() or by
##      direct placement (the traversal's owned modes): it keeps the last move_and_slide() result.
##   2. The hand-back refresh "velocity = 0; move_and_slide(); if not is_on_floor(): apply_floor_snap()"
##      fixes it in the same physics tick, in both directions (stale true in the air, stale false on a
##      top), and snaps a body that stands up to floor_snap_length above a floor.
## Pure engine test (no project scripts). Prints one line per check and TRAVERSAL FLOOR REFRESH OK/FAILED.
##
##   Godot --headless --path <Frontier> -s res://tests/traversal/test_floor_refresh.gd

var body: CharacterBody3D
var tick := 0
var failures := 0


func _initialize() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(20, 1, 20))          # ground, top at y = 0
	_box(Vector3(5, 1.5, 0), Vector3(2, 3, 2))             # a top at y = 3
	body = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	root.add_child(body)
	body.position = Vector3(0, 0.02, 0)
	physics_frame.connect(_step)


func _box(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	b.add_child(cs)
	root.add_child(b)


func _refresh() -> void:
	var v := body.velocity
	body.velocity = Vector3.ZERO
	body.move_and_slide()
	if not body.is_on_floor():
		body.apply_floor_snap()
	body.velocity = v


func _check(label: String, want: bool) -> void:
	var got := body.is_on_floor()
	var ok := got == want
	if not ok:
		failures += 1
	print("  %-4s %-60s is_on_floor=%s (want %s)" % ["ok" if ok else "FAIL", label, got, want])


func _step() -> void:
	tick += 1
	match tick:
		1, 2, 3, 4:
			body.velocity = Vector3(0, -1, 0)
			body.move_and_slide()
			if tick == 4:
				_check("grounded by move_and_slide", true)
		5:
			body.move_and_collide(Vector3(0, 1.5, 0))
			_check("stale after move_and_collide +1.5 m (engine keeps true)", true)
			_refresh()
			_check("refresh in the air", false)
		6:
			body.global_position = Vector3(5, 3.01, 0)
			_check("stale after placement on a top (engine keeps false)", false)
			_refresh()
			_check("refresh on the top", true)
		7:
			body.global_position = Vector3(0, 2.0, 0)
			_check("stale after placement mid-air (engine keeps true)", true)
			_refresh()
			_check("refresh mid-air", false)
		8:
			body.global_position = Vector3(0, 0.05, 0)
			_refresh()
			_check("refresh 5 cm above the ground (snap)", true)
			var y := body.global_position.y
			var snapped_ok := absf(y) < 0.005
			if not snapped_ok:
				failures += 1
			print("  %-4s %-60s y=%.4f" % ["ok" if snapped_ok else "FAIL", "snapped onto the ground", y])
		9:
			print("TRAVERSAL FLOOR REFRESH %s (%d failure(s))" % ["OK" if failures == 0 else "FAILED", failures])
			quit(0 if failures == 0 else 1)
