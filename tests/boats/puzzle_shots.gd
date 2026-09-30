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
	quit()
