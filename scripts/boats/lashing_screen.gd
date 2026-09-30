class_name LashingScreen
extends BoatPuzzleScreen
## The gunwale-lashing board (Lashing): a marker sweeps across a bar; click (or Space) to pull each stitch as it crosses the middle. A
## builder who knows the technique sees the middle; one who does not has only the bar. The stitches sewn show below, green true, red wide.

var puzzle: Lashing


func _ready() -> void:
	title = "Lash the gunwales"
	puzzle = Lashing.make(guided, randf())
	hint = ("Sew the gunwales to the bark with wattap: click or press Space to pull each stitch as the marker crosses the green middle. It quickens with every stitch."
			if guided else "Sew the gunwales to the bark with wattap: click or press Space to pull each stitch. You do not know where a good stitch falls: keep a rhythm and watch. It quickens with every stitch.")
	super._ready()


func _board_size() -> Vector2:
	return Vector2(720, 150)


func _input_board(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		puzzle.pull()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE:
		puzzle.pull()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(e)


func _tick(dt: float) -> void:
	puzzle.step(dt)


func _progress() -> float:
	return float(puzzle.quality.size()) / float(Lashing.STITCHES)


func _finished() -> bool:
	return puzzle.done()


func _score() -> float:
	return puzzle.score()


func _status() -> String:
	return "%d of %d stitches sewn" % [puzzle.quality.size(), Lashing.STITCHES]


func _draw_board(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color(0.55, 0.39, 0.24))
	var bar := Rect2(30, h * 0.28, w - 60, 26)
	c.draw_rect(bar, Color(0.3, 0.2, 0.12))
	if guided:
		var zw := bar.size.x * Lashing.SWEET * 2.0
		c.draw_rect(Rect2(bar.position.x + bar.size.x * 0.5 - zw * 0.5, bar.position.y, zw, bar.size.y), Color(0.4, 0.75, 0.3, 0.8))
	var mx := bar.position.x + bar.size.x * puzzle.pos
	c.draw_rect(Rect2(mx - 4, bar.position.y - 8, 8, bar.size.y + 16), Color(0.95, 0.9, 0.75))
	for i in puzzle.quality.size():
		var q: float = puzzle.quality[i]
		var col := Color(0.4, 0.75, 0.3) if q > 0.7 else Color(0.85, 0.7, 0.25) if q > 0.35 else Color(0.85, 0.3, 0.2)
		c.draw_rect(Rect2(30 + float(i) * ((w - 60) / float(Lashing.STITCHES)), h * 0.66, (w - 60) / float(Lashing.STITCHES) - 6, 10), col)
