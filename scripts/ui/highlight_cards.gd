class_name HighlightCards
extends VBoxContainer
## THE HIGHLIGHT CARDS (round 4 VIRAL) on the match screen (MatchScreen adds it: make(mode) in its _ready, refresh() as it
## paints): the match's best plays (RingHighlights.cards(): the best three, one per kind), each a card with its title, one
## plain line and its number, and Watch: its 4 s played through the Splash Cam (RingReplay.play). Laid at the right of the
## screen, clear of the match screen's rows; nothing over the ring but this panel. Words in data/ring/highlights.json.

var match_mode: Node
var _head: Label
var _list: VBoxContainer
## Tests: the cards shown now (RingHighlights.cards()).
var shown: Array = []


static func make(m: Node) -> HighlightCards:
	var h := HighlightCards.new()
	h.name = "HighlightCards"
	h.match_mode = m
	return h


func _ready() -> void:
	anchor_left = 0.64
	anchor_right = 0.97
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_top = 80.0
	offset_bottom = -60.0
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head = MenuUI.label(String(RingHighlights.data().get("head", "Highlights")), 30, MenuUI.GOLD)
	add_child(_head)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
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
		_list.add_child(MenuUI.label(String(RingHighlights.data().get("none", "")), 18, MenuUI.DIM, true))
		return
	for card: Dictionary in shown:
		_list.add_child(_card(card))


func _card(card: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.02, 0.9)
	sb.border_color = MenuUI.GOLD if bool(card.get("mine", false)) else MenuUI.FAINT
	sb.border_width_left = 4
	sb.content_margin_left = 18
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	panel.add_child(words)
	words.add_child(MenuUI.label(String(card.title), 24, MenuUI.GOLD))
	words.add_child(MenuUI.label(String(card.line), 17, MenuUI.INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	words.add_child(row)
	var n := MenuUI.label(String(card.num), 34, Color(1, 1, 1))
	n.add_theme_font_override("font", Callouts.font())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var watch := MenuUI.item(String(RingHighlights.data().get("watch", "Watch")), 22)
	watch.name = "Watch"
	watch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	watch.custom_minimum_size.x = 120.0         # (a menu row sizes by its own box, not its words: room for "Watch")
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
