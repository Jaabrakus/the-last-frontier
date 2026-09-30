class_name PitchScreen
extends BoatPuzzleScreen
## The seam-pitching board (PitchSpread): the seam along the canoe as a strip. Hold the mouse and draw the brush along it: slowly lays
## more, quickly less. Every part wants an even coat, not thin and not a blob; the pitch is only so much. A builder who knows the
## technique is shown the coat's target band; one who does not sees only the pitch going on.

var lumps := 3.0
var puzzle: PitchSpread
var _down := false
var _x := 0.5


func _ready() -> void:
	title = "Pitch the seam"
	hint = ("Hold the mouse and draw the brush along the seam: slowly lays more, quickly less. Aim for an even coat inside the marked band, no thin places and no blobs. The pitch is only so much."
			if guided else "Hold the mouse and draw the brush along the seam: slowly lays more, quickly less. You do not know how thick a coat should be: an even one, no thin places and no blobs. The pitch is only so much.")
	puzzle = PitchSpread.make(lumps, 35.0, guided)
	super._ready()


func _board_size() -> Vector2:
	return Vector2(720, 150)


func _input_board(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_down = e.pressed
		_x = e.position.x / board.size.x
		if not _down:
			puzzle.lift()
	elif e is InputEventMouseMotion:
		_x = e.position.x / board.size.x


func _tick(dt: float) -> void:
	if _down:
		puzzle.brush(_x, dt)
	puzzle.step(dt)


func _progress() -> float:
	return puzzle.time / puzzle.duration


func _finished() -> bool:
	return puzzle.done()


func _score() -> float:
	return puzzle.score()


func _status() -> String:
	return "Pitch left: %d%%" % roundi(100.0 * (1.0 - puzzle.used / puzzle.supply))


func _draw_board(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color(0.55, 0.39, 0.24))   # the bark of the skin, tan
	for k in 6:
		c.draw_rect(Rect2(0, h * (0.08 + 0.17 * float(k)), w, 2), Color(0.5, 0.35, 0.21))
	var cw := w / float(PitchSpread.CELLS)
	var seam_y := h * 0.5
	c.draw_rect(Rect2(0, seam_y - 3, w, 6), Color(0.36, 0.24, 0.14))   # the bare seam: the stitches
	for i in PitchSpread.CELLS:
		var t: float = puzzle.thick[i]
		if t <= 0.001:
			continue
		var bh := clampf(t, 0.0, 1.6) * h * 0.4
		var col := Color(0.05, 0.03, 0.02)
		if t < puzzle.lo:
			col = Color(0.05, 0.03, 0.02).lerp(Color(0.42, 0.28, 0.16), clampf(1.0 - t / puzzle.lo, 0.0, 1.0))   # thin: the bark shows through
		c.draw_rect(Rect2(i * cw, seam_y - bh * 0.5, cw + 0.5, bh), col)
		if t > puzzle.hi:
			c.draw_rect(Rect2(i * cw, seam_y - bh * 0.5, cw + 0.5, 3), Color(0.5, 0.36, 0.2, 0.6))   # a blob's sheen
	if guided:
		var top := seam_y - puzzle.hi * h * 0.2
		var bot := seam_y + puzzle.hi * h * 0.2
		c.draw_line(Vector2(0, top), Vector2(w, top), Color(0.3, 0.75, 0.25, 0.95), 2.0)
		c.draw_line(Vector2(0, bot), Vector2(w, bot), Color(0.3, 0.75, 0.25, 0.95), 2.0)
	if _down:
		c.draw_circle(Vector2(_x * w, seam_y), 10.0, Color(0.9, 0.85, 0.7, 0.9))
		c.draw_circle(Vector2(_x * w, seam_y), 6.0, Color(0.05, 0.03, 0.02))
