class_name StakeBedScreen
extends BoatPuzzleScreen
## The building-bed board (StakeBed), seen from above: the hull's length along the board, the bow to the right. Click where each stake goes;
## it is driven there and shows how well it sits (green well, amber near, red wide). A builder who knows the technique sees the places
## (rings); one who does not has a metre grid, the centre line and the hull's length and beam to go by.

var hull: Dictionary = {}
var puzzle: StakeBed
const PX_PER_M := 118.0


func _ready() -> void:
	title = "Lay the building bed"
	puzzle = StakeBed.make(hull, guided)
	hint = ("Drive the stakes round the outline of the hull, a hand's breadth wide of it all the way: click each place marked. Green sits well, red is wide."
			if guided else "Drive the stakes round the outline of the hull, a hand's breadth wide of it all the way. The canoe is about %.1f m long and %.1f m across, and widest in the middle. You have only the grid to go by." % [puzzle.length, puzzle.beam])
	super._ready()


func _board_size() -> Vector2:
	return Vector2(720, 300)


func _to_screen(m: Vector2) -> Vector2:
	return Vector2(board.size.x * 0.5 + m.y * PX_PER_M, board.size.y * 0.5 + m.x * PX_PER_M)


func _to_metres(px: Vector2) -> Vector2:
	return Vector2((px.y - board.size.y * 0.5) / PX_PER_M, (px.x - board.size.x * 0.5) / PX_PER_M)


func _input_board(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		puzzle.place(_to_metres(e.position))


func _progress() -> float:
	return float(puzzle.placed.size()) / float(puzzle.wanted())


func _finished() -> bool:
	return puzzle.full()


func _score() -> float:
	return puzzle.score()


func _status() -> String:
	return "%d of %d stakes driven" % [puzzle.placed.size(), puzzle.wanted()]


func _draw_board(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color(0.42, 0.38, 0.33))   # gravel
	for k in range(-3, 4):
		var x := _to_screen(Vector2(0, float(k))).x
		c.draw_line(Vector2(x, 0), Vector2(x, h), Color(0.36, 0.32, 0.28), 1.0)
	for k in range(-1, 2):
		var y := _to_screen(Vector2(float(k), 0)).y
		c.draw_line(Vector2(0, y), Vector2(w, y), Color(0.36, 0.32, 0.28), 1.0)
	c.draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color(0.55, 0.5, 0.42), 2.0)
	if guided:
		for i in puzzle.targets.size():
			c.draw_arc(_to_screen(puzzle.targets[i]), 11.0, 0.0, TAU, 20, Color(0.9, 0.85, 0.5, 0.75), 2.0)
	for i in puzzle.placed.size():
		var q: float = puzzle.quality[i]
		var col := Color(0.4, 0.75, 0.3) if q > 0.7 else Color(0.85, 0.7, 0.25) if q > 0.35 else Color(0.85, 0.3, 0.2)
		var sp := _to_screen(puzzle.placed[i])
		c.draw_circle(sp, 6.0, Color(0.42, 0.29, 0.17))
		c.draw_arc(sp, 9.0, 0.0, TAU, 16, col, 3.0)
