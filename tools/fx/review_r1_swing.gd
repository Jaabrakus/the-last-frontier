extends SceneTree
## Review round 1 probe (read-only): water_redirect/redirect "swing" (data/bending/sb_fx/water.json) plays CB_RiversReflection_FxP
## at a point with no life, no travel and no hold, and that effect's emitters loop forever. How long does it play, and what
## does it do to the max_playing cap (config.json: 40) that every other seam shares?
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r1_swing.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SbFx.allow_headless = true
	SbFx.reload_data()
	SbFx.force_on = true
	SbFx.force_elements = {"earth": true, "water": true, "fire": true, "air": true}
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.current = true
	var body := CharacterBody3D.new()
	stage.add_child(body)
	Bending.of(body).element = "water"
	await process_frame
	var player := SpellFx.of(stage)
	var r := SbFx._play(body, "water_redirect/redirect", "swing", {"at": Vector3(0, 1, -4), "dir": Vector3.FORWARD, "el": "water"})
	var h: SpellFx.Handle = r.handles[0]
	print("REVIEW swing: played %d handle(s), replace=%s" % [r.handles.size(), r.replace])
	for sec in [1, 5, 20, 60, 120]:
		while h.age < sec:
			await process_frame
		print("  after %3d s: playing %s, stopping %s, particles %d, SpellFx playing_count %d" % [sec, h.is_playing(), h.stopping, h.particle_count(), player.playing_count()])
	# 39 more swings (a fight's worth of redirects): the cap
	for i in 39:
		SbFx._play(body, "water_redirect/redirect", "swing", {"at": Vector3(float(i) * 0.1, 1, -4), "dir": Vector3.FORWARD, "el": "water"})
	await process_frame
	var fire_body := CharacterBody3D.new()
	stage.add_child(fire_body)
	Bending.of(fire_body).element = "fire"
	var ok := SbFx.fire(fire_body, "fire_blast/punch", "impact", {"at": Vector3(0, 1, -3), "dir": Vector3.FORWARD, "info": {}})
	print("  playing_count now %d (max_playing %d); a fire punch's impact then plays: %s (false = today's look carries it)" % [
			player.playing_count(), int(SbFx.config().get("max_playing", 40)), ok])
	player.kill_all()
	SbFx.allow_headless = false
	SbFx.force_on = null
	SbFx.force_elements = {}
	quit(0)
