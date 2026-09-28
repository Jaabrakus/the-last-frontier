class_name GripRing
extends Control
## The grip stamina (PlayerGrip.stamina) as a ring by the crosshair: shown while climbing and while it refills, faded
## out when full; it turns red below a quarter and pulses when nearly empty. No text.

const RADIUS := 17.0
const WIDTH := 4.0
const OFFSET := Vector2(64.0, 44.0)      ## from the screen's centre (below right of the crosshair)

var grip: PlayerGrip
var _alpha := 0.0
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if grip == null:
		return
	var want := 1.0 if grip.state != PlayerGrip.OFF or grip.stamina < grip.stamina_max - 0.5 else 0.0
	_alpha = move_toward(_alpha, want, delta * (4.0 if want > _alpha else 1.5))
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if grip == null or _alpha <= 0.01:
		return
	var c := get_viewport_rect().size * 0.5 + OFFSET
	var f := clampf(grip.stamina / maxf(grip.stamina_max, 1.0), 0.0, 1.0)
	var col := Color(0.95, 0.93, 0.86)
	if f < 0.25:
		col = Color(0.95, 0.35, 0.3)
		if f < 0.12:
			col.a = 0.55 + 0.45 * absf(sin(_pulse * 9.0))
	col.a *= _alpha
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.35 * _alpha), WIDTH + 2.0, true)
	if f > 0.0:
		draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * f, 48, col, WIDTH, true)
