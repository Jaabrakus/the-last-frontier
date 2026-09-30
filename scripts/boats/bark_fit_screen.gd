class_name BarkFitScreen
extends BoatPuzzleScreen
## The bark-fitting board (BarkFit): the skin as seven sections stern to bow, each a bar of how tight it is. Click a section (or hold
## the mouse on it, or press 1 to 7) to draw the bark tighter there; it springs back; every section wants the green band, none torn.
## A builder who knows the technique is shown the band; one who does not sees only the bark's colour go from pale to angry.

var puzzle: BarkFit
var _held := -1
var _repeat := 0.0


func _ready() -> void:
	title = "Fit the bark"
	hint = ("Draw the bark over the bed: click a section to pull it tighter, and keep every section in the green band. It springs back on its own; pull too hard and it tears."
			if guided else "Draw the bark over the bed: click a section to pull it tighter. You do not know how tight it should be: watch the bark. It springs back, and if it goes angry it will tear.")
	puzzle = BarkFit.make(0.45, 0.72, 28.0, guided, randi())
	super._ready()


func _board_size() -> Vector2:
	return Vector2(720, 240)


func _section_at(x: float) -> int:
	return clampi(int(x / (board.size.x / float(BarkFit.ZONES))), 0, BarkFit.ZONES - 1)


func _input_board(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_held = _section_at(e.position.x)
			puzzle.press(_held)
			_repeat = 0.16
		else:
			_held = -1
	elif e is InputEventMouseMotion and _held >= 0:
		_held = _section_at(e.position.x)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_7:
		puzzle.press(e.keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(e)


func _tick(dt: float) -> void:
	if _held >= 0:
		_repeat -= dt
		if _repeat <= 0.0:
			puzzle.press(_held)
			_repeat = 0.16
	puzzle.step(dt)


func _progress() -> float:
	return puzzle.time / puzzle.duration


func _finished() -> bool:
	return puzzle.done()


func _score() -> float:
	return puzzle.score()


func _status() -> String:
	var ok := 0
	for i in BarkFit.ZONES:
		if puzzle.in_band(i):
			ok += 1
	return ("%d of %d sections in the band" % [ok, BarkFit.ZONES] if guided else "You work the bark by feel") + ("   |   %d torn" % puzzle.tears if puzzle.tears > 0 else "")


func _draw_board(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color(0.16, 0.13, 0.1))
	var zw := w / float(BarkFit.ZONES)
	if guided:
		c.draw_rect(Rect2(0, h * (1.0 - puzzle.hi), w, h * (puzzle.hi - puzzle.lo)), Color(0.35, 0.6, 0.3, 0.28))
		c.draw_line(Vector2(0, h * (1.0 - puzzle.hi)), Vector2(w, h * (1.0 - puzzle.hi)), Color(0.5, 0.8, 0.4, 0.8), 1.5)
		c.draw_line(Vector2(0, h * (1.0 - puzzle.lo)), Vector2(w, h * (1.0 - puzzle.lo)), Color(0.5, 0.8, 0.4, 0.8), 1.5)
	for i in BarkFit.ZONES:
		var t: float = puzzle.tension[i]
		var col := Color(0.9, 0.85, 0.72).lerp(Color(0.78, 0.5, 0.28), clampf((t - 0.3) * 1.6, 0.0, 1.0))
		if guided and puzzle.in_band(i):
			col = Color(0.72, 0.82, 0.5)
		if t > BarkFit.TEAR_AT - 0.1:
			col = Color(0.85, 0.3, 0.2)
		var bh := h * t
		c.draw_rect(Rect2(i * zw + 6, h - bh, zw - 12, bh), col)
		c.draw_string(ThemeDB.fallback_font, Vector2(i * zw + zw * 0.5 - 4, h - 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.15, 0.1))
