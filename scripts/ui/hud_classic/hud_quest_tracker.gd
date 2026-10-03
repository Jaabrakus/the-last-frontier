class_name HudQuestTracker
extends Control
## The classic HUD's quest tracker, under the minimap (HudClassicMap; owner 2026-10-03: the classic MMO layout): the
## mission at hand as StoryHUD has it (StoryHUD.set_mission: its title, its step, the step's count) and the way to its
## place (StoryHUD.marker_at, its distance: marker_dist, else from the player), right-aligned to the minimap's edge:
##   THE MISSION'S TITLE          gold, small capitals
##   the step to do               ink, wrapping at WIDTH
##   2 / 4                        the count, when the step has one
##   ▲ 120 m                      a small gold arrow the way to the place (from the view's heading), its distance
## StoryHUD keeps its cards, the key hints and the marker in the world; its own mission lines step aside while a
## tracker is up (StoryHUD.tracker_shown). Nothing shown with no mission. A new mission title goes to the chat log too
## ("New mission: ...", `mission_begun`).

signal mission_begun(title: String)

const WIDTH := 272.0
const PAD := Vector2(12.0, 8.0)

var minimap: HudMinimap            ## for the view's heading (the arrow), the player's place
var title := ""
var text := ""
var count := ""
var dist := -1.0

var _box: VBoxContainer
var _title: Label
var _text: Label
var _count: Label
var _way: Control
var _way_text := ""
var _way_m := -2
var _t := 0.0
var _at: Variant = null                    ## the step's place (StoryHUD.marker_at), read with the rest
var _arrow := PackedVector2Array([Vector2(0, -6.5), Vector2(4.5, 4.5), Vector2(0, 2.0), Vector2(-4.5, 4.5)])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 1)
	_box.position = PAD
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_title = HudClassicMap.label(15, FrontierHUD.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_title)
	_text = HudClassicMap.label(17, FrontierHUD.INK)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_text)
	_count = HudClassicMap.label(15, FrontierHUD.TEXT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_count)
	_way = Control.new()
	_way.custom_minimum_size = Vector2(WIDTH, 20)
	_way.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_way.draw.connect(_draw_way)
	_box.add_child(_way)
	_box.minimum_size_changed.connect(_fit)
	visible = false
	self_modulate.a = 0.82                    # (the plate a little see-through; the lettering on it, its children, not)
	_fit()


func _fit() -> void:
	var s := _box.get_combined_minimum_size()
	custom_minimum_size = s + PAD * 2.0
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	HudClassicMap.draw_panel(self, Rect2(Vector2.ZERO, size), false)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		_way.queue_redraw()
		return
	_t = 0.1                                   # (the mission changes over seconds: ten reads a second is plenty)
	var d := StoryDirector.find(get_tree()) if is_inside_tree() else null
	var h: StoryHUD = d.hud if d != null else null
	var t := h.mission_title if h != null else ""
	var s := h.mission_text if h != null else ""
	var c := h.mission_count if h != null else ""
	var new_title := t != title
	if new_title:
		title = t
		if t != "":
			mission_begun.emit(t)
	if new_title or s != text or c != count:
		text = s
		count = c
		_title.text = title.to_upper()
		_title.visible = title != ""
		_text.text = text
		_text.visible = text != ""
		_count.text = count
		_count.visible = count != ""
	dist = -1.0
	var at: Variant = h.marker_at if h != null else null
	_at = at
	if at is Vector3:
		dist = h.marker_dist
		if dist < 0.0 and minimap != null:
			dist = minimap.centre.distance_to(Vector2((at as Vector3).x, (at as Vector3).z))
	_way.visible = dist >= 0.0
	var dm := roundi(dist) if dist >= 0.0 else -1
	if dm != _way_m:
		_way_m = dm
		_way_text = "%d m" % dm if dm >= 0 else ""      # (a new string only when the metres change)
	visible = title != "" or text != ""
	_way.queue_redraw()


## The way to the step's place: a gold arrow from the view's heading (turned each frame: a fixed outline moved by the
## draw's transform, no allocation), and its distance.
func _draw_way() -> void:
	if _way_text == "":
		return
	var f := FrontierHUD.serif()
	var fs := 15
	var tw := f.get_string_size(_way_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := _way.size.x - tw
	var y := _way.size.y * 0.5 + fs * 0.36
	_way.draw_string(f, Vector2(x + 1, y + 1), _way_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	_way.draw_string(f, Vector2(x, y), _way_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FrontierHUD.TEXT)
	if not (_at is Vector3) or minimap == null:
		return
	var dir := minimap.dir_on_disc(Vector2((_at as Vector3).x, (_at as Vector3).z) - minimap.centre)
	var c := Vector2(x - 12.0, _way.size.y * 0.5)
	var turn := atan2(dir.x, -dir.y)
	_way.draw_set_transform(c + Vector2(0.8, 1.0), turn)
	_way.draw_colored_polygon(_arrow, Color(0, 0, 0, 0.55))
	_way.draw_set_transform(c, turn)
	_way.draw_colored_polygon(_arrow, FrontierHUD.GOLD)
	_way.draw_set_transform(Vector2.ZERO)
