extends SceneTree
## Iron Man (GameSettings.iron_man; user 2026-09-30: "this should be a iron man mode", "do it"), headless, in the real level:
##
##   Godot --headless --path . -s tests/save/test_iron_man.gd -- save=on ironman=on survival=on
##
##   saved    a save says it is an Iron Man save (meta "iron")
##   maimed   a cut cord (a ball through T10) keeps the legs gone (maim_legs) and the save keeps it: cleared, loaded back, it is back
##   death    a death ends the character: the saves are erased at once, and when the death screen is done the run ends (run_ended)
##            and the player does not wake
## Ends with "IRON MAN TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var shooter := Node.new()
var ended := false


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


func _part(a: Anatomy, nm: String) -> Vector3:
	for d in a.parts:
		if d.name == nm:
			return (d.node as Node3D).global_position
	return Vector3.INF


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	await _fr(30)
	current_scene.add_child(shooter)
	p = current_scene.get_node("Player") as FrontierPlayer
	var sg := SaveGame.find(self)
	var dr := DeathRule.find(self)
	_expect(sg != null and dr != null and GameSettings.iron_man(), "the level has its saves and death rule, in Iron Man")
	if sg == null or dr == null:
		quit(1)
		return
	dr.run_ended.connect(func() -> void: ended = true)
	await _fr(60)
	_expect(sg.save_game("auto") == OK, "saved")
	var doc := SaveGame.read_slot("auto")
	_expect(bool((doc.get("meta", {}) as Dictionary).get("iron", false)), "the save says it is an Iron Man save")
	# the cord
	var an := Anatomy.attach_to(p.skeleton)
	var fwd := -p.global_basis.z
	p.apply_hit(30.0, _part(an, "T10 vertebra") - fwd * 0.3, fwd, shooter, "body")
	await _fr(10)
	_expect(not p.is_dead and p.maim_legs, "a ball through T10: the legs gone")
	var d := SaveParts.save_player(current_scene)
	_expect(bool((d.get("maim", {}) as Dictionary).get("legs", false)), "the save has the cut cord")
	p.maim_legs = false
	SaveParts.load_player(current_scene, d)
	_expect(p.maim_legs, "loaded back: still gone")
	PlayerRagdoll.of(p).recover_now()
	await _fr(60)
	# death
	_expect(FileAccess.file_exists(SaveGame.dir() + "auto.json"), "a save is there before the death")
	p.apply_hit(30.0, _part(an, "Brain") - fwd * 0.3, fwd, shooter, "body")
	_expect(p.is_dead, "a ball through the brain: dead")
	_expect(not FileAccess.file_exists(SaveGame.dir() + "auto.json"), "the saves are erased at once")
	await _fr(int((DeathRule.DEATH_S + 1.0) * Engine.physics_ticks_per_second))
	_expect(ended and p.is_dead, "the run ends, and the player does not wake")
	if fails.is_empty():
		print("IRON MAN TEST PASSED (%d checks)" % checks)
	else:
		print("IRON MAN TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
