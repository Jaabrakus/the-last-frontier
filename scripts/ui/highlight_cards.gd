class_name HighlightCards
extends VBoxContainer
## THE HIGHLIGHT CARDS (round 4 VIRAL) on the match screen (MatchScreen adds it: make(mode) in its _ready, refresh() as it
## paints): the match's best plays (RingHighlights.cards(): the best three, one per kind), each a card with its title, one
## plain line and its number, and Watch: its 4 s played through the Splash Cam (RingReplay.play). Laid at the right of the
## screen, clear of the match screen's rows; nothing over the ring but this panel. Words in data/ring/highlights.json.
## In the broadcast look (BroadcastUI, 2026-10-10): a dark plate with a bar of the side's colour (yours in your element's, the
## other side's in theirs), the title in capitals, the line, the number big, and Watch as a teal chip with a play mark.
## Anchored to the right edge of whatever holds it (420 px wide, from y 290 down) so it stays put in the match screen's scaled
## layout and in an unscaled parent alike.

var match_mode: Node
var _head: Control
var _list: VBoxContainer
## Tests: the cards shown now (RingHighlights.cards()).
var shown: Array = []


static func make(m: Node) -> HighlightCards:
	var h := HighlightCards.new()
	h.name = "HighlightCards"
	h.match_mode = m
	return h


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -500.0
	offset_right = -80.0
	offset_top = 296.0
	offset_bottom = -170.0
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hd := Control.new()
	hd.custom_minimum_size = Vector2(420, 28)
	hd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hd)
	_head = hd
	BroadcastUI.section(hd, Vector2(0, 2), String(RingHighlights.data().get("head", "Highlights")), 420.0)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)


## The cards for the match just over (empty: the line that says so).
func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var h := RingHighlights.find(get_tree()) if is_inside_tree() else null
	shown = h.cards() if h != null else []
	visible = RingRules.stock_on() or not shown.is_empty()
	if shown.is_empty():
		_list.add_child(BroadcastUI.label(String(RingHighlights.data().get("none", "")), 18, BroadcastUI.DIM, true))
		return
	for card: Dictionary in shown:
		_list.add_child(_card(card))


func _card(card: Dictionary) -> Control:
	var mine := bool(card.get("mine", false))
	var m := match_mode
	var el := String(m.get(&"element")) if m != null and m.get(&"element") != null else MatchSetup.element
	var fe := String(m.get(&"foe_element")) if m != null and m.get(&"foe_element") != null else MatchSetup.foe()
	var side := BroadcastUI.plate_c(el if mine else fe)
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(420, 120)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", BroadcastUI.box(Color(BroadcastUI.NAVY1, 0.94), 0.0))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := ColorRect.new()
	bar.color = side
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar.offset_right = 6
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(words)
	words.add_child(BroadcastUI.caps(String(card.title), BroadcastUI.head(false, 2), 28, BroadcastUI.WHITE))
	words.add_child(BroadcastUI.label(String(card.line), 17, BroadcastUI.DIM, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(row)
	var n := BroadcastUI.caps(String(card.num), BroadcastUI.head(true, 1), 46, side)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var watch := BroadcastUI.Chip.new()
	watch.pad = Vector2(14, 5)
	watch.setup(String(RingHighlights.data().get("watch", "Watch")), 18, BroadcastUI.TEAL, "play")
	watch.chosen = true
	watch.paint()
	watch.name = "Watch"
	watch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var clip: Variant = card.get("clip")
	watch.disabled = not (clip is RingReplay.Clip)
	watch.pressed.connect(func() -> void: watch_card(card))
	row.add_child(watch)
	return panel


## A card's play through the Splash Cam (false: no clip, or a replay already playing).
func watch_card(card: Dictionary) -> bool:
	var r := RingReplay.find(get_tree())
	var clip: Variant = card.get("clip")
	if r == null or not (clip is RingReplay.Clip):
		return false
	return r.play(clip as RingReplay.Clip)
