class_name PracticePanel
extends Control
## Practice's numbers in Tidebreak's % ring (round 3, smash_r3 spec §11.1; RingPractice paints it): top centre, under the
## practice's line, on the screen only (nothing on or near the dummy):
##   the string counter   counter_px (32) bold: "3 hits · 41%", white while every hit landed inside the dummy's hitstun,
##                        grey once it was free ("free"); held while it lasts and counter_hold_s after; the best under it
##                        ("best 4 · 57%")
##   the readout          readout_px (18): "Launch 9.2 m · reeling 0.55 s · steered 12° · from here, out at 124%"
##   the notes line       notes_px (15), dim: "Hop and let go at once: a low hop."
## Sizes and the top in data/ring/practice.json panel; the words are RingPractice's (practice.json words).

const WHITE := Color(1.0, 1.0, 1.0)
const GREY := Color(0.5, 0.5, 0.5)

var counter: Label
var best: Label
var readout: Label
var notes: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pn: Dictionary = MatchSetup.practice_data().get("panel", {})
	var y := float(pn.get("top_px", 162.0))
	var csz := int(pn.get("counter_px", 32))
	counter = _line(y, csz, WHITE, true)
	counter.name = "Counter"
	y += csz + 10.0
	best = _line(y, 16, MenuUI.DIM, false)
	best.name = "Best"
	y += 22.0
	readout = _line(y, int(pn.get("readout_px", 18)), MenuUI.INK, false)
	readout.name = "Readout"
	y += float(pn.get("readout_px", 18)) + 8.0
	notes = _line(y, int(pn.get("notes_px", 15)), MenuUI.FAINT, false)
	notes.name = "Notes"


func _line(y: float, size: int, color: Color, bold: bool) -> Label:
	var l := MenuUI.label("", size, color)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = y
	l.offset_bottom = y + size + 6.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("outline_size", 6 if bold else 4)
	if bold:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = 700
		l.add_theme_font_override("font", f)
	add_child(l)
	return l


## The panel's lines now: the counter (white while true, grey once free), the best, the readout, the notes.
func paint(counter_text: String, white: bool, best_text: String, readout_text: String, notes_text: String) -> void:
	if counter == null:
		return
	counter.text = counter_text
	counter.add_theme_color_override("font_color", WHITE if white else GREY)
	best.text = best_text
	readout.text = readout_text
	notes.text = notes_text


## The counter's colour now (tests).
func counter_color() -> Color:
	return counter.get_theme_color("font_color") if counter != null else WHITE
