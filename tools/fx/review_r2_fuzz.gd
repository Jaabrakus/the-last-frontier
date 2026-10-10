extends SceneTree
## Review round 2 probe (read-only): every entry of the four sb_fx tables played through SbFx._play with the argument
## combinations the seams can produce but the tests do not use (no caster, no point, a freed node, a node outside the tree,
## a degenerate travel, a non-finite point), then every imported effect through SpellFx.spawn with odd option mixes. The log is
## then grepped for "ERROR" (script errors cost nothing here, they only print). Last line "FUZZ done n plays".
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r2_fuzz.gd
## (every element forced on)

var stage: Node3D
var cam: Camera3D
var body: CharacterBody3D
var plays := 0
var errors_seen := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mk_body(el: String) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	cs.position = Vector3.UP * 0.9
	b.add_child(cs)
	stage.add_child(b)
	Bending.of(b).element = el
	return b


func _run() -> void:
	SbFx.allow_headless = true
	SbFx.reload_data()
	SbFx.force_on = true
	SbFx.force_elements = {"earth": true, "water": true, "fire": true, "air": true}
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.global_position = Vector3(0, 3, 10)
	cam.current = true
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	cs.shape = bx
	ground.add_child(cs)
	stage.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	body = _mk_body("fire")
	await _frames(3)
	var player := SpellFx.of(stage)
	var todo: Array = []
	for el: String in SbFx.ELEMENTS:
		var t := SbFx.table(el)
		for key: String in t:
			for role: String in t[key]:
				if t[key][role] is Dictionary and not role.begins_with("_"):
					todo.append([el, key, role])
	print("FUZZ %d entries" % todo.size())
	var variants := ["no caster, no ctx", "caster, no ctx", "no caster, at only", "caster, node in tree", "freed caster, freed node",
			"node outside the tree", "degenerate travel", "non-finite at", "zero dir", "volley"]
	for v in variants.size():
		var n0 := plays
		for i in todo.size():
			var el: String = todo[i][0]
			var key: String = todo[i][1]
			var role: String = todo[i][2]
			var by: Variant = null
			var ctx := {}
			var extra: Node = null
			match v:
				0:
					pass
				1:
					by = body
				2:
					ctx = {"at": Vector3(0, 1, -3)}
				3:
					extra = Node3D.new()
					stage.add_child(extra)
					(extra as Node3D).global_position = Vector3(2, 1, -2)
					by = body
					ctx = {"node": extra, "at": Vector3(2, 1, -2), "dir": Vector3.FORWARD, "size": Vector3(4, 2, 0.6), "radius": 1.2, "width": 2.0}
				4:
					var fb := _mk_body("earth")
					extra = Node3D.new()
					stage.add_child(extra)
					by = fb
					ctx = {"node": extra, "at": Vector3(1, 1, -2)}
					fb.free()
					extra.free()
				5:
					extra = Node3D.new()
					by = body
					ctx = {"node": extra, "at": Vector3(0, 1, -3)}
				6:
					by = body
					ctx = {"at": Vector3(0, 1, -3), "to": Vector3(0, 1, -3), "dir": Vector3.FORWARD}
				7:
					by = body
					ctx = {"at": Vector3.INF, "dir": Vector3(NAN, 0, 0)}
				8:
					by = body
					ctx = {"at": Vector3(0, 1, -3), "dir": Vector3.ZERO, "normal": Vector3.ZERO}
				9:
					by = body
					ctx = {"at": Vector3(0, 1, -3), "info": {"volley_id": 7 + i % 3}}
			ctx["el"] = el
			var r := SbFx._play(by, key, role, ctx)
			plays += 1
			if v == 3 and extra != null:
				extra.queue_free()
			if v == 5 and extra != null:
				extra.free()
			if i % 20 == 19:
				await process_frame
		await _frames(4)
		print("FUZZ variant '%s': %d plays, playing now %d" % [variants[v], plays - n0, player.playing_count()])
		player.kill_all()
		await _frames(2)
	# SpellFx.spawn option mixes on every imported effect
	var ids := Array(SpellFx.effect_ids())
	var mover := Node3D.new()
	stage.add_child(mover)
	var k := 0
	for id: String in ids:
		var optsets := [
			{"scene": stage},
			{"scene": stage, "follow_basis": "motion", "scale": 0.0},
			{"scene": stage, "follow_basis": "fixed", "scale": 4.0, "tint": Color(1, 0, 0, 0.5), "life": 0.5},
			{"scene": stage, "attach": true, "time_scale": 3.0, "hide": ["#0", "#1", "nonexistent"]},
			{"scene": stage, "one_shot": false, "ground_y": 5.0, "camera": cam},
		]
		for o in optsets:
			var where: Variant = mover if k % 2 == 0 else Transform3D(Basis.looking_at(Vector3(1, 0.3, 0.2)), Vector3(0, 1, -2))
			var h := SpellFx.spawn(id, where, o)
			plays += 1
			k += 1
			if h != null and k % 7 == 0:
				mover.global_position += Vector3(0.5, 0, 0)
		await process_frame
		if k % 40 == 0:
			await _frames(3)
	await _frames(30)
	for i in 20:
		mover.global_position += Vector3(0.3, 0, 0)
		await process_frame
	mover.free()                         # attached/followed effects lose their node
	await _frames(10)
	player.kill_all()
	await _frames(3)
	print("FUZZ done %d plays" % plays)
	quit(0)
