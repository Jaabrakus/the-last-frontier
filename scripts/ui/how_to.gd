class_name HowTo
extends CanvasLayer
## How to play, the first time (user 2026-10-02: "in the how to i want that to be added to every thing a player does for
## the first time"): the tutorial clips' panel (tools/showcase/clips.gd) in the game, top left. The first time the
## player takes up something (the axe, the bow, build mode, a horse, a lit campfire...) its panel comes up with the
## keys for it; each step ticks off once its keys have been pressed (a key lights while it is held), and the panel goes
## once every step is done, the player has stopped doing that thing, or after MAX_S. Each topic shows once ever: the
## seen ones are kept in user://how_to.cfg (for the player, not the save).
##
## Off when a script drives the game (the tests, the films) unless howto=on; howto=off turns it off, howto=reset
## forgets the seen topics.

const CFG := "user://how_to.cfg"
const FLASH_S := 0.35          ## a tapped key stays lit at least this long
const AUTO_S := 5.0            ## a step without keys ticks off after this long
const MAX_S := 45.0            ## a panel goes after this long at the most
const GONE_S := 3.0            ## ... or this long after the player stopped doing its thing
const DONE_S := 1.4            ## ... or this long after its last step
const FADE_S := 0.35
const POLL_S := 0.25

## The keys the steps name, and the game's actions they light for.
const CAP_ACTIONS := {
	"W": [&"move_forward"], "A": [&"move_left"], "S": [&"move_back"], "D": [&"move_right"],
	"Space": [&"jump"], "Shift": [&"sprint"], "Alt": [&"walk"], "C": [&"crouch"], "R": [&"reload"],
	"T": [&"torch"], "E": [&"interact"], "Q": [&"equip_wheel"], "B": [&"build_mode"], "Tab": [&"inventory"],
	"Z": [&"sleep"], "F": [&"cook"], "G": [&"grip"], "V": [&"eat"], "X": [&"sling_all"],
	"1": [&"weapon_1"], "2": [&"weapon_2"], "3": [&"weapon_3"], "4": [&"weapon_4"], "5": [&"weapon_5"],
	"6": [&"weapon_6"], "7": [&"tool_cycle", &"tool_axe"], "8": [&"fish_gear", &"tool_mattock"], "H": [&"hands_free"],
	"LMB": [&"fire"], "RMB": [&"aim"], "MMB": [&"club_grip"], "Wheel": [&"weapon_next", &"weapon_prev"],
}

## The topics in the order they are looked for: {title, steps (text with keys in brackets), pre (the first steps
## already done by what brought the panel up)}. When each comes up: _doing(). Every key checked against the bindings
## and the code that reads it (2026-10-02).
const TOPICS := {
	"basics": {"title": "Getting around", "steps": ["[W] [A] [S] [D]  Move", "Hold [Shift]  Sprint",
			"[Space]  Jump; at a run, vault", "[C]  Crouch", "[E]  Tap: take or use what glows",
			"Hold [Q]  The wheel: weapons, tools, the torch"]},
	"hold_e": {"title": "Everything in reach", "pre": 1, "steps": ["Hold [E]  A list of everything in reach",
			"[Wheel]  Choose", "Let go of [E]  Do it", "[RMB]  While holding: put the list away"]},
	"wheel": {"title": "The equip wheel", "steps": ["Move the mouse  Choose", "Let go of [Q]  Take it in hand",
			"[Tab]  The pack: everything you carry", "[H]  Hands free"]},
	"torch": {"title": "The torch", "steps": ["[T]  Raise it, and again to lower it", "[T] [T]  Double-tap: torch mode",
			"[LMB]  In torch mode: set it in the ground or a wall", "[T]  In torch mode: switch to throwing it",
			"Hold [T]  Put it away"]},
	"axe": {"title": "Felling, limbing and bucking", "steps": ["Hold [LMB]  at a trunk: fell it",
			"[E]  in the crown: limb it, stroke by stroke", "[E]  along the log: buck off a length",
			"[7]  Next tool: the mattock, then put away"]},
	"mattock": {"title": "The mattock", "steps": ["Hold [LMB]  at a rock: break it into stone",
			"[7]  Put it away"]},
	"bow": {"title": "The hunting bow", "steps": ["Hold [LMB]  Draw: longer, harder and flatter", "Let go of [LMB]  Loose",
			"[RMB]  While drawn: let the string down", "[R]  Pull arrows into the bow hand: shoot fast"]},
	"musket": {"title": "The flintlock musket", "steps": ["Hold [LMB]  Shoulder it", "Let go of [LMB]  Fire",
			"[RMB]  Steady the aim", "[R]  Reload: powder, ball, ramrod, prime"]},
	"pistol": {"title": "The pistol", "steps": ["Hold [LMB]  Aim it", "Let go of [LMB]  Fire", "[R]  Reload"]},
	"throw": {"title": "Thrown weapons", "steps": ["Hold [LMB]  Wind up: the arc shows", "Let go of [LMB]  Throw",
			"[RMB]  While winding up: lower it", "[E]  Walk up and take it back"]},
	"build": {"title": "Building", "steps": ["[Wheel]  Choose a piece  ·  [R]  turn it", "Hold [Alt]  Snap it to the others",
			"Hold [E] , let go  Build it", "[B]  Done"]},
	"campfire": {"title": "A campfire", "steps": ["[E]  Lay firewood, light it, feed it", "[F]  Cook raw food from the pack",
			"[Z]  Rest by it: the health refills", "Hold [Z]  Sleep: the night passes, a fire makes it better"]},
	"ride": {"title": "Riding", "steps": ["[W]  Walk on  ·  [S]  slow down", "[Shift]  A tap for each gait up: trot, canter",
			"Hold [Alt]  Walk", "Hold [E]  Get off"]},
	"tree": {"title": "Climbing", "pre": 1, "steps": ["[G]  At a rock face or a trunk: take hold",
			"[W] [A] [S] [D]  Climb: the grip tires as you go", "[G]  Again: let go", "Hold [Space]  On a branch: jump down"]},
	"dress": {"title": "Field dressing", "pre": 1, "steps": ["[E]  at the carcass: skin it", "[E]  Again: butcher it for the meat",
			"[F]  at a lit fire: cook the meat"]},
	"forage": {"title": "Wild food and herbs", "pre": 1, "steps": ["[E]  Grab: berries, nuts, roots and herbs, on the move",
			"Each grab fills the bar; a full bar is a handful in the pack", "[V]  Eat the best food in the pack"]},
	"barrow": {"title": "The wheelbarrow", "pre": 1, "steps": ["[E]  At the handles: take it",
			"[W]  Push: a doe, logs, or what the pack holds", "[E]  Set it down"]},
	"hurt": {"title": "Your health", "steps": ["[Z]  Rest: sit down, the health refills",
			"Hold [Z]  Sleep: a fire makes it better"]},
}

var player: FrontierPlayer
var enabled := true
var cfg_path := CFG                 ## (tests keep their own)
var seen := {}
var current := ""
var queue: Array[String] = []

var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer
var _steps: Array = []          ## per row: {row, bar, caps: [HowToKey], actions: [[StringName]], done}
var _pressed := {}              ## action -> true: pressed since the panel came up
var _flash := {}                ## action -> seconds it stays lit
var _t := 0.0                   ## seconds the panel has been up
var _done_t := -1.0
var _gone_t := 0.0
var _close_t := -1.0            ## _t the fade out began at (-1: not closing)
var _poll := 0.0
var _age := 0.0
var _s := 1.0
var _serif: SystemFont
var _sans: SystemFont
var _sans_b: SystemFont


static func install(p: FrontierPlayer) -> HowTo:
	var h := HowTo.new()
	h.name = "HowTo"
	h.player = p
	p.add_child(h)
	return h


func _ready() -> void:
	layer = 12
	var args := OS.get_cmdline_user_args()
	# a script driving the game (the tests, the films): off unless asked for
	enabled = get_tree().get_script() == null or args.has("howto=on")
	if args.has("howto=off"):
		enabled = false
	if args.has("howto=reset"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	_load()
	_build()


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(cfg_path) == OK:
		for k in c.get_section_keys("seen") if c.has_section("seen") else PackedStringArray():
			seen[k] = true


func _save() -> void:
	var c := ConfigFile.new()
	for k: String in seen:
		c.set_value("seen", k, true)
	c.save(cfg_path)


## Forgets every topic seen (the next time each comes up again).
func reset() -> void:
	seen.clear()
	_save()


# --- What the player is doing --------------------------------------------------------------------------------

## Whether the player is doing what topic `id` is about.
func _doing(id: String) -> bool:
	var p := player
	match id:
		"basics":
			return _age > 2.0
		"hold_e":
			return p.interactor != null and not p.interactor.menu.is_empty()
		"wheel":
			return p.equip_wheel != null and p.equip_wheel.is_open
		"torch":
			return p.torch != null and p.torch.held != null
		"axe", "mattock":
			return p.gather != null and p.gather.tool == id
		"bow", "musket", "pistol":
			return p.weapon != null and p.weapon.active and not p.hands_free and p.weapon_key == id
		"throw":
			return p.weapon != null and p.weapon.active and not p.hands_free and p.weapon_key in ["spear", "tomahawk", "atlatl"]
		"build":
			return p.building != null and p.building.active
		"campfire":
			for n in get_tree().get_nodes_in_group(Campfire.GROUP):
				if n is Node3D and (n as Node3D).global_position.distance_to(p.global_position) < 3.5:
					return true
			return false
		"ride":
			return p.riding != null
		"tree":
			return p.grip != null and p.grip.state != PlayerGrip.OFF
		"dress":
			return p.kneeling is FieldDressing
		"forage":
			return ForagePick.grabbing == p
		"barrow":
			return p.pushing != null
		"hurt":
			return p.health < 70.0 and not p.is_dead
	return false


func _process(delta: float) -> void:
	if not enabled or player == null or not is_instance_valid(player):
		return
	_age += delta
	for a in _flash.keys():
		_flash[a] = float(_flash[a]) - delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_S
		for id: String in TOPICS:
			if id != "basics" and not seen.has("basics"):
				break                              # getting around first; the rest after it
			if not seen.has(id) and id != current and not queue.has(id) and _doing(id):
				queue.append(id)
	if current == "" and not queue.is_empty() and not player.is_dead:
		var next: String = queue.pop_front()
		if _doing(next) or next == "basics":
			_show(next)
	if current != "":
		_update(delta)


func _input(event: InputEvent) -> void:
	if current == "" or event.is_echo():
		return
	for label: String in CAP_ACTIONS:
		for a: StringName in CAP_ACTIONS[label]:
			if InputMap.has_action(a) and (event.is_action_pressed(a) or event.is_action_released(a)):
				_pressed[a] = true
				if event.is_action_pressed(a):
					_flash[a] = FLASH_S


# --- The panel ---------------------------------------------------------------------------------------------

func _show(id: String) -> void:
	current = id
	seen[id] = true
	_save()
	_s = maxf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7)
	_title.text = String(TOPICS[id].title)
	for r in _rows.get_children():
		_rows.remove_child(r)
		r.queue_free()
	_steps.clear()
	_pressed.clear()
	var pre := int(TOPICS[id].get("pre", 0))
	for i in (TOPICS[id].steps as Array).size():
		_add_step(String(TOPICS[id].steps[i]), i < pre)
	_t = 0.0
	_done_t = -1.0
	_gone_t = 0.0
	_close_t = -1.0
	_panel.visible = true
	_panel.modulate.a = 0.0


func _update(delta: float) -> void:
	_t += delta
	var first := true
	var all_done := true
	for st: Dictionary in _steps:
		if not st.done:
			var acts: Array = st.actions
			if acts.is_empty():
				st.done = _t >= AUTO_S
			else:
				st.done = acts.all(func(alts: Array) -> bool: return alts.any(func(a: StringName) -> bool: return _pressed.has(a)))
		var row := st.row as Control
		var bar := st.bar as ColorRect
		if st.done:
			row.modulate.a = 0.45
			bar.color = Color(0.55, 0.82, 0.45)
		elif first:
			row.modulate.a = 1.0
			bar.color = Color(0.95, 0.74, 0.36)
			first = false
		else:
			row.modulate.a = 0.8
			bar.color = Color(0.95, 0.74, 0.36, 0.0)
		for c: HowToKey in st.caps:
			c.live = not st.done
			c.queue_redraw()
		all_done = all_done and st.done
	if all_done and _done_t < 0.0:
		_done_t = _t
	if current != "basics":
		_gone_t = 0.0 if _doing(current) else _gone_t + delta
	if _close_t < 0.0 and ((_done_t >= 0.0 and _t - _done_t > DONE_S) or _gone_t > GONE_S or _t > MAX_S):
		_close_t = _t
	var a := clampf(_t / FADE_S, 0.0, 1.0)
	if _close_t >= 0.0:
		a = minf(a, 1.0 - clampf((_t - _close_t) / FADE_S, 0.0, 1.0))
		if _t - _close_t >= FADE_S:
			_panel.visible = false
			current = ""
	_panel.modulate.a = a


func is_lit(label: String) -> bool:
	for a: StringName in CAP_ACTIONS.get(label, []):
		if (InputMap.has_action(a) and Input.is_action_pressed(a)) or float(_flash.get(a, 0.0)) > 0.0:
			return true
	return false


func _add_step(spec: String, done: bool) -> void:
	var s := _s
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * s))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(3, 30) * s
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var caps: Array = []
	var actions: Array = []
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]")
	var at := 0
	for m in re.search_all(spec):
		var txt := spec.substr(at, m.get_start() - at).strip_edges()
		if txt != "":
			row.add_child(_text(txt))
		var key := m.get_string(1)
		var cap := HowToKey.new(key, is_lit, s, _sans_b)
		caps.append(cap)
		row.add_child(cap)
		var alts: Array = CAP_ACTIONS.get(key, [])
		if not alts.is_empty() and not actions.has(alts):
			actions.append(alts)
		at = m.get_end()
	var rest := spec.substr(at).strip_edges()
	if rest != "":
		row.add_child(_text(rest))
	_rows.add_child(row)
	_steps.append({"row": row, "bar": bar, "caps": caps, "actions": actions, "done": done})


func _text(t: String) -> Label:
	var l := _label(_sans, int(24 * _s), Color(0.95, 0.93, 0.88))
	l.text = t
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", maxi(1, size / 16))
	l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 16))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	_s = maxf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7)
	var s := _s
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Baskerville", "Georgia", "Times New Roman", "serif"])
	_serif.font_weight = 500
	_sans = SystemFont.new()
	_sans.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"])
	_sans.font_weight = 500
	_sans_b = SystemFont.new()
	_sans_b.font_names = _sans.font_names
	_sans_b.font_weight = 700
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.04, 0.58)
	sb.set_corner_radius_all(int(8 * s))
	sb.border_width_left = int(4 * s)
	sb.border_color = Color(0.85, 0.62, 0.3, 0.95)
	sb.content_margin_left = 22 * s
	sb.content_margin_right = 26 * s
	sb.content_margin_top = 14 * s
	sb.content_margin_bottom = 18 * s
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(36, 36) * s
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(4 * s))
	_panel.add_child(vb)
	var kicker := _label(_sans_b, int(16 * s), Color(0.9, 0.7, 0.42))
	kicker.text = "HOW TO PLAY"
	_title = _label(_serif, int(40 * s), Color(0.97, 0.94, 0.87))
	vb.add_child(kicker)
	vb.add_child(_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4 * s)
	vb.add_child(gap)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", int(8 * s))
	vb.add_child(_rows)
	_panel.visible = false
