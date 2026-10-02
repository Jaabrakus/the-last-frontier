class_name HowToKey
extends Control
## A key or a mouse button drawn as a cap, lit gold while it is pressed: the How to play panel's (HowTo in the game,
## tools/showcase/clips.gd's tutorial cut). "LMB" / "RMB" / "MMB" / "Wheel" draw a mouse; anything else a key with
## its label on it. `s`: the scale (the screen's height / 1080).

var label := ""
var shown := ""               ## what is written on it: the label, as the platform calls the key (Alt: Option on a Mac)
var lit_fn: Callable         ## func(label) -> bool: the key is lit
var s := 1.0
var font: Font
var live := true             ## only the current step's keys light


func _init(l: String, lit: Callable, sc: float, f: Font) -> void:
	label = l
	shown = key_name(l)
	lit_fn = lit
	s = sc
	font = f
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := 46.0
	if _mouse():
		w = 34.0
	elif shown.length() > 1:
		w = 26.0 + font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, int(23 * s)).x / s
	custom_minimum_size = Vector2(maxf(w, 46.0 if not _mouse() else 34.0), 46.0) * s
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## A key's name as this platform's keyboard has it ("Alt" is "Option" on a Mac).
static func key_name(l: String) -> String:
	return "Option" if l == "Alt" and OS.get_name() == "macOS" else l


func _mouse() -> bool:
	return label in ["LMB", "RMB", "MMB", "Wheel"]


func _draw() -> void:
	var lit: bool = live and bool(lit_fn.call(label))
	var gold := Color(0.95, 0.74, 0.36)
	var ink := Color(0.97, 0.94, 0.87)
	if _mouse():
		var r := Rect2(Vector2(3, 0) * s, Vector2(28, 46) * s)
		var body := StyleBoxFlat.new()
		body.bg_color = Color(0.05, 0.05, 0.06, 0.55)
		body.set_corner_radius_all(int(12 * s))
		body.border_color = ink
		body.set_border_width_all(maxi(1, int(2 * s)))
		draw_style_box(body, r)
		var mid := r.position.x + r.size.x * 0.5
		var split := r.position.y + r.size.y * 0.42
		draw_line(Vector2(r.position.x, split), Vector2(r.end.x, split), ink, maxf(1.0, 1.5 * s))
		if label != "Wheel":
			draw_line(Vector2(mid, r.position.y), Vector2(mid, split), ink, maxf(1.0, 1.5 * s))
		var inset := 2.5 * s
		if label == "LMB" or label == "RMB" or label == "MMB":
			if lit and label != "MMB":
				var left := label == "LMB"
				var x0 := r.position.x + inset if left else mid + 1.0 * s
				var x1 := mid - 1.0 * s if left else r.end.x - inset
				var btn := StyleBoxFlat.new()
				btn.bg_color = gold
				if left:
					btn.corner_radius_top_left = int(10 * s)
				else:
					btn.corner_radius_top_right = int(10 * s)
				draw_style_box(btn, Rect2(x0, r.position.y + inset, x1 - x0, split - inset * 0.6 - r.position.y - inset))
			elif label == "MMB":
				var wr := Rect2(Vector2(mid - 3 * s, r.position.y + 5 * s), Vector2(6, 12) * s)
				var wheel := StyleBoxFlat.new()
				wheel.bg_color = gold if lit else Color(ink, 0.0)
				wheel.border_color = ink
				wheel.set_border_width_all(maxi(1, int(1.5 * s)))
				wheel.set_corner_radius_all(int(3 * s))
				draw_style_box(wheel, wr)
		else:
			var wr := Rect2(Vector2(mid - 3 * s, r.position.y + 5 * s), Vector2(6, 12) * s)
			var wheel := StyleBoxFlat.new()
			wheel.bg_color = gold if lit else Color(ink, 0.0)
			wheel.border_color = ink
			wheel.set_border_width_all(maxi(1, int(1.5 * s)))
			wheel.set_corner_radius_all(int(3 * s))
			draw_style_box(wheel, wr)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = gold if lit else Color(0.05, 0.05, 0.06, 0.55)
	box.set_corner_radius_all(int(7 * s))
	box.border_color = gold if lit else ink
	box.set_border_width_all(maxi(1, int(2 * s)))
	box.border_width_bottom = maxi(2, int(4 * s))
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var fs := int(23 * s)
	var ts := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := Vector2((size.x - ts.x) * 0.5, (size.y - 2 * s + font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	draw_string(font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.06, 0.04) if lit else ink)
