class_name BreakingHud
extends Control
## The rider's balance while a wild horse is ridden out (HorseBreaking), below the crosshair: a ring, and in it a dot
## where his weight is (x right, up forward: the move keys move it); out of the ring he is thrown. On the ring's edge a
## mark where the horse is throwing him now; round it an arc of the horse's spirit left. The grip's stamina is its own
## ring (GripRing). No text, as GripRing.

const RADIUS := 42.0
const WIDTH := 3.0
const OFFSET := Vector2(0.0, 118.0)
const SPIRIT_R := 52.0

var breaking: HorseBreaking
var _alpha := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	if breaking == null or not is_instance_valid(breaking):
		return
	var c := get_viewport_rect().size * 0.5 + OFFSET
	var b := breaking.balance
	var off := clampf(b.length(), 0.0, 1.0)
	var ring := Color(0.95, 0.93, 0.86, 0.8 * _alpha).lerp(Color(0.95, 0.35, 0.3, 0.9 * _alpha), smoothstep(0.55, 0.9, off))
	draw_circle(c, RADIUS, Color(0.0, 0.0, 0.0, 0.22 * _alpha))
	draw_arc(c, RADIUS, 0.0, TAU, 64, ring, WIDTH, true)
	draw_arc(c, RADIUS * 0.35, 0.0, TAU, 32, Color(0.95, 0.93, 0.86, 0.25 * _alpha), 1.5, true)
	# the throw now: a wedge on the edge the way it pushes
	var p := breaking.push
	if p.length() > 0.08:
		var dir := Vector2(p.x, -p.y).normalized()
		var tip := c + dir * (RADIUS + 3.0)
		var side := Vector2(-dir.y, dir.x) * 7.0
		var base := c + dir * (RADIUS - 9.0)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
				Color(0.95, 0.62, 0.25, clampf(p.length(), 0.3, 1.0) * _alpha))
	# his weight
	var dot := c + Vector2(b.x, -b.y) * RADIUS
	draw_circle(dot, 6.0, Color(0.0, 0.0, 0.0, 0.5 * _alpha))
	draw_circle(dot, 4.5, ring)
	# the horse's spirit left
	var f := clampf(breaking.spirit / maxf(breaking.spirit_max, 1.0), 0.0, 1.0)
	draw_arc(c, SPIRIT_R, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.3 * _alpha), 4.0, true)
	if f > 0.0:
		draw_arc(c, SPIRIT_R, -PI * 0.5, -PI * 0.5 + TAU * f, 64, Color(0.78, 0.55, 0.3, 0.9 * _alpha), 3.0, true)
