extends SceneTree
## The player's death is a ragdoll (PlayerRagdoll.knock(dying), user 2026-09-30: "ragdoll physics on deaths shots arrows"),
## on the climbing yard's flat ground, headless:
##
##   Godot --headless --path . -s tests/climb/test_death_ragdoll.gd -- --no-capture
##
##   shot     a killing ball: the player is dead and down as a ragdoll, thrown the way the ball went; input off
##   stays    it comes to rest and stays down (no get-up) while dead
##   respawn  respawn(): alive, on their feet, the ragdoll ended, the weapon (slung with the body) back in the hands
##   arrow    a light blow (an arrow) kills and pushes less than the ball did
##   bled     dying of blood loss (no blow): the body goes limp where it stands
## Ends with "DEATH RAGDOLL TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	var yard := current_scene.get("yard") as ClimbYard
	yard.giant.paces = false
	var at := Vector3(0.0, 0.0, -140.0)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	p.global_position = at
	p.velocity = Vector3.ZERO
	await _fr(120)
	var ball := await _die_by(60.0, Vector3(1.0, 0.0, 0.0), "a ball")
	var arrow := await _die_by(8.0, Vector3(1.0, 0.0, 0.0), "an arrow")
	_expect(arrow + 0.3 < ball, "an arrow pushes less (%.2f m) than the ball (%.2f m)" % [arrow, ball])
	await _bled()
	if fails.is_empty():
		print("DEATH RAGDOLL TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("DEATH RAGDOLL TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


## Killed by a blow of `damage` along `dir`; returns how far the body went.
func _die_by(damage: float, dir: Vector3, what: String) -> float:
	var r := PlayerRagdoll.of(p)
	var start := p.global_position
	p.health = 0.5
	p.apply_hit(damage, start + Vector3.UP, dir, null, "body")
	_expect(p.is_dead, "%s: dead" % what)
	_expect(r.is_down() and p.kneeling == r, "%s: down as a ragdoll" % what)
	await _fr(480)
	var went := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	_expect(r.phase == "thrown" and p.is_dead, "%s: stays down at rest (no get-up), %.2f m off" % [what, went])
	p.respawn()
	await _fr(240)
	_expect(not p.is_dead and not r.is_down() and p.kneeling == null, "%s: respawn: up, the ragdoll ended" % what)
	_expect(p.is_on_floor(), "%s: respawn: on their feet" % what)
	return went


func _bled() -> void:
	var r := PlayerRagdoll.of(p)
	p.health = 1.0
	p.lose_blood(5.0)
	_expect(p.is_dead and r.is_down(), "bled: dead, limp")
	await _fr(240)
	p.respawn()
	await _fr(240)
	_expect(not p.is_dead and not r.is_down(), "bled: respawn ends it")
