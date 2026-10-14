class_name UiSounds
extends Node
## The menus' sounds (the sound audit, 2026-10-13: the lobby, the ring's Esc menu, settings and the round and match screens
## were all silent): every BaseButton and Slider the tree has or gains is heard, in the ring score's band (a temple block
## and a small bowl: tools/sfx/bend/ui.py, audio/sfx/bend/ui_*):
##   lit       focus (the keys, a pad, the mouse over a button that grabs it), or the mouse over one that takes no focus:
##             ui_hover, no more often than HOVER_GAP_S
##   pressed   ui_click; ui_back when its words say back, close, cancel or resume
##   a slider  moved: ui_hover, no more often than SLIDE_GAP_S
## Its own few players under the root, PROCESS_MODE_ALWAYS (the Esc menu pauses the ring; BendSounds' voices pause with it),
## on the SFX bus (the Effects slider). install(tree) once: the lobby's and the ring's ready call it.

const HOVER_GAP_S := 0.04
const SLIDE_GAP_S := 0.08
const VOICES := 3
const BACK_WORDS := ["back", "close", "cancel", "resume", "return", "leave"]
const HOOKED := &"ui_sounds"
const DB := {"ui_hover": -4.0, "ui_click": 0.0, "ui_back": 0.0}

static var _me: UiSounds

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_hover := -INF
var _last_slide := -INF
var _rng := RandomNumberGenerator.new()


## The tree's buttons and sliders heard from now on (idempotent).
static func install(tree: SceneTree) -> void:
	if tree == null or tree.root == null or (_me != null and is_instance_valid(_me)):
		return
	_me = UiSounds.new()
	_me.name = "UiSounds"
	_me.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_me)


func _ready() -> void:
	_rng.seed = 1750
	Sfx.setup_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_hook)
	for n in get_tree().root.find_children("*", "Control", true, false):
		_hook(n)


func _hook(n: Node) -> void:
	if not (n is BaseButton or n is Slider) or n.has_meta(HOOKED):
		return
	n.set_meta(HOOKED, true)
	if n is BaseButton:
		var b := n as BaseButton
		b.focus_entered.connect(_lit.bind(b))
		b.mouse_entered.connect(func() -> void:
			if b.focus_mode == Control.FOCUS_NONE:
				_lit(b))
		b.pressed.connect(_pressed.bind(b))
	else:
		(n as Slider).value_changed.connect(func(_v: float) -> void: _slid(n as Slider))


func _lit(b: BaseButton) -> void:
	if b == null or not is_instance_valid(b) or b.disabled or not b.is_visible_in_tree():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hover < HOVER_GAP_S:
		return
	_last_hover = now
	play(&"ui_hover")


func _pressed(b: BaseButton) -> void:
	if b == null or not is_instance_valid(b):
		return
	play(&"ui_back" if _is_back(b) else &"ui_click")


func _slid(s: Slider) -> void:
	if s == null or not is_instance_valid(s) or not s.is_visible_in_tree():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_slide < SLIDE_GAP_S:
		return
	_last_slide = now
	play(&"ui_hover")


## Its words (a Button's text, a MenuUI item's Text label, its name) say back, close, cancel, resume.
static func _is_back(b: BaseButton) -> bool:
	var words := String(b.name)
	if b is Button:
		words += " " + (b as Button).text
	var lab := b.find_child("Text", true, false) as Label
	if lab != null:
		words += " " + lab.text
	words = words.to_lower()
	for w: String in BACK_WORDS:
		if words.contains(w):
			return true
	return false


## `id` (ui_hover, ui_click, ui_back) now, not placed, a variant at random.
func play(id: StringName) -> void:
	var list := BendSounds.streams(id)
	if list.is_empty() or _players.is_empty():
		return
	var p := _players[_next % _players.size()]
	_next += 1
	p.stream = list[_rng.randi() % list.size()]
	p.volume_db = float(DB.get(String(id), 0.0)) + _rng.randf_range(-0.5, 0.5)
	p.pitch_scale = _rng.randf_range(0.985, 1.015)
	p.play()
