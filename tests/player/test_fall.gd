extends SceneTree
## Falls (user 2026-10-01: "fall damage with broken bones if they jump from too high up; the first set is okay to jump down"):
## a drop under FALL_SAFE_M does nothing; past it the player is hurt; well past it a leg breaks and slows; jumping off a tree's
## first branches (fall_safe_m set to their height) is safe.
##   Godot --headless --path . -s tests/player/test_fall.gd
var fails := 0
var p: FrontierPlayer


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 200:
		await physics_frame
	p = current_scene.get_node_or_null("Player")
	p.ignore_mouse_capture = true
	var at := Vector3(-30.0, 0.0, 30.0)
	var h0 := p.health
	await _drop(at, 3.0)
	_c(is_equal_approx(p.health, h0) and not p.broken_leg, "a 3 m drop: unhurt (%.0f)" % p.health)
	await _drop(at, 6.5)
	_c(p.health < h0 and p.health > h0 - 40.0 and not p.broken_leg, "a 6.5 m drop: hurt, not broken (%.0f)" % p.health)
	p.health = p.max_health
	await _drop(at, 8.5)
	_c(p.broken_leg and p._maim_speed() < 0.7, "an 8.5 m drop: a leg broken, slowed (%.2f)" % p._maim_speed())
	p.broken_leg = false
	p.health = p.max_health
	p.fall_safe_m = 9.0
	await _drop(at, 8.5)
	_c(is_equal_approx(p.health, p.max_health) and not p.broken_leg, "off the first branches (safe to their height): unhurt")
	print("FALL TEST ", "FAILED" if fails > 0 else "PASSED")
	quit(1 if fails > 0 else 0)


func _drop(at: Vector3, h: float) -> void:
	var g := FrontierTerrain.height_at(at.x, at.z)
	p.global_position = Vector3(at.x, g + h, at.z)
	p.velocity = Vector3.ZERO
	for i in 240:
		await physics_frame
		if i > 10 and p.is_on_floor():
			break
	for i in 10:
		await physics_frame


func _c(ok: bool, what: String) -> void:
	print("  ", "ok  " if ok else "FAIL", " ", what)
	if not ok:
		fails += 1
