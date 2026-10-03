class_name HudChatLog
extends Control
## The classic HUD's chat log, bottom left (HudClassicMap; owner 2026-10-03: the classic MMO layout): everything the game
## tells the player in passing, one line each, newest at the bottom, in the HUD's serif over a leather backing:
##   loot      what gathering, skinning and foraging give ("+2 Firewood", the item's picture before it): FrontierHUD's
##             toasts (its `toasted` signal; the toasts at the right step aside while the log is up)
##   skill     a skill's level ("Woodcutting 5  ·  Apprentice": the gathering skills' toasts; the survival skills'
##             whole levels: "Your skill in Hunting has risen to 12")
##   notice    the interactor's notices (PlayerInteractor.noticed: "The torch went out", "You drink from the river")
##   say       a line said aloud near the player (StoryBark: "Leclerc says: Mind the river ice"; within HEAR_M)
##   quest     a mission begun ("New mission: The Clearing")
##   system    anything else (a co-op toast)
## Each line stays LINE_S, then fades; the backing shows while something is new, fainter while old lines still show, and
## goes when they have all faded. With the cursor free (Esc, Tab) the mouse over it shows it all again and the wheel
## scrolls back through the last MAX_LINES.
## A line the same as the last within REPEAT_S is not written twice; a keyed line (a skill's level, rising) is rewritten.
## An item's picture still being painted (ItemIcons) is put before its line when it comes (`icon_source`, twice a second).

const W := 460.0
const MIN_W := 280.0
const H := 196.0
const PAD := Vector2(10.0, 8.0)
const FONT_PX := 16
const LINE_S := 14.0
const FADE_S := 2.5
const IDLE_S := 8.0
const MAX_LINES := 120
const REPEAT_S := 4.0
const HEAR_M := 30.0
const ICON_PX := 18
const ICON_WAIT_S := 10.0
const BACKING_A := 0.55
const QUIET_A := 0.45               ## the backing (of BACKING_A) while lines show but nothing is new

const COLORS := {
	"loot": Color(0.66, 0.88, 0.52),
	"skill": Color(0.6, 0.76, 1.0),
	"notice": Color(0.96, 0.85, 0.58),
	"say": Color(0.96, 0.92, 0.82),
	"quest": Color(0.95, 0.76, 0.38),
	"system": Color(0.78, 0.74, 0.66),
}

var lines: Array = []              ## [{text, kind, key, t, node}] oldest first
var scroll := 0                    ## lines scrolled back from the newest
var panel_a := 0.0                 ## the backing's opacity now

var _clip: Control
var _list: VBoxContainer
var _more: Label
var _hover := false
var _icon_t := 0.0
## kind -> Texture2D or null (ItemIcons.get_icon): a loot line's picture asked for again until it is painted.
var icon_source: Callable
var _last_t := -1000.0
var _now := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.clip_contents = true
	_clip.position = PAD
	_clip.size = Vector2(W, H) - PAD * 2.0
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_list = VBoxContainer.new()
	_list.name = "Lines"
	_list.add_theme_constant_override("separation", 1)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.custom_minimum_size = Vector2(_clip.size.x, 0)
	_clip.add_child(_list)
	_more = HudClassicMap.label(12, FrontierHUD.DIM)
	_more.text = "newer below  (wheel)"
	_more.position = Vector2(W - 150.0, H - 18.0)
	_more.visible = false
	add_child(_more)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


## Writes a line of `kind` (COLORS' keys). `icon`: a texture before it. `key`: a line with the same key written within
## REPEAT_S is rewritten instead (a skill rising several levels at once). `who`: a speaker's name before a said line.
func add(text: String, kind := "system", icon: Texture2D = null, key := "", who := "", icon_kind := "") -> void:
	text = text.strip_edges()
	if text == "":
		return
	if not lines.is_empty():
		var last: Dictionary = lines.back()
		var fresh := _now - float(last.t) < REPEAT_S
		if fresh and key != "" and String(last.key) == key:
			last.text = text
			last.t = _now
			last.icon = icon
			last.icon_kind = icon_kind
			_fill(last.node as RichTextLabel, text, kind, icon, who)
			_last_t = _now
			return
		if fresh and String(last.text) == text and String(last.get("who", "")) == who:
			last.t = _now
			_last_t = _now
			return
	var rt := RichTextLabel.new()
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.custom_minimum_size = Vector2(_clip.size.x, 0)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_override("normal_font", FrontierHUD.serif())
	rt.add_theme_font_size_override("normal_font_size", FONT_PX)
	rt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	rt.add_theme_constant_override("shadow_offset_x", 1)
	rt.add_theme_constant_override("shadow_offset_y", 1)
	rt.add_theme_constant_override("shadow_outline_size", 2)
	_fill(rt, text, kind, icon, who)
	_list.add_child(rt)
	lines.append({"text": text, "kind": kind, "key": key, "who": who, "t": _now, "node": rt, "icon": icon,
			"icon_kind": icon_kind})
	while lines.size() > MAX_LINES:
		var old: Dictionary = lines.pop_front()
		(old.node as Node).queue_free()
	if scroll > 0 and not _hover:
		scroll = 0
	_last_t = _now


func _fill(rt: RichTextLabel, text: String, kind: String, icon: Texture2D, who: String) -> void:
	rt.clear()
	var col: Color = COLORS.get(kind, COLORS.system)
	if icon != null:
		rt.add_image(icon, ICON_PX, ICON_PX, Color.WHITE if kind != "skill" else Color(FrontierHUD.GOLD), INLINE_ALIGNMENT_CENTER)
		rt.add_text(" ")
	if who != "":
		rt.push_color(FrontierHUD.GOLD)
		rt.add_text(who + " says: ")
		rt.pop()
	rt.push_color(col)
	rt.add_text(text)
	rt.pop()


## Narrower or wider (a small window: clear of the action bar), between MIN_W and W; the lines wrap again.
func fit_width(w: float) -> void:
	w = clampf(w, MIN_W, W)
	if absf(w - size.x) < 1.0:
		return
	custom_minimum_size = Vector2(w, H)
	size = custom_minimum_size
	_clip.size = Vector2(w, H) - PAD * 2.0
	# (the lines' widths first: the list cannot be made narrower than its widest line's minimum, and it is a plain
	# Control's child, so nothing else narrows it)
	for ln: Dictionary in lines:
		(ln.node as Control).custom_minimum_size = Vector2(_clip.size.x, 0)
	_list.custom_minimum_size = Vector2(_clip.size.x, 0)
	_list.size = Vector2(_clip.size.x, 0)
	_more.position = Vector2(w - 150.0, H - 18.0)
	queue_redraw()


## The newest line's text ("" none: tests).
func last_text() -> String:
	return String((lines.back() as Dictionary).text) if not lines.is_empty() else ""


## The newest line's kind.
func last_kind() -> String:
	return String((lines.back() as Dictionary).kind) if not lines.is_empty() else ""


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = mini(scroll + 1, maxi(lines.size() - 1, 0))
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = maxi(scroll - 1, 0)
			accept_event()


func _process(delta: float) -> void:
	_now += delta
	var free := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	var looking := _hover and free
	var busy := looking or scroll > 0 or _now - _last_t < IDLE_S
	# a faint backing while a line still shows (it reads over bright grass and snow), none once they have all faded
	var showing := not lines.is_empty() and _now - float((lines.back() as Dictionary).t) < LINE_S + FADE_S
	var want := 1.0 if busy else (QUIET_A if showing else 0.0)
	panel_a = move_toward(panel_a, want, delta * (4.0 if want > panel_a else 0.8))
	# the lines: the newest at the bottom, scrolled back by `scroll`
	var below := 0.0
	var n := lines.size()
	for i in range(n - scroll, n):
		if i >= 0:
			below += (lines[i].node as Control).size.y + 1.0
	_list.position.y = _clip.size.y - _list.size.y + below
	for i in n:
		var ln: Dictionary = lines[i]
		var age := _now - float(ln.t)
		var a := 1.0 if looking or scroll > 0 else clampf(1.0 - (age - LINE_S) / FADE_S, 0.0, 1.0)
		var c := ln.node as CanvasItem
		if c.modulate.a != a:
			c.modulate.a = a
	_more.visible = scroll > 0
	_icon_t -= delta
	if _icon_t <= 0.0:
		_icon_t = 0.5
		_late_icons()
	if absf(self_modulate.a - BACKING_A * panel_a) > 0.002:
		self_modulate.a = BACKING_A * panel_a  # (the backing fades; the lines are children: their own)


## The pictures that were still being painted when their lines came (the last few lines, ICON_WAIT_S at most).
func _late_icons() -> void:
	if not icon_source.is_valid():
		return
	for i in range(maxi(lines.size() - 8, 0), lines.size()):
		var ln: Dictionary = lines[i]
		if ln.icon != null or String(ln.icon_kind) == "" or _now - float(ln.t) > ICON_WAIT_S:
			continue
		var tex: Texture2D = icon_source.call(String(ln.icon_kind))
		if tex != null:
			ln.icon = tex
			_fill(ln.node as RichTextLabel, String(ln.text), String(ln.kind), tex, String(ln.who))


func _draw() -> void:
	HudClassicMap.draw_panel(self, Rect2(Vector2.ZERO, size))
