extends SceneTree
## The two tandem poses that are in the game (user 2026-09-30: "only keep two": Happy Baby, updated, and the doggy pose, the puppy), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/tandem/test_tandem_poses.gd -- survival=on
##   in the level   the tandem controller and the puppy (with its pair) are on the player; nothing of the Wide Kneel or the Reverse Plank
##   Happy Baby     starts (a woman leads); the crawl no longer does
##   puppy          starts and stops (Ctrl+P's own controller), the player kneeling in it while it holds
##   yoga together  the pose menu offers Happy Baby and the puppy
## Ends with "TANDEM POSES TEST PASSED (<n> checks)" or "TANDEM POSES TEST FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 20:
		await process_frame
	var p := current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(p != null, "the level has the player")
	if p == null:
		quit(1)
		return
	p.ignore_mouse_capture = true
	var tandem := p.get_node_or_null("TandemPoses")
	var puppy := p.get_node_or_null("PuppyPose")
	var pair := p.get_node_or_null("PuppyTandem")
	_expect(tandem != null and puppy != null and pair != null, "the tandem controller, the puppy and its pair are on the player")
	_expect(p.get_node_or_null("WideKneel") == null and p.get_node_or_null("ReversePlank") == null, "no Wide Kneel or Reverse Plank")
	_expect(not FileAccess.file_exists("res://features/tandem/wide_kneel.gd") and not FileAccess.file_exists("res://features/tandem/reverse_plank.gd"), "and their scripts are gone")
	# the yoga-together menu
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/companion/intimacy.json"))
	var ids := []
	for pz: Dictionary in (d as Dictionary).get("poses", []):
		ids.append(String(pz.id))
	_expect(ids == ["yoga", "puppy"], "the yoga-together menu offers Happy Baby and the puppy (%s)" % str(ids))
	_expect(Intimacy.DEFAULTS.poses.size() == 2, "and so do its defaults")
	await _frames(30)
	# the crawl is out
	_expect(tandem.start_pose("crawl") == false and String(tandem.mode) == "", "the crawl no longer starts")
	# Happy Baby (a woman leads)
	if not tandem.is_woman(p) and p.appearance != null:
		var look: Dictionary = AppearanceStore.default_look()
		look["sex"] = 0.0
		p.appearance.apply(look)
		await _frames(10)
	var yoga_ok: bool = tandem.start_pose("yoga")
	await _frames(40)
	_expect(yoga_ok and String(tandem.mode) == "yoga", "Happy Baby starts (mode %s)" % str(tandem.mode))
	tandem.stop_pose()
	await _frames(20)
	_expect(String(tandem.mode) == "" and p.kneeling == null, "and stops")
	# the puppy
	var pup_ok: bool = puppy.start()
	await _frames(40)
	_expect(pup_ok and puppy.active and p.kneeling == puppy, "the puppy starts, the player kneeling in it")
	puppy.flinch()
	await _frames(20)
	_expect(puppy.active, "K's forward flinch plays and it holds")
	# yoga together: an existing body (the husband's stand-in) kneels upright behind her as the partner
	var man := TandemProxy.make(p.get_parent(), {}, p.global_position + p.skeleton.get_parent().global_basis * Vector3(0, 0, -0.3), p.rotation.y)
	await _frames(30)
	var took: bool = pair.take_partner(man)
	await _frames(40)
	_expect(took and pair.joined and pair.partner == man, "an existing body takes the upright kneel behind the puppy (yoga together)")
	pair.react()
	await _frames(30)
	_expect(pair.joined, "and K's paired flinch plays")
	pair.stop_pair()
	await _frames(20)
	_expect(not pair.joined and is_instance_valid(man) and man.kneeling == null, "the pair ends and the partner's body is his again, not freed")
	man.queue_free()
	puppy.stop()
	await _frames(20)
	_expect(not puppy.active and p.kneeling == null, "and it stops")
	if fails.is_empty():
		print("TANDEM POSES TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("TANDEM POSES TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
