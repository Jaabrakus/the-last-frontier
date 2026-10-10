extends Control
## Menu style B's broadcast hatching: thin diagonal lines across its rect (clipped to it), `color` at its own alpha,
## `gap` px apart, `width` px thick, leaning `lean` (x per y). A fade to nothing toward the bottom when `fade` > 0.

var color := Color(1, 1, 1, 0.06)
var gap := 14.0
var width := 3.0
var lean := 1.0
var fade := 0.0


static func make(c: Color, g := 14.0, w := 3.0) -> Control:
	var s: Control = load("res://tools/ui_audit/menu_variants/b_broadcast/stripes.gd").new()
	s.set("color", c)
	s.set("gap", g)
	s.set("width", w)
	s.clip_contents = true
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var h := size.y
	var x := -h * absf(lean) - gap
	while x < size.x + h * absf(lean) + gap:
		if fade <= 0.0:
			draw_line(Vector2(x + h * lean, 0), Vector2(x, h), color, width, true)
		else:
			# in steps, each fainter, so the hatching melts away down the rect
			var steps := 8
			for i in steps:
				var y0 := h * i / steps
				var y1 := h * (i + 1) / steps
				var k := clampf(1.0 - fade * float(i) / steps, 0.0, 1.0)
				draw_line(Vector2(x + (h - y0) * lean, y0), Vector2(x + (h - y1) * lean, y1), Color(color, color.a * k), width, true)
		x += gap
