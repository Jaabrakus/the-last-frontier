class_name BodyChart
extends Control
## The Condition tab's body outline (user 2026-09-27: "a pose of the char somewhere or in the conidtions tab to should
## what is afficted we can see if someone got shot in the stomach"; picked a flat body outline): the body from the front
## and from the back in the tab's ink, each region (PlayerWounds.REGIONS) filled with the worst of what is on it
## (`marks`: LastingConditions.body_marks and chilled to the bone): an open wound red, a festering one sickly yellow-green,
## a bruise purple, a dressed wound linen, sore feet orange, chilled icy blue, the flux and wasted amber, the ague grey-blue.
## The mouse over a region tells what is on it (hovered). The front view has the body's right on the viewer's left, the
## back view its left.

signal hovered(region: String, side: String, lines: PackedStringArray)

const INK := Color(0.95, 0.88, 0.7)
const GOLD := Color(0.93, 0.74, 0.36)
const DIM := Color(0.62, 0.57, 0.48)
## A figure's box in its own units, and the gap between the two.
const FIG := Vector2(100, 224)
const GAP := 26.0
const LABEL_H := 22.0
## The marks, the worst first (the fill is the worst on the region), their colours and their words.
const ORDER := ["festering", "bleed", "bruise", "dressed", "sore", "chill", "sick", "fever"]
const COLORS := {
	"festering": Color(0.64, 0.68, 0.22, 0.9), "bleed": Color(0.86, 0.22, 0.18, 0.88),
	"bruise": Color(0.56, 0.37, 0.68, 0.82), "dressed": Color(0.88, 0.82, 0.66, 0.82),
	"sore": Color(0.94, 0.52, 0.28, 0.7), "chill": Color(0.55, 0.8, 1.0, 0.7),
	"sick": Color(0.9, 0.62, 0.28, 0.62), "fever": Color(0.62, 0.72, 0.9, 0.62),
}
const WORDS := {"festering": "festering", "bleed": "open wound", "bruise": "bruised", "dressed": "dressed",
		"sore": "sore", "chill": "chilled", "sick": "sick", "fever": "fever"}

## [{region, side ("front" / "back" / "both"), mark, text}]
var marks: Array = []
var _polys: Array = []                  ## [region, side, PackedVector2Array] as drawn
var _hover := ["", ""]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void: _set_hover("", ""))


## The regions' shapes of one figure, in its units: the viewer's left ("a"), the middle, the viewer's right ("b").
static func shapes() -> Array:
	var out: Array = []
	var head := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		head.append(Vector2(50.0 + 12.5 * cos(a), 19.0 + 14.0 * sin(a)))
	out.append(["head", head])
	out.append(["neck", PackedVector2Array([Vector2(45, 31), Vector2(55, 31), Vector2(56, 41), Vector2(44, 41)])])
	out.append(["chest", PackedVector2Array([Vector2(31, 41), Vector2(69, 41), Vector2(72, 47), Vector2(70, 82),
			Vector2(30, 82), Vector2(28, 47)])])
	out.append(["stomach", PackedVector2Array([Vector2(30, 82), Vector2(70, 82), Vector2(69, 112), Vector2(66, 120),
			Vector2(34, 120), Vector2(31, 112)])])
	var arm := PackedVector2Array([Vector2(27, 43), Vector2(21, 47), Vector2(17, 57), Vector2(14, 84), Vector2(11, 114),
			Vector2(20, 116), Vector2(22, 87), Vector2(26, 63), Vector2(28, 52)])
	var hand := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		hand.append(Vector2(15.0 + 5.5 * cos(a), 124.0 + 8.0 * sin(a)))
	var leg := PackedVector2Array([Vector2(34, 120), Vector2(49, 120), Vector2(48, 128), Vector2(46, 166),
			Vector2(45, 205), Vector2(37, 205), Vector2(35, 166), Vector2(33, 130)])
	var foot := PackedVector2Array([Vector2(37, 205), Vector2(45, 205), Vector2(47, 212), Vector2(45, 219),
			Vector2(33, 219), Vector2(33, 213)])
	for part: Array in [["arm", arm], ["hand", hand], ["leg", leg], ["foot", foot]]:
		var pts: PackedVector2Array = part[1]
		var mir := PackedVector2Array()
		for q in pts:
			mir.append(Vector2(FIG.x - q.x, q.y))
		out.append(["a_" + String(part[0]), pts])
		out.append(["b_" + String(part[0]), mir])
	return out


## A shape's region on a figure: the front view has the body's right on the viewer's left, the back view its left.
static func region_of(shape: String, side: String) -> String:
	if shape == "neck":
		return "head"
	if shape.begins_with("a_") or shape.begins_with("b_"):
		var body_left := shape.begins_with("b_") == (side == "front")
		return ("l_" if body_left else "r_") + shape.substr(2)
	return shape


## What is on `region` seen from `side`: the marks there (theirs, or on both sides).
func marks_at(region: String, side: String) -> Array:
	return marks.filter(func(m: Dictionary) -> bool:
		return String(m.region) == region and (String(m.side) == side or String(m.side) == "both"))


## The worst mark on `region` from `side` ("" none).
func worst_at(region: String, side: String) -> String:
	var best := ""
	for m: Dictionary in marks_at(region, side):
		var k := String(m.mark)
		if best == "" or ORDER.find(k) < ORDER.find(best):
			best = k
	return best


func _fit() -> Array:
	var k := minf(size.x / (FIG.x * 2.0 + GAP), (size.y - LABEL_H) / FIG.y)
	var w := (FIG.x * 2.0 + GAP) * k
	var x0 := (size.x - w) * 0.5
	return [k, x0]


func _draw() -> void:
	_polys.clear()
	var fit := _fit()
	var k: float = fit[0]
	var font := get_theme_default_font()
	for f in 2:
		var side := "front" if f == 0 else "back"
		var off := Vector2(float(fit[1]) + float(f) * (FIG.x + GAP) * k, 0.0)
		for sh: Array in shapes():
			var region := region_of(String(sh[0]), side)
			var pts := PackedVector2Array()
			for q: Vector2 in sh[1]:
				pts.append(off + q * k)
			_polys.append([region, side, pts])
			var worst := worst_at(region, side)
			var fill: Color = COLORS[worst] if worst != "" else Color(INK, 0.07)
			draw_colored_polygon(pts, fill)
			var hot: bool = _hover[0] == region and _hover[1] == side
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, GOLD if hot else Color(INK, 0.45), 2.0 if hot else 1.2, true)
		if font:
			draw_string(font, off + Vector2(0.0, FIG.y * k + LABEL_H - 5.0), "Front" if f == 0 else "Back",
					HORIZONTAL_ALIGNMENT_CENTER, FIG.x * k, 15, DIM)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var at := (ev as InputEventMouseMotion).position
		for i in range(_polys.size() - 1, -1, -1):
			var pl: Array = _polys[i]
			if Geometry2D.is_point_in_polygon(at, pl[2]):
				_set_hover(String(pl[0]), String(pl[1]))
				return
		_set_hover("", "")


func _set_hover(region: String, side: String) -> void:
	if _hover[0] == region and _hover[1] == side:
		return
	_hover = [region, side]
	queue_redraw()
	var lines := PackedStringArray()
	for m: Dictionary in marks_at(region, side):
		lines.append(String(m.text))
	hovered.emit(region, side, lines)


## The kinds of mark on the body now, the worst first (the tab's legend).
func kinds() -> Array:
	var out: Array = []
	for k: String in ORDER:
		if marks.any(func(m: Dictionary) -> bool: return String(m.mark) == k):
			out.append(k)
	return out
