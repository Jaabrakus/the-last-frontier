extends Control
## Menu style B's marks, drawn here in vectors (our own: no font icons, no third-party art):
##   earth   two peaks           water   three waves         fire   a flame with its core
##   air     three curling winds any     the four elements' diamonds
##   play    a triangle (Watch)  next    a chevron           prev   a chevron the other way
## `color` the mark, `cut` the colour its inner lines are cut in (the plate under it).

var kind := "fire"
var color := Color.WHITE
var cut := Color(0.04, 0.07, 0.12)
## The four elements' colours, for "any".
var palette := {}


static func make(k: String, c: Color, px: float, under := Color(0.04, 0.07, 0.12)) -> Control:
	var g: Control = load("res://tools/ui_audit/menu_variants/b_broadcast/glyph.gd").new()
	g.set("kind", k)
	g.set("color", c)
	g.set("cut", under)
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	return o + Vector2(x, y) * s


func _poly(pts: Array, c: Color) -> void:
	var v := PackedVector2Array()
	for p: Vector2 in pts:
		v.append(_p(p.x, p.y))
	draw_colored_polygon(v, c)


func _line(pts: Array, c: Color, w: float) -> void:
	var v := PackedVector2Array()
	for p: Vector2 in pts:
		v.append(_p(p.x, p.y))
	draw_polyline(v, c, w * minf(size.x, size.y), true)


func _arc(cx: float, cy: float, r: float, a0: float, a1: float, n := 14) -> Array:
	var out: Array = []
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return out


func _draw() -> void:
	match kind:
		"fire":
			_poly([Vector2(0.50, 1.00), Vector2(0.29, 0.95), Vector2(0.15, 0.80), Vector2(0.12, 0.62), Vector2(0.19, 0.44),
					Vector2(0.30, 0.30), Vector2(0.33, 0.47), Vector2(0.41, 0.53), Vector2(0.43, 0.36), Vector2(0.51, 0.18),
					Vector2(0.62, 0.00), Vector2(0.65, 0.19), Vector2(0.75, 0.33), Vector2(0.86, 0.51), Vector2(0.89, 0.70),
					Vector2(0.83, 0.86), Vector2(0.70, 0.96)], color)
			_poly([Vector2(0.51, 0.95), Vector2(0.39, 0.90), Vector2(0.34, 0.79), Vector2(0.38, 0.66), Vector2(0.46, 0.57),
					Vector2(0.51, 0.68), Vector2(0.57, 0.59), Vector2(0.65, 0.71), Vector2(0.67, 0.83), Vector2(0.61, 0.92)], cut)
		"water":
			for row in 3:
				var y := 0.28 + row * 0.23
				var pts: Array = []
				for i in 25:
					var x := 0.06 + 0.88 * i / 24.0
					pts.append(Vector2(x, y + sin((x - 0.06) / 0.88 * TAU * 1.5) * 0.065))
				_line(pts, color, 0.10)
		"air":
			var a: Array = [Vector2(0.06, 0.30), Vector2(0.62, 0.30)]
			a.append_array(_arc(0.62, 0.17, 0.13, PI * 0.5, -PI * 0.75))
			_line(a, color, 0.085)
			var b: Array = [Vector2(0.06, 0.52), Vector2(0.80, 0.52)]
			b.append_array(_arc(0.80, 0.65, 0.13, -PI * 0.5, PI * 0.75))
			_line(b, color, 0.085)
			var c: Array = [Vector2(0.20, 0.76), Vector2(0.52, 0.76)]
			c.append_array(_arc(0.52, 0.86, 0.10, -PI * 0.5, PI * 0.6))
			_line(c, color, 0.085)
		"earth":
			_poly([Vector2(0.04, 0.90), Vector2(0.42, 0.14), Vector2(0.80, 0.90)], color)
			_poly([Vector2(0.42, 0.14), Vector2(0.50, 0.30), Vector2(0.44, 0.40), Vector2(0.36, 0.34), Vector2(0.30, 0.38)], cut)
			_poly([Vector2(0.48, 0.90), Vector2(0.71, 0.46), Vector2(0.96, 0.90)], cut)
			_poly([Vector2(0.56, 0.90), Vector2(0.71, 0.60), Vector2(0.88, 0.90)], color)
		"any":
			var cs: Array = [palette.get("earth", color), palette.get("water", color), palette.get("fire", color),
					palette.get("air", color)]
			var at := [Vector2(0.5, 0.2), Vector2(0.8, 0.5), Vector2(0.5, 0.8), Vector2(0.2, 0.5)]
			for i in 4:
				var q: Vector2 = at[i]
				_poly([q + Vector2(0, -0.17), q + Vector2(0.17, 0), q + Vector2(0, 0.17), q + Vector2(-0.17, 0)], cs[i])
		"diamond":
			_poly([Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)], color)
		"play":
			_poly([Vector2(0.22, 0.10), Vector2(0.90, 0.50), Vector2(0.22, 0.90)], color)
		"next":
			_line([Vector2(0.32, 0.12), Vector2(0.70, 0.50), Vector2(0.32, 0.88)], color, 0.16)
		"prev":
			_line([Vector2(0.68, 0.12), Vector2(0.30, 0.50), Vector2(0.68, 0.88)], color, 0.16)
