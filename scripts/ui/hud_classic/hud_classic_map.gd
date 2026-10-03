class_name HudClassicMap
extends Control
## The classic HUD's map corner and chat (owner 2026-10-03: "can the hud be similar to world of warcraft vanilla?": the
## classic MMO layout in the game's own art, no one else's: dark leather panels, brass edging, the HUD's serif):
##   top right     HudMinimap: the round map turned with the view, the compass letters on its brass ring, zoom, markers;
##                 the date and the hour under it (they leave the minimal HUD's compass, which steps aside)
##   under it      HudQuestTracker: the mission, its step and count, the way and distance to its place (StoryHUD's mission
##                 lines step aside; its cards, its key hints and its marker in the world stay StoryHUD's)
##   bottom left   HudChatLog: loot ("+2 Firewood"), skill levels, the interactor's notices, lines said nearby
##                 (StoryBark), missions begun (FrontierHUD's toasts at the right step aside)
##   var m := HudClassicMap.install(hud)     # on the player's FrontierHUD (once; again returns the one there)
##   HudClassicMap.remove(hud)               # the minimal HUD back as it was (its compass, toasts, StoryHUD's lines)
##   m.minimap / m.tracker / m.chat
## The routing: FrontierHUD.toasted (loot, skills, co-op), PlayerInteractor.noticed, the "bark_listeners" group
## (StoryBark.say calls on_bark), the survival core's skill_changed (whole levels), HudQuestTracker.mission_begun.
## The look is ClassicSkin's (the classic frames' leather, brass and lettering): draw_panel() and label() here are its
## plate and the HUD's shadowed serif for these parts.

const BRASS := ClassicSkin.BRASS
const BRASS_DARK := ClassicSkin.BRASS_LO
const BRASS_HI := ClassicSkin.BRASS_HI
const NODE_NAME := "ClassicMap"
const BARKS := &"bark_listeners"
const MARGIN := 14.0

var hud: FrontierHUD
var player: Node3D
var minimap: HudMinimap
var tracker: HudQuestTracker
var chat: HudChatLog

var _core: Object = null
var _interactor: Object = null
var _hook_t := 0.0


## Puts the map corner and the chat on `h` (the player's FrontierHUD), taking over what they replace there.
static func install(h: FrontierHUD) -> HudClassicMap:
	var have := find(h)
	if have != null:
		return have
	var m := HudClassicMap.new()
	m.name = NODE_NAME
	m.hud = h
	h._root.add_child(m)                         # (in the HUD's full-screen root, over the classic frames)
	return m


static func find(h: Node) -> HudClassicMap:
	var r: Node = h.get("_root") if h != null else null
	return r.get_node_or_null(NodePath(NODE_NAME)) as HudClassicMap if r != null else null


## The minimal HUD back: its compass, its toasts and StoryHUD's mission lines.
static func remove(h: FrontierHUD) -> void:
	var m := find(h)
	if m == null:
		return
	m._give_back()
	m.get_parent().remove_child(m)
	m.queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (in the tree already: set_anchors_preset would keep a 0 size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ClassicSkin.theme()
	add_to_group(BARKS)
	if player == null and hud != null:
		player = hud.player
	minimap = HudMinimap.new()
	minimap.name = "Minimap"
	minimap.player = player
	add_child(minimap)
	_pin(minimap, Vector2(1, 0), Vector2(-MARGIN, MARGIN - 2.0), Vector2(1, 0))
	tracker = HudQuestTracker.new()
	tracker.name = "QuestTracker"
	tracker.minimap = minimap
	add_child(tracker)
	_pin(tracker, Vector2(1, 0), Vector2(-MARGIN + 4.0, MARGIN + minimap.custom_minimum_size.y + 6.0), Vector2(1, 0))
	chat = HudChatLog.new()
	chat.name = "ChatLog"
	add_child(chat)
	_pin(chat, Vector2(0, 1), Vector2(MARGIN, -MARGIN), Vector2(0, 1))
	tracker.mission_begun.connect(func(t: String) -> void: chat.add("New mission: %s" % t, "quest"))
	chat.icon_source = func(k: String) -> Texture2D: return hud._icons.get_icon(k) if hud != null and hud._icons else null
	chat.add("F1: the controls.  = and -: zoom the map.", "system")
	_take_over()
	_hook()


## Anchors `c` at a point of the screen (`at`, 0..1), offset `off` px, its own `pivot` (0..1) there; it keeps its
## minimum size as that changes (FrontierHUD._place's way).
func _pin(c: Control, at: Vector2, off: Vector2, pivot: Vector2) -> void:
	c.anchor_left = at.x
	c.anchor_right = at.x
	c.anchor_top = at.y
	c.anchor_bottom = at.y
	var fit := func() -> void:
		var sz := c.get_combined_minimum_size()
		c.offset_left = off.x - sz.x * pivot.x
		c.offset_right = c.offset_left + sz.x
		c.offset_top = off.y - sz.y * pivot.y
		c.offset_bottom = c.offset_top + sz.y
	c.minimum_size_changed.connect(fit)
	fit.call()


## What the minimal HUD showed in these places steps aside.
func _take_over() -> void:
	if hud == null:
		return
	hud.toasts_shown = false
	for t in hud._toasts.get_children() if hud._toasts else []:
		t.queue_free()
	var compass := hud.find_child("Compass", true, false) as Control
	if compass:
		compass.visible = false
	if hud._help_hint:
		hud._help_hint.visible = false           # (the chat's first line says it)
	var d := StoryDirector.find(get_tree())
	if d != null and d.hud != null:
		d.hud.tracker_shown = true


func _give_back() -> void:
	if hud == null:
		return
	hud.toasts_shown = true
	var compass := hud.find_child("Compass", true, false) as Control
	if compass:
		compass.visible = true
	if hud._help_hint:
		hud._help_hint.visible = true
	var d := StoryDirector.find(get_tree()) if is_inside_tree() else null
	if d != null and d.hud != null:
		d.hud.tracker_shown = false


## Connects to what writes into the chat (again each second until all are there: the survival core and the story come
## after the HUD).
func _hook() -> void:
	if hud != null and not hud.toasted.is_connected(_on_toast):
		hud.toasted.connect(_on_toast)
	var it: Object = player.get("interactor") if player != null else null
	if it != null and it != _interactor and it.has_signal(&"noticed"):
		_interactor = it
		it.connect(&"noticed", _on_notice)
	var b := SurvivalBridge.find(get_tree())
	if b != null and b.core != null and b.core != _core:
		_core = b.core
		b.core.skill_changed.connect(_on_skill)
	var d := StoryDirector.find(get_tree())
	if d != null and d.hud != null and not d.hud.tracker_shown:
		d.hud.tracker_shown = true


func _process(delta: float) -> void:
	_hook_t -= delta
	if _hook_t <= 0.0:
		_hook_t = 1.0
		_hook()
		_fit_chat()


## The chat as wide as it can be and stay clear of the classic action bar (a small window narrows it).
func _fit_chat() -> void:
	var w := HudChatLog.W
	var bar: Control = hud.classic.action_bar if hud != null and hud.classic != null and is_instance_valid(hud.classic) else null
	if bar != null and bar.is_visible_in_tree():
		w = bar.get_global_rect().position.x - 12.0 - chat.get_global_rect().position.x
	chat.fit_width(w)


# --- What comes in ---------------------------------------------------------------------------------------------------

func _on_toast(text: String, icon: String, key: String) -> void:
	var tex: Texture2D = null
	var kind := "system"
	if icon.begins_with("ui:"):
		tex = hud.icon_texture(icon.substr(3))
		kind = "skill" if icon.begins_with("ui:skill_") or key.begins_with("level:") else "notice"
	elif icon != "":
		tex = hud._icons.get_icon(icon) if hud._icons else null
		kind = "loot"
	elif text.begins_with("+"):
		kind = "loot"
	chat.add(text, kind, tex, key, "", icon if kind == "loot" else "")


func _on_notice(text: String, _secs: float) -> void:
	chat.add(text, "notice")


## A survival skill's whole level ("Your skill in Hunting has risen to 12").
func _on_skill(id: String, old_level: float, new_level: float) -> void:
	if floori(new_level) <= floori(old_level) or _core == null:
		return
	var nm := id.capitalize()
	var data: Object = _core.get("data")
	if data != null and data.has_method(&"skill"):
		nm = String((data.call(&"skill", id) as Dictionary).get("name", nm))
	chat.add("Your skill in %s has risen to %d" % [nm, floori(new_level)], "skill", hud.icon_texture("skill_" + id) if hud else null,
			"sskill:" + id)


## A line said aloud (StoryBark.say): into the log when the speaker is within HEAR_M of the player.
func on_bark(speaker: Node, text: String) -> void:
	if chat == null or not (speaker is Node3D):
		return
	if player != null and is_instance_valid(player) \
			and (speaker as Node3D).global_position.distance_to(player.global_position) > HudChatLog.HEAR_M:
		return
	chat.add(text, "say", null, "", speaker_name(speaker))


## A speaker's name: a contact's `who`, a story actor's display name, a walker's label, its "display_name" meta, else "".
static func speaker_name(n: Node) -> String:
	for prop: StringName in [&"who", &"display_name"]:
		var v: Variant = n.get(prop)
		if v is String and v != "":
			return v
	if n is StoryWalker and String(n.get("label")) != "":
		return String(n.get("label"))
	if n.has_meta(&"display_name"):
		return String(n.get_meta(&"display_name"))
	var c := n.get_node_or_null(^"StoryContact")
	if c != null and String(c.get("who")) != "":
		return String(c.get("who"))
	return ""


# --- The look -------------------------------------------------------------------------------------------------------

## The classic frames' leather plate in `r` (ClassicSkin.panel). Its opacity is the CanvasItem's own: a panel that fades
## sets its self_modulate (its children, the lettering on it, keep theirs).
static func draw_panel(ci: CanvasItem, r: Rect2, rivets := true) -> void:
	if r.size.x >= 4.0 and r.size.y >= 4.0:
		ClassicSkin.panel(ci, r, rivets)


## The HUD's lettering with its soft shadow (FrontierHUD._label's look), at `px`, in `col`.
static func label(px: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FrontierHUD.serif())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
