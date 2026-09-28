class_name FishFightGauge
extends CanvasLayer
## A fish on the line (FishingGear; user 2026-09-28: "a stamia gauge where we catch a fish on the line the user uses
## the mouse to pull the tension to much tension the line breaks"): two slim bars at the top, under the compass and
## the date (clear of the angler, the prompts and the vitals), in the
## HUD's own hand (FrontierHUD: serif lettering, no box, the soft shade behind):
##   Line     the line's tension, 0 to where it goes at once (FishingGear.SNAP_NOW); a notch at its break (1) and the
##            stretch past it dark red; the fill from the ink to gold to red as it climbs, beating while it is over
##   <fish>   the fish's strength (FishLife stamina), its name over it; "tiring", then "spent" as it goes
## A line of the pull's keys under them for the first moments of a fight. It shows only while a fish is on, easing in
## and out.

const W := 240.0
const Y := 0.14
const HINT_S := 7.0
const FISH := Color(0.6, 0.8, 0.76)
const BREAK := Color(0.86, 0.26, 0.2)

var gear: FishingGear
var _c: Control
var _a := 0.0
var _on_t := 0.0
var _beat := 0.0


func _ready() -> void:
	layer = 3
	_c = Control.new()
	_c.name = "FishFight"
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw)
	add_child(_c)


func _process(dt: float) -> void:
	var on := gear != null and gear.rod_state == FishingGear.Rod.FIGHT and gear.bait != null and gear.bait.fish != null
	_a = move_toward(_a, 1.0 if on else 0.0, dt / 0.25)
	_on_t = _on_t + dt if on else 0.0
	_beat += dt
	visible = _a > 0.0
	if visible:
		_c.queue_redraw()


func _draw() -> void:
	if gear == null:
		return
	var vp := _c.get_viewport_rect().size
	var x0 := vp.x * 0.5 - W * 0.5
	var y0 := vp.y * Y
	var font := FrontierHUD.serif()
	_c.draw_texture_rect(FrontierHUD.shade(), Rect2(x0 - 60.0, y0 - 34.0, W + 120.0, 104.0), false, Color(1, 1, 1, _a))
	# the line
	var t := clampf(gear.tension / FishingGear.SNAP_NOW, 0.0, 1.0)
	var brk := 1.0 / FishingGear.SNAP_NOW
	var col := FrontierHUD.INK.lerp(FrontierHUD.GOLD, smoothstep(0.35, 0.65, gear.tension))
	col = col.lerp(BREAK, smoothstep(0.82, 1.0, gear.tension))
	if gear.tension >= 1.0:
		col.a = 0.55 + 0.45 * absf(sin(_beat * 14.0))
	_text(font, "Line", Vector2(x0, y0 - 8.0), 15, FrontierHUD.TEXT)
	_bar(Rect2(x0, y0, W, 4.0), t, col, brk)
	# the fish
	var fish = gear.bait.fish if gear.bait else null
	if fish != null:
		var st := clampf(float(fish.stamina), 0.0, 1.0)
		var name := String((fish.spec as Dictionary).get("name", fish.sp))
		name = name.left(1).to_upper() + name.substr(1)
		var y1 := y0 + 30.0
		_text(font, name, Vector2(x0, y1 - 8.0), 15, FrontierHUD.TEXT)
		var mood := "spent" if st < FishingGear.LAND_STAMINA else ("tiring" if st < 0.4 else "")
		if mood != "":
			var mw := font.get_string_size(mood, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_text(font, mood, Vector2(x0 + W - mw, y1 - 8.0), 14, FrontierHUD.GOLD if st < FishingGear.LAND_STAMINA else FrontierHUD.DIM)
		_bar(Rect2(x0, y1, W, 3.0), st, FISH, -1.0)
	# the keys, at first
	if _on_t < HINT_S:
		var ha := _a * clampf((HINT_S - _on_t) / 1.5, 0.0, 1.0)
		var hint := "mouse back: pull the rod in  ·  forward: give it line  ·  walk with it"
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var hc := FrontierHUD.DIM
		hc.a *= ha
		_text(font, hint, Vector2(vp.x * 0.5 - hw * 0.5, y0 + 58.0), 13, hc, ha)


func _bar(r: Rect2, k: float, fill: Color, mark: float) -> void:
	var a := _a * fill.a
	_c.draw_rect(r.grow(1.0), Color(0.02, 0.015, 0.01, 0.5 * _a))
	if mark > 0.0:
		# past the break: the stretch the line takes before it goes
		_c.draw_rect(Rect2(r.position + Vector2(r.size.x * mark, 0.0), Vector2(r.size.x * (1.0 - mark), r.size.y)),
				Color(BREAK.r, BREAK.g, BREAK.b, 0.28 * _a))
	_c.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color(fill.r, fill.g, fill.b, a))
	if mark > 0.0:
		var mx := r.position.x + r.size.x * mark
		_c.draw_line(Vector2(mx, r.position.y - 4.0), Vector2(mx, r.end.y + 4.0), Color(BREAK.r, BREAK.g, BREAK.b, 0.9 * _a), 1.5)


func _text(font: Font, s: String, at: Vector2, size: int, col: Color, a := -1.0) -> void:
	var k := _a if a < 0.0 else a
	_c.draw_string(font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.42 * k))
	_c.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.r, col.g, col.b, col.a * (k if a < 0.0 else 1.0)))
