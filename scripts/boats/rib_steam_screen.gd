class_name RibSteamScreen
extends BoatPuzzleScreen
## The rib-steaming board (RibSteam): hold the mouse (or Space) to steam the rib and let go to set it. A builder who knows the technique
## sees the window on the gauge; one who does not has the wood's colour to go by, pale to amber to dark. The ribs set show below.

var puzzle: RibSteam
var _down := false


func _ready() -> void:
	title = "Steam and set the ribs"
	puzzle = RibSteam.make(guided, randi())
	hint = ("Hold the mouse or Space to steam a rib, and let go to set it when the heat is in the green window: too soon and it cracks, too long and it goes mushy."
			if guided else "Hold the mouse or Space to steam a rib, and let go to set it. You do not know how long it wants: watch the wood, pale then amber; too soon and it cracks, too long and it goes mushy.")
	super._ready()


func _board_size() -> Vector2:
	return Vector2(720, 190)


func _input_board(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
		elif _down:
			_down = false
			puzzle.release()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.keycode == KEY_SPACE and not e.echo:
		if e.pressed:
			_down = true
		elif _down:
			_down = false
			puzzle.release()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(e)


func _tick(dt: float) -> void:
	if _down:
		puzzle.hold(dt)


func _progress() -> float:
	return float(puzzle.quality.size()) / float(RibSteam.RIBS)


func _finished() -> bool:
	return puzzle.done()


func _score() -> float:
	return puzzle.score()


func _status() -> String:
	return "%d of %d ribs set" % [puzzle.quality.size(), RibSteam.RIBS]


func _draw_board(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color(0.2, 0.17, 0.14))
	var gauge := Rect2(30, 30, w - 60, 22)
	c.draw_rect(gauge, Color(0.3, 0.25, 0.2))
	if guided:
		var win := puzzle.window()
		c.draw_rect(Rect2(gauge.position.x + gauge.size.x * win.x, gauge.position.y, gauge.size.x * (win.y - win.x), gauge.size.y), Color(0.4, 0.75, 0.3, 0.8))
	c.draw_rect(Rect2(gauge.position.x, gauge.position.y, gauge.size.x * puzzle.heat, gauge.size.y), Color(0.95, 0.6, 0.25, 0.85))
	# the rib in the steam: pale, amber, dark
	var wood := Color(0.86, 0.78, 0.62).lerp(Color(0.75, 0.5, 0.25), clampf(puzzle.heat * 1.6, 0.0, 1.0)).lerp(Color(0.32, 0.2, 0.12), clampf((puzzle.heat - 0.7) * 3.0, 0.0, 1.0))
	c.draw_rect(Rect2(60, 90, w - 120, 22), wood)
	if _down:
		for k in 5:
			c.draw_circle(Vector2(100.0 + float(k) * 130.0 + sin(Time.get_ticks_msec() / 300.0 + float(k)) * 8.0, 84.0 - fposmod(Time.get_ticks_msec() / 12.0 + float(k) * 40.0, 40.0)), 7.0, Color(1, 1, 1, 0.18))
	for i in puzzle.quality.size():
		var q: float = puzzle.quality[i]
		var col := Color(0.4, 0.75, 0.3) if q > 0.7 else Color(0.85, 0.7, 0.25) if q > 0.35 else Color(0.85, 0.3, 0.2)
		c.draw_rect(Rect2(30 + float(i) * ((w - 60) / float(RibSteam.RIBS)), h - 34, (w - 60) / float(RibSteam.RIBS) - 8, 12), col)
