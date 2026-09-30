extends SceneTree
## Look-check of the two building puzzles' screens (BarkFitScreen, PitchScreen), windowed:
##   Godot --path . --resolution 960x600 -s tests/boats/puzzle_shots.gd -- out=<abs dir>
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	# the bark, guided, part way through
	var s := BoatPuzzleScreen.open(self, "bark_fit", true) as BarkFitScreen
	await process_frame
	for i in 60:
		s.puzzle.step(0.05)
		var k := s.puzzle.slackest()
		if s.puzzle.tension[k] < s.puzzle.lo + 0.05:
			s.puzzle.press(k)
	s.puzzle.tension[5] = 0.9
	await _shot("bark_guided")
	s.queue_free()
	paused = false
	await process_frame
	var u := BoatPuzzleScreen.open(self, "bark_fit", false) as BarkFitScreen
	await process_frame
	for i in 40:
		u.puzzle.step(0.05)
		u.puzzle.press(i % 7)
	await _shot("bark_unguided")
	u.queue_free()
	paused = false
	await process_frame
	var p := BoatPuzzleScreen.open(self, "pitch", true) as PitchScreen
	await process_frame
	var x := 0.0
	while x < 1.0:
		x += 0.012
		p.puzzle.brush(x, 0.02)
	p.puzzle.thick[30] += 1.3
	p.puzzle.thick[12] = 0.1
	p._down = true
	p._x = 0.7
	await _shot("pitch_guided")
	p.queue_free()
	paused = false
	await process_frame
	var hull: Dictionary = (BoatBuild.plans().birchbark as Dictionary).hull
	var sb := BoatPuzzleScreen.open(self, "bed_stakes", true, {"hull": hull}) as StakeBedScreen
	await process_frame
	for i in 9:
		var tg: Vector2 = sb.puzzle.targets[i]
		sb.puzzle.place(tg + Vector2(0.09 * float(i % 3 - 1), 0.12 * float(i % 2)) * (2.0 if i == 4 else 1.0))
	await _shot("bed_guided")
	sb.queue_free()
	paused = false
	await process_frame
	var su := BoatPuzzleScreen.open(self, "bed_stakes", false, {"hull": hull}) as StakeBedScreen
	await process_frame
	for i in 5:
		su.puzzle.place(Vector2(0.75, -2.2 + 0.9 * float(i)))
	await _shot("bed_unguided")
	su.queue_free()
	paused = false
	await process_frame
	var la := BoatPuzzleScreen.open(self, "lashing", true) as LashingScreen
	await process_frame
	for i in 7:
		la.puzzle.pos = 0.5 + 0.2 * sin(float(i) * 2.1)
		la.puzzle.pull()
	la.puzzle.pos = 0.62
	await _shot("lashing_guided")
	la.queue_free()
	paused = false
	await process_frame
	var rb := BoatPuzzleScreen.open(self, "rib_steam", true) as RibSteamScreen
	await process_frame
	var w := rb.puzzle.window()
	for i in 4:
		rb.puzzle.heat = (w.x + w.y) * 0.5 + (0.25 if i == 2 else 0.0)
		rb.puzzle.release()
	rb.puzzle.heat = 0.5
	rb._down = true
	await _shot("ribs_guided")
	quit()
