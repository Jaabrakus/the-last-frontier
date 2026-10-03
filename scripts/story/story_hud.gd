class_name StoryHUD
extends CanvasLayer
## The story on screen (StoryDirector), in the HUD's own manner (FrontierHUD: serif lettering with a soft shadow over
## the world, nothing boxed but the cards):
##   top left    the mission's title in gold, the step to do under it (and a count, "2 / 4"), then the mission's key
##               hints, dimmer (the first-time tutorial: the keys of what this mission asks)
##   top centre  the mission's title large for a few seconds as it starts (under the compass)
##   the world   a gold diamond on the step's place, its distance under it; held at the screen's edge when off screen
##   centre      the story cards: a title, the text, "Enter  continue". The game waits under them (paused), but not
##               in a shared world (co-op: the others play on; this player only stands while a card is up).

const INK := FrontierHUD.INK
const TEXT := FrontierHUD.TEXT
const DIM := FrontierHUD.DIM
const GOLD := FrontierHUD.GOLD
const BANNER_S := 4.0
const EDGE := 48.0

var marker_at: Variant = null       ## Vector3 or null
var marker_dist := -1.0

var _root: Control
var _panel: VBoxContainer
var _panel_shade: TextureRect
var _title: Label
var _text: Label
var _count: Label
var _hints: VBoxContainer
var _banner: Label
var _banner_t := 0.0
var _marks: Control
var _veil: ColorRect
var _card: VBoxContainer
var _card_title: Label
var _card_text: Label
var _card_more: Label
var _cards: Array = []
var _card_done: Callable
var _card_i := 0
var _card_open_t := 0.0
var _paused_by_us := false
var _waiting: Array = []           ## [cards, done] held while the character creator is open
## In a shared world the game runs on under a card: the player's controls let go of and its E interactor stopped while
## it is up (Enter, Space, E or a click on the card does nothing in the world; the move keys do not walk), as under a
## talk (StoryDialogue._hold_game); given back as the cards close.
var _held: PlayerControls = null
var _interactor: Node = null
var _interactor_mode := Node.PROCESS_MODE_INHERIT
## Seconds at the level's start the cards wait for the character creator to open (it opens a few frames in).
var _creator_grace := 0.0           ## (set by the director as a new game's storyline begins)


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = FrontierHUD.serif()
	_root.theme = th
	add_child(_root)
	_marks = Control.new()
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marker)
	_root.add_child(_marks)
	# top left: the mission and its hints (over the HUD's soft shade, so they read over a bright sky)
	_panel_shade = TextureRect.new()
	_panel_shade.texture = FrontierHUD.shade()
	_panel_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_panel_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_shade)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 2)
	_panel.position = Vector2(28, 22)
	_panel.custom_minimum_size = Vector2(380, 0)
	_root.add_child(_panel)
	_title = _label(17, GOLD)
	_panel.add_child(_title)
	_text = _label(21, INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(380, 0)
	_panel.add_child(_text)
	_count = _label(17, TEXT)
	_panel.add_child(_count)
	_hints = VBoxContainer.new()
	_hints.add_theme_constant_override("separation", 0)
	_panel.add_child(_hints)
	_panel.visible = false
	# top centre: the banner
	_banner = _label(40, INK)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 96)
	_banner.size = Vector2(800, 60)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	# centre: the cards
	_veil = ColorRect.new()
	_veil.color = Color(0.02, 0.015, 0.01, 0.72)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.visible = false
	_root.add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 18)
	_card.custom_minimum_size = Vector2(720, 0)
	center.add_child(_card)
	_card_title = _label(34, GOLD)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_title)
	_card_text = _label(22, INK)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(720, 0)
	_card.add_child(_card_text)
	_card_more = _label(16, DIM)
	_card_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_card_more)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The mission at hand (title "" hides the panel).
func set_mission(title: String, text: String, count: String, hints: Array) -> void:
	_panel.visible = title != "" or text != ""
	_title.text = title.to_upper()
	_text.text = text
	_count.text = count
	_count.visible = count != ""
	var want := "\n".join(hints)
	if String(_hints.get_meta(&"keys", "")) != want:
		_hints.set_meta(&"keys", want)
		_build_checklist(hints)


func banner(text: String) -> void:
	_banner.text = text
	_banner_t = BANNER_S


# --- Cards ---------------------------------------------------------------------------------------------------

## Show `cards` ([{title, text}]) one after another; `done` runs after the last. The game waits under them (not in a
## shared world: StoryDirector.shared_world).
func show_cards(cards: Array, done: Callable) -> void:
	if _creator_open():
		_waiting = [cards, done]                     # (a new game's character creator first: the cards after it)
		return
	_cards = cards
	_card_done = done
	_card_i = 0
	_veil.visible = true
	if StoryDirector.shared_world(get_tree()):
		_hold_player()
	elif not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_card()


func cards_open() -> bool:
	return _veil.visible or not _waiting.is_empty()


## The character creator a new game opens over the level (PlayerAppearance), still open, or about to open.
func _creator_open() -> bool:
	if _creator_grace > 0.0:
		return true
	return not get_tree().root.find_children("*", "CharacterCreator", true, false).is_empty()


func clear_cards() -> void:
	_waiting = []
	_cards = []
	_card_done = Callable()
	_close_cards()


func _show_card() -> void:
	var c: Dictionary = _cards[_card_i]
	_card_title.text = String(c.get("title", ""))
	_card_title.visible = _card_title.text != ""
	_card_text.text = String(c.get("text", ""))
	_card_more.text = "Enter  continue" if _card_i < _cards.size() - 1 else "Enter  close"
	_card_open_t = 0.35          # (a held key from before the card does not skip it)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.3)


func _next_card() -> void:
	_card_i += 1
	if _card_i < _cards.size():
		_show_card()
		return
	var done := _card_done
	_close_cards()
	if done.is_valid():
		done.call()


func _close_cards() -> void:
	_veil.visible = false
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
	_let_player_go()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The player stands under a card in a shared world (see _held).
func _hold_player() -> void:
	var p := StoryObjectives.player(get_tree())
	if p == null:
		return
	if _held == null and p.controls != null and p.controls.from_input:
		p.controls.from_input = false
		p.controls.release_all()
		_held = p.controls
	var it: Node = p.interactor
	if _interactor == null and it != null and it.process_mode != Node.PROCESS_MODE_DISABLED:
		_interactor = it
		_interactor_mode = it.process_mode
		it.process_mode = Node.PROCESS_MODE_DISABLED


func _let_player_go() -> void:
	if _held != null:
		_held.from_input = true
		_held = null
	if _interactor != null and is_instance_valid(_interactor):
		_interactor.process_mode = _interactor_mode
	_interactor = null


func _unhandled_input(event: InputEvent) -> void:
	if not _veil.visible or _card_open_t > 0.0:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		go = (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]
	elif event is InputEventMouseButton and event.pressed:
		go = (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if go:
		get_viewport().set_input_as_handled()
		_next_card()


func _process(delta: float) -> void:
	_creator_grace = maxf(0.0, _creator_grace - delta)
	_tick_checklist(delta)
	if not _waiting.is_empty() and not _creator_open():
		var w := _waiting
		_waiting = []
		show_cards(w[0], w[1])
	if _veil.visible:
		_card_open_t -= delta
		if StoryDirector.shared_world(get_tree()):
			_hold_player()                           # (a session begun under the card: the player stands from now)
		elif not get_tree().paused and _paused_by_us == false:
			get_tree().paused = true                 # (the pause menu let go over a card: the card still holds the game)
			_paused_by_us = true
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(minf(BANNER_S - _banner_t, _banner_t) / 0.6, 0.0, 1.0)
	_panel_shade.visible = _panel.visible and not _veil.visible
	if _panel_shade.visible:
		var r := Rect2(_panel.position, _panel.size).grow_individual(60, 40, 90, 50)
		_panel_shade.position = r.position
		_panel_shade.size = r.size
	_marks.queue_redraw()


# --- The marker ----------------------------------------------------------------------------------------------

func _draw_marker() -> void:
	if marker_at == null or _veil.visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p: Vector3 = (marker_at as Vector3) + Vector3(0, 2.0, 0)
	var size := _marks.size
	if size.x < EDGE * 3.0 or size.y < EDGE * 3.0:
		return
	var behind := cam.is_position_behind(p)
	var s := cam.unproject_position(p)
	if behind:
		s = size - s                                 # (behind the camera: mirrored, then held to the edge)
	var on := not behind and Rect2(Vector2.ZERO, size).grow(-EDGE).has_point(s)
	if not on:
		var c := size * 0.5
		var d := s - c
		if d.length() < 1.0:
			d = Vector2(0, 1)
		var k := minf((c.x - EDGE) / maxf(absf(d.x), 0.001), (c.y - EDGE) / maxf(absf(d.y), 0.001))
		s = c + d * k
	var r := 9.0
	var pts := PackedVector2Array([s + Vector2(0, -r), s + Vector2(r, 0), s + Vector2(0, r), s + Vector2(-r, 0), s + Vector2(0, -r)])
	_marks.draw_polyline(pts, Color(0, 0, 0, 0.6), 4.0, true)
	_marks.draw_polyline(pts, GOLD, 2.0, true)
	_marks.draw_circle(s, 2.5, GOLD)
	var dist := marker_dist
	if dist < 0.0:
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl:
			dist = Vector2(pl.global_position.x, pl.global_position.z).distance_to(Vector2(p.x, p.z))
	if dist >= 0.0:
		var f := FrontierHUD.serif()
		var t := "%d m" % roundi(dist)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_marks.draw_string(f, s + Vector2(-w * 0.5 + 1, r + 19), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.7))
		_marks.draw_string(f, s + Vector2(-w * 0.5, r + 18), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)


# --- The keys checklist ----------------------------------------------------------------------------------------
## The mission's key hints as a checklist (user 2026-10-01: "it should be a checklist, removed if it's there the first time"):
## each hint whose key is pressed is ticked, fades and goes; a hint ticked once is remembered (SEEN_PATH) and not shown again,
## in any mission or game after. A hint with no key in it ("Wall with door  your way in") stays as a plain note.
const SEEN_PATH := "user://tutorial_seen.cfg"
const DONE_FADE_S := 1.2
const CHECK_OFF := "☐  "
const CHECK_ON := "✓  "
const GREEN := Color(0.62, 0.86, 0.5)
var _rows: Array = []              ## [{label, hint, triggers, done_t}]
static var _seen := {}
static var _seen_loaded := false


static func _seen_set() -> Dictionary:
	if not _seen_loaded:
		_seen_loaded = true
		var cf := ConfigFile.new()
		if cf.load(SEEN_PATH) == OK:
			for k in cf.get_section_keys("seen") if cf.has_section("seen") else []:
				_seen[k] = true
	return _seen


static func _mark_seen(hint: String) -> void:
	_seen_set()[hint] = true
	var cf := ConfigFile.new()
	cf.load(SEEN_PATH)
	cf.set_value("seen", hint, true)
	cf.save(SEEN_PATH)


func _build_checklist(hints: Array) -> void:
	for c in _hints.get_children():
		_hints.remove_child(c)
		c.queue_free()
	_rows.clear()
	var seen := _seen_set()
	var any := false
	for h: String in hints:
		if seen.has(h):
			continue
		var tr := _triggers(h)
		var l := _label(16, TEXT)
		l.text = (CHECK_OFF if not tr.is_empty() else "") + h
		if not any:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 10)
			_hints.add_child(gap)
			any = true
		_hints.add_child(l)
		_rows.append({"label": l, "hint": h, "triggers": tr, "done_t": -1.0})


## What ticks a hint: the keys named before its first double space ("W A S D", "Shift", "LMB (hold) at a tree", "Ctrl / C",
## "hold E", "1 bow", "Mouse wheel"). [] when it names none.
static func _triggers(h: String) -> Array:
	var label := h.split("  ")[0]
	var out: Array = []
	if label.begins_with("Mouse wheel"):
		return [{"t": "wheel"}]
	for raw in label.replace("/", " ").replace("(", " ").replace(")", " ").split(" ", false):
		var w := String(raw)
		match w:
			"Mouse":
				out.append({"t": "motion"})
			"LMB":
				out.append({"t": "mouse", "b": MOUSE_BUTTON_LEFT})
			"RMB":
				out.append({"t": "mouse", "b": MOUSE_BUTTON_RIGHT})
			"Shift":
				out.append({"t": "key", "k": KEY_SHIFT})
			"Space":
				out.append({"t": "key", "k": KEY_SPACE})
			"Alt":
				out.append({"t": "key", "k": KEY_ALT})
			"Ctrl":
				out.append({"t": "key", "k": KEY_CTRL})
			"Tab":
				out.append({"t": "key", "k": KEY_TAB})
			"Enter":
				out.append({"t": "key", "k": KEY_ENTER})
			_:
				if w.length() == 1 and (w >= "A" and w <= "Z" or w >= "0" and w <= "9"):
					out.append({"t": "key", "k": OS.find_keycode_from_string(w)})
				elif w.length() >= 2 and w.length() <= 3 and w.begins_with("F") and w.substr(1).is_valid_int():
					out.append({"t": "key", "k": OS.find_keycode_from_string(w)})
	return out


func _input(event: InputEvent) -> void:
	if _rows.is_empty() or _veil.visible:
		return
	for r: Dictionary in _rows:
		if float(r.done_t) >= 0.0 or (r.triggers as Array).is_empty():
			continue
		for t: Dictionary in r.triggers:
			if _hit(t, event):
				r.done_t = DONE_FADE_S
				var l := r.label as Label
				l.text = CHECK_ON + String(r.hint)
				l.add_theme_color_override("font_color", GREEN)
				_mark_seen(String(r.hint))
				break


static func _hit(t: Dictionary, e: InputEvent) -> bool:
	match String(t.t):
		"key":
			return e is InputEventKey and e.pressed and not e.echo and ((e as InputEventKey).physical_keycode == int(t.k) or (e as InputEventKey).keycode == int(t.k))
		"mouse":
			return e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == int(t.b)
		"wheel":
			return e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		"motion":
			return e is InputEventMouseMotion and (e as InputEventMouseMotion).relative.length() > 4.0
	return false


func _tick_checklist(delta: float) -> void:
	var gone := false
	for r: Dictionary in _rows.duplicate():
		if float(r.done_t) < 0.0:
			continue
		r.done_t = float(r.done_t) - delta
		var l := r.label as Label
		l.modulate.a = clampf(float(r.done_t) / 0.5, 0.0, 1.0)
		if float(r.done_t) <= 0.0:
			l.queue_free()
			_rows.erase(r)
			gone = true
	if gone and _rows.is_empty():
		for c in _hints.get_children():
			c.queue_free()
