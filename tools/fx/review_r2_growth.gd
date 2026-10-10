extends SceneTree
## Review round 2 probe (read-only): does any imported effect, played held (looping, one_shot off, as a seam holds it), keep
## adding particles without end? Every effect is played at once for 12 s of frames; its live particle count is read at 2, 6 and
## 12 s; an effect whose count at 12 s is more than 1.5 x its count at 6 s (and above 60) grows without bound. Headless.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r2_growth.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.current = true
	await process_frame
	var ids := Array(SpellFx.effect_ids())
	var hs: Array = []
	for i in ids.size():
		hs.append(SpellFx.spawn(ids[i], Vector3(float(i % 9) * 3.0, 1.0, -float(i / 9) * 3.0), {"scene": stage, "one_shot": false}))
	var at := {}
	for f in 60 * 12:
		await process_frame
		if f + 1 in [120, 360, 720]:
			var counts: Array = []
			for h in hs:
				counts.append(h.particle_count() if h != null else 0)
			at[f + 1] = counts
	var grow: Array = []
	for i in ids.size():
		var a: int = at[360][i]
		var b: int = at[720][i]
		if b > 60 and float(b) > 1.5 * float(maxi(a, 1)):
			grow.append("%s %d -> %d -> %d" % [String(ids[i]).get_file(), at[120][i], a, b])
	print("REVIEW growth: %d effects held 12 s; growing without bound (count at 12 s > 1.5 x at 6 s, > 60): %d" % [ids.size(), grow.size()])
	for g in grow:
		print("  " + g)
	var big: Array = []
	for i in ids.size():
		if int(at[720][i]) > 300:
			big.append("%s %d" % [String(ids[i]).get_file(), at[720][i]])
	print("  above 300 particles at 12 s: %s" % [big])
	var player := SpellFx.of(stage)
	player.kill_all()
	quit(0)
