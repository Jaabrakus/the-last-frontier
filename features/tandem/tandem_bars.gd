extends Control
## The two stamina bars of a tandem pair, bottom centre: yours on the left (a small marker under it), your
## partner's (or the lead's) on the right. No text. They fade in while a pair is in the pose and out after it.
## The owner calls show_values() every frame.

const W := 220.0
const H := 10.0
const GAP := 28.0
const FROM_BOTTOM := 118.0
const FADE_S := 0.35
## Below this a bar pulses.
const LOW := 0.15

var mine := 1.0
var other := 1.0
var _shown := 0.0
var _pulse := 0.0

func _init() -> void:
	name = "TandemBars"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false

## `v`: x = yours, y = the other's (both 0..1); a negative x hides the bars.
func show_values(v: Vector2, delta: float) -> void:
	var want := v.x >= 0.0
	if want:
		mine = clampf(v.x, 0.0, 1.0)
		other = clampf(v.y, 0.0, 1.0)
	_shown = move_toward(_shown, 1.0 if want else 0.0, delta / FADE_S)
	modulate.a = _shown
	visible = _shown > 0.0
	_pulse += delta
	if visible: queue_redraw()

func _draw() -> void:
	var s := size.y / 900.0
	var w := W * s
	var h := H * s
	var y := size.y - FROM_BOTTOM * s
	var cx := size.x * 0.5
	_bar(Rect2(cx - GAP * s * 0.5 - w, y, w, h), mine, true, s)
	_bar(Rect2(cx + GAP * s * 0.5, y, w, h), other, false, s)

func _bar(r: Rect2, v: float, is_mine: bool, s: float) -> void:
	var frame := r.grow(2.0 * s)
	draw_rect(frame, Color(0, 0, 0, 0.55))
	var col := _color(v)
	if v < LOW:
		col.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_pulse * 8.0))
	draw_rect(Rect2(r.position, Vector2(r.size.x * v, r.size.y)), col)
	draw_rect(frame, Color(1, 1, 1, 0.8 if is_mine else 0.3), false, maxf(1.0, s))
	if is_mine:
		var mid := r.position.x + r.size.x * 0.5
		var top := r.end.y + 3.0 * s
		draw_colored_polygon(PackedVector2Array([Vector2(mid - 5.0 * s, top + 7.0 * s), Vector2(mid + 5.0 * s, top + 7.0 * s),
				Vector2(mid, top)]), Color(1, 1, 1, 0.85))

## Green when full, amber halfway, red when nearly out.
static func _color(v: float) -> Color:
	var green := Color(0.42, 0.78, 0.38)
	var amber := Color(0.95, 0.74, 0.28)
	var red := Color(0.88, 0.28, 0.26)
	return amber.lerp(green, (v - 0.5) / 0.5) if v >= 0.5 else red.lerp(amber, v / 0.5)
