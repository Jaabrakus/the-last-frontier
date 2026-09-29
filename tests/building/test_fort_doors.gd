extends SceneTree
## The fort's buildings have doors that open (FortHollow): for the cabin, the storehouse (FrontierStructures.doors) and both
## blockhouses (build-menu pieces, FortPlan; their door is the piece's BuiltPiece.door), a shut door stops the player, E opens it
## (the door is the interactor's target), the player walks in through the doorway, and the walls stop them from walking
## through them elsewhere.
##   Godot --headless --fixed-fps 120 --path . -s tests/building/test_fort_doors.gd
var player: FrontierPlayer
var fails := 0


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _stand(at: Vector3, face: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = atan2(-face.x, -face.z)
	player.rotation.y = player.yaw
	player.pitch = 0.0


func _walk(frames: int) -> void:
	Input.action_press(&"move_forward")
	await _frames(frames)
	Input.action_release(&"move_forward")
	await _frames(20)


func _run() -> void:
	await _frames(20)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	await _frames(60)
	var st := current_scene.get_node("Structures") as FrontierStructures
	_expect(st != null and st.doors.size() == 2, "the cabin and the storehouse hang their doors (%d)" % (st.doors.size() if st else 0))
	# the buildings: name -> [FortHollow-style dict in world coordinates, door]
	var entries := {}
	for name: String in FortHollow.BUILDINGS:
		entries[name] = [FortHollow.BUILDINGS[name], st.doors.get(name)]
	var world := BuildWorld.of(self, false)
	_expect(world != null and world.fort_built, "the fort's pieces are built (FortPlan)")
	for q in (world.pieces() if world else []):
		if q.type == "blockhouse":
			var xf := q.global_transform
			var hb: Dictionary = FortPieces.HOLLOW.duplicate()
			hb["c"] = xf * (FortPieces.HOLLOW.c as Vector3)
			hb["pos"] = xf * (FortPieces.HOLLOW.pos as Vector3)
			hb["out"] = (xf.basis * (FortPieces.HOLLOW.out as Vector3)).normalized()
			entries["blockhouse_%s" % ("nw" if q.global_position.x < 0.0 else "se")] = [hb, q.door]
	_expect(entries.size() == 4, "four hollow buildings with doors (%d)" % entries.size())
	for name: String in entries:
		var b: Dictionary = entries[name][0]
		var door: BuildDoor = entries[name][1]
		_expect(door != null and not door.is_open, "%s: its door hangs shut" % name)
		if door == null:
			continue
		var out: Vector3 = b.out
		var centre: Vector3 = b.c
		var pos: Vector3 = b.pos
		# shut: the door stops the player
		_stand(pos + out * 3.0, -out)
		await _frames(30)
		await _walk(220)
		var d0 := (player.global_position - centre).dot(-out)
		var bsize: Vector3 = b.size
		var half: float = (bsize.x if absf(out.x) > 0.5 else bsize.z) * 0.5
		_expect(d0 < half + 0.3 and d0 > 0.0 - 99.0 and (player.global_position - centre).dot(out) > half - 0.2, "%s: the shut door stops the player outside (%.2f m in, wall face at %.2f)" % [name, -(player.global_position - centre).dot(out), half])
		# E opens it
		_stand(pos + out * 1.6, -out)
		await _frames(20)
		door.interact(player)
		var opened := false
		for i in 240:
			await physics_frame
			if door.swing() >= 1.0:
				opened = true
				break
		_expect(door.is_open and opened, "%s: the door swings open" % name)
		# walk in
		_stand(pos + out * 1.6, -out)
		await _frames(20)
		await _walk(300)
		var p := player.global_position
		var inside: bool = absf((p - centre).dot(FortHollow.along_of(out))) < (bsize.z if absf(out.x) > 0.5 else bsize.x) * 0.5 and (p - centre).dot(out) < half - 0.3
		_expect(inside, "%s: the player walked in through the doorway (at %s, building centre %s)" % [name, p, centre])
		door.set_open(false, true)
		await _frames(10)
	print("FORT DOORS TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)
