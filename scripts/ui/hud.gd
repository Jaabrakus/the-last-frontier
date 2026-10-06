class_name FrontierHUD
extends CanvasLayer
## The in-game HUD (user 2026-09-26: "work on the hud elements"; 2026-09-27: "i think you can do the hud better",
## "no those big cards are terrible"): nothing boxed. Serif lettering with a soft shadow straight over the world,
## thin lines, the icons of assets/ui/icons/, and a soft edgeless shade (`shade()`) behind what needs to stay legible.
##   centre         the aim dot, the draw / reload bar under it, hit markers, the pickup prompt (ThrownPickup)
##   bottom left    health: the heart, a red bar and its number, the blood still to lose dark red behind it and what a
##                  lasting harm holds it under shaded at its end (SurvivalBridge.health_cap); well rested under it
##                  while the survival rules run (a blue bar counting the sleep's boost down, the hours left); the held
##                  torch's burn (the pack's torches). The rest of the body (food, warmth, wet, the lasting harms, drink
##                  and tobacco) is in the Tab screen's Condition tab (user 2026-09-27: "i like the right more actually
##                  and a blue bar under it for rested the other badges users can look in the tab to find")
##   bottom right   the hotbar (Hotbar; user 2026-10-02: "if nothing is equipped then nothing shows in the toolbar"):
##                  only its filled slots, each with its number: bare icons (a spell's circle drawn), the one in the
##                  hands bright with a gold rule under it, the rest dimmed; nothing at all when the bar is empty; one
##                  small line under it with the weapon's ammo and state (a readied spell: its name and the motes)
##   top centre     the compass: a thin line fading at its ends, N E S W on it, a gold notch at the heading; the date
##                  and time under it (WorldClock), the sun or the moon
##   right          toasts sliding in: what gathering gives ("+2 Firewood", the item's picture) and skill levels
##   edges          a red heartbeat at the edges of the screen when health is low; a flash when hurt
##   F1             the controls (hidden; a hint at the start), F3 the debug lines
## ARENA MODE (set_arena(true): Tidebreak's ring, FrontierPlayer.arena): the compass and the clock, the rested row, the
## torch and the needs are gone; the hotbar's strip gives way to the BendStrip (bottom centre: keys 1-5, both skills each,
## the readied one bright, its variation pips, the ready line "2 · Earth Wall · column (2/3)"), the MatchBar sits top centre
## (the round, the time, the score, your own zone and the ground each side holds: read off the match node, never a mark of
## the other side's body), a thin water bar under the health for a water fighter, the status words (rooted, slowed,
## anchored, winded) under it, and F1 shows ARENA_HELP. Nothing is ever drawn on or over the opponent (the owner: no target
## cues of any kind); the aim dot shows while a move is readied.
## Hooks kept: player, show_debug, on_projectile_hit(), on_target_killed() (group hit_listeners), toast().

@export var color := Color(0.95, 0.92, 0.8)
@export var line_length := 9.0
@export var thickness := 2.0
@export var min_gap := 3.0
@export var dot_radius := 2.2
@export var show_debug := false

const ICON_DIR := "res://assets/ui/icons/"
const INK := Color(0.96, 0.9, 0.76)
const TEXT := Color(0.9, 0.86, 0.77)
const DIM := Color(0.7, 0.65, 0.56)
const GOLD := Color(0.93, 0.74, 0.36)
const NORTH := Color(0.88, 0.38, 0.3)
const SERIF := ["Baskerville", "Hoefler Text", "Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"]
const TOAST_S := 4.0
const TOAST_IN := 0.25
const TOAST_MAX := 6
const HELP_HINT_S := 12.0
const LOW_HEALTH := 0.35
## The needs shown as badges under the health (survival rules only): [need id, icon, name].
const NEED_BADGES := [["need.food", "need_food", "Hunger"], ["need.warmth", "need_warmth", "Warmth"],
		["need.wetness", "need_wetness", "Wet"], ["need.thirst", "need_wetness", "Thirst"]]
const BADGE_OK := Color(0.9, 0.9, 0.85, 0.28)
const BADGE_WARN := Color(0.96, 0.74, 0.3)
const BADGE_BAD := Color(0.92, 0.3, 0.26)
const RESTED := Color(0.55, 0.72, 1.0)
## Game hours of the sleep's boost that fill the rested bar (eight hours slept; a better sleep keeps it full longer).
const REST_FULL_H := SurvivalBridge.REST_MAX_SLEPT_H * SurvivalBridge.REST_H_PER_H
const HELP := "WASD move · Shift sprint · Ctrl/C crouch (toggle) · Space jump / climb\n" \
		+ "1-9 or wheel: the hotbar (Tab: put things on it) · hold Q: equip wheel · E use (hold E: all there is to do) · T torch · B build\n" \
		+ "LMB hold to aim, release to fire · RMB raise / steady aim (bow: let down) · R reload\n" \
		+ "Z rest, hold Z sleep (a lean-to and a fire make it better) · V eat · F cook at a lit campfire\n" \
		+ "T: tap light / raise, hold put away, double-tap set or throw it (click)  ·  hold U drink · hold Y smoke a pipe\n" \
		+ "Tab gear · K skills · O character · F1 this help · F3 debug · Esc free mouse"
## F1 in the arena (round 2 of the skills: the same buttons for every element, KitWords; no show words:
## tests/ring/test_ring_hud.gd holds the HUD's arena lines to that): the moving keys, the buttons (ARENA_KEYS, the scheme's),
## the four rules (KitWords.rule_lines: the lock, the guard, the counters, the floor and the air), Q, the ring's rule.
const ARENA_HELP := "WASD move · Shift sprint · Space jump, even while you hold a cast · Ctrl/C crouch\n" \
		+ "%KEYS%\n%RULES%\n" \
		+ "{quick}: the readied move onto LMB · hold {quick}: your jab back · F1 this help · Esc free mouse\n" \
		+ "Knock the other side back through its three zones: into the water behind them takes the round"
## The buttons' line of F1 per control scheme (KitWords.scheme_id; {guard}, {wheel}, {aim} as bound).
const ARENA_KEYS := {
	"keys": "LMB jab · {guard} guard · 1 strike · 2 push ▲ · 3 dash · 4 wall · 5 heal · tap a key twice: its other move",
	"first_moves": "LMB jab · {guard} guard · 1 strike · 2 push ▲ · 3 dash · 4 wall · 5 heal · one move a key",
	"direction": "LMB jab · {guard} guard · hold W, S or A/D as you press {aim}: strike, wall or dash · 1-5 the keys' moves",
	"radial": "LMB jab · {guard} guard · hold {wheel}: your moves round a wheel, point and let go · 1-5 the keys' moves",
}
## HELP's lines that change outside the arena while the player has an element (the duel): Q and LMB are the quick
## spell's then (SwayCaster's; ELEMENT_LMB, ELEMENT_Q with the set key as bound).
const WORLD_LMB := "LMB hold to aim, release to fire"
const WORLD_Q := "hold Q: equip wheel"
const ELEMENT_LMB := "Hold RMB on the aim: lock the readied move, let go to cast · hold LMB: the same with the left-click move"
const ELEMENT_Q := "%s: the readied move onto LMB"


## F1's text now: ARENA_HELP in the arena (the scheme's buttons, the four rules); with an element outside it (the duel) HELP
## with its Q and LMB as the quick spell has them; else HELP. The keys as bound (KitWords.key: "(no key)" when unbound).
func help_text() -> String:
	var shown_k := KitWords.key(SwayCaster.QUICK_BIND)
	if arena:
		var keys_l := String(ARENA_KEYS.get(KitWords.scheme_id(), ARENA_KEYS.keys))
		var h := ARENA_HELP.replace("%KEYS%", keys_l).replace("%RULES%", "\n".join(PackedStringArray(KitWords.rule_lines())))
		return KitWords.keyed(h)
	# (the control scheme's own line for how moves are chosen, outside the keys scheme)
	var scheme_l := KitWords.help_line() if KitWords.scheme_id() != "keys" else ""
	var c := SwayCaster.of(player) if player != null else null
	if c == null or c.quick_element() == "":
		return HELP
	var q_line := ELEMENT_Q % shown_k
	var wheel_k := SwayCaster.key_name(EquipWheel.ACTION)
	if wheel_k != "" and wheel_k != shown_k:
		q_line = "hold %s: equip wheel · %s" % [wheel_k, q_line]     # (the wheel keeps a key of its own)
	var out := HELP.replace(WORLD_Q, q_line).replace(WORLD_LMB, ELEMENT_LMB)
	return out + "\n" + scheme_l if scheme_l != "" else out


## The water bar's colour, and how long "winded" stays among the status words (s).
const WATER := Color(0.42, 0.68, 0.95)
const WINDED_S := 2.5
const EDGE_SHADER := "shader_type canvas_item;
uniform float amount = 0.0;
uniform vec4 tint : source_color = vec4(0.4, 0.02, 0.01, 1.0);
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.3, 1.0);
	float v = smoothstep(0.3, 0.8, length(d));
	COLOR = vec4(tint.rgb, v * amount);
}"

static var _serif: SystemFont
static var _shade: GradientTexture2D

var player: FrontierPlayer
var _cross: Control
var _debug: Label
var _pickup: Label               ## "E  pick up Throwing Spear" near a thrown weapon (ThrownPickup)
var _hit_flash := 0.0
var _kill_flash := 0.0
var _hits := 0
var _shots := 0

var _root: Control
var _edge: ColorRect             ## the low-health heartbeat and the hurt flash at the screen's edges
var _hurt := 0.0
var _beat := 0.0
var _last_health := -1.0
var _health_bar: ProgressBar
var _bleed_bar: ProgressBar       ## behind the health bar: health plus the blood still to be lost (PlayerWounds)
var _health_text: Label
var _cap_bar: ProgressBar         ## at the health bar's end: what a lasting harm holds the health under (grey)
var _rest_row: HBoxContainer
var _rest_bar: ProgressBar        ## well rested: the boost left (blue), with the survival rules only
var _rest_text: Label
var _torch_row: HBoxContainer
var _torch_bar: ProgressBar
var _torch_text: Label
var _needs_row: HBoxContainer     ## food, warmth, wet and thirst as small badges: dim when well, amber then red as they worsen
var _need_icons := {}             ## need id -> TextureRect
var _needs_t := 0.0
var _ammo: Label                  ## the weapon's ammo and state under the slot strip (one small line)
var _slots_row: HBoxContainer
var _slots_box: Control           ## the strip and its line with their shade (hidden when neither shows anything)
var _slot_boxes: Array = []      ## [Control (meta active, meta spell), TextureRect (meta kind), Label]
## The quick spell under the slot strip outside the arena (a duel: the player has an element; SwayCaster's quick spell):
## the "LMB" chip and its move at its frozen variation, then the help line (BendStrip.help_text). Hidden without one.
var quick_row: HBoxContainer
var quick_name: Label
var quick_help: Label
var _compass: Control
var _clock: Label
var _clock_icon: TextureRect
var _toasts: VBoxContainer
var _help_box: Control
var _help_hint: Label
var _help_t := 0.0
var _icons: ItemIcons
var _tex := {}
var _heading := 0.0
## Arena mode (set_arena) and its pieces (null until it is first on).
var arena := false
var bend_strip: BendStrip
var match_bar: MatchBar
var _help_label: Label
var _water_row: HBoxContainer
var _water_bar: ProgressBar
var _water_text: Label
var _status: Label
var _winded_t := 0.0


## The HUD's lettering: a serif of the machine's (Baskerville on a Mac), the engine's own font where there is none.
static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(SERIF)
		_serif.fallbacks = [ThemeDB.fallback_font]
	return _serif


## A soft dark smear with no edges (an ellipse fading out from its middle), drawn stretched behind lettering and
## icons so they read over a bright sky or snow.
static func shade() -> Texture2D:
	if _shade == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.015, 0.01, 0.5))
		g.set_color(1, Color(0.02, 0.015, 0.01, 0.0))
		g.add_point(0.55, Color(0.02, 0.015, 0.01, 0.3))
		_shade = GradientTexture2D.new()
		_shade.gradient = g
		_shade.fill = GradientTexture2D.FILL_RADIAL
		_shade.fill_from = Vector2(0.5, 0.5)
		_shade.fill_to = Vector2(1.0, 0.5)
		_shade.width = 128
		_shade.height = 64
	return _shade


func _ready() -> void:
	add_to_group("hit_listeners")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = serif()
	_root.theme = th
	add_child(_root)
	_edge = ColorRect.new()
	_edge.name = "Edges"
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = EDGE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_edge.material = mat
	_edge.visible = false
	_root.add_child(_edge)
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_overlay)
	_root.add_child(_cross)
	_icons = ItemIcons.shared(get_tree())
	_icons.prewarm.call_deferred()
	_build_vitals()
	_build_slots()
	_build_compass()
	_toasts = VBoxContainer.new()
	_toasts.name = "Toasts"
	_toasts.add_theme_constant_override("separation", 2)
	_toasts.custom_minimum_size = Vector2(10, 10)
	_root.add_child(_toasts)
	_place(_toasts, Vector2(1, 0.62), Vector2(-18, 0), Vector2(1, 1))
	_debug = _label(14, TEXT)
	_root.add_child(_debug)
	_place(_debug, Vector2(0, 0), Vector2(16, 70), Vector2(0, 0))
	_pickup = _label(19, INK)
	_pickup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_pickup)
	_place(_pickup, Vector2(0.5, 0.5), Vector2(0, 58), Vector2(0.5, 0))
	var help := _label(17, TEXT)
	help.text = HELP
	_help_label = help
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_box = _shaded(help, Vector2(60, 26))
	_help_box.name = "Help"
	_root.add_child(_help_box)
	_place(_help_box, Vector2(0.5, 1), Vector2(0, -20), Vector2(0.5, 1))
	_help_box.visible = false
	_help_hint = _label(15, DIM)
	_help_hint.text = "F1  controls"
	_root.add_child(_help_hint)
	_place(_help_hint, Vector2(0, 1), Vector2(24, -112), Vector2(0, 1))
	_help_t = HELP_HINT_S
	if player:
		for w: Weapon in player.weapons.values():
			w.fired.connect(func() -> void: _shots += 1)
		_hook_gathering.call_deferred()


## Puts a control at an anchor point of the screen (`at`, 0..1 each), offset by `off` px, its own `pivot` (0..1) on
## that point; it keeps its minimum size as it changes.
func _place(c: Control, at: Vector2, off: Vector2, pivot: Vector2) -> void:
	c.set_meta(&"hud_place", [at, off, pivot])
	c.anchor_left = at.x
	c.anchor_right = at.x
	c.anchor_top = at.y
	c.anchor_bottom = at.y
	c.minimum_size_changed.connect(_reflow.bind(c))
	_reflow(c)


func _reflow(c: Control) -> void:
	var pl: Array = c.get_meta(&"hud_place")
	var sz := c.get_combined_minimum_size()
	var off: Vector2 = pl[1]
	var pv: Vector2 = pl[2]
	c.offset_left = off.x - sz.x * pv.x
	c.offset_right = c.offset_left + sz.x
	c.offset_top = off.y - sz.y * pv.y
	c.offset_bottom = c.offset_top + sz.y


# --- building ------------------------------------------------------------------------------------------

func _build_vitals() -> void:
	var v := VBoxContainer.new()
	v.name = "Vitals"
	v.add_theme_constant_override("separation", 4)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	v.add_child(hr)
	hr.add_child(_icon_rect("hud_health", 22, Color(0.9, 0.34, 0.3)))
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(190, 5)
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hr.add_child(stack)
	_bleed_bar = _bar(190, 5, Color(0.42, 0.05, 0.04))
	_bleed_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_bleed_bar)
	_cap_bar = _bar(190, 5, Color(0.6, 0.58, 0.54, 0.55))
	_cap_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_cap_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_cap_bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0)
	stack.add_child(_cap_bar)
	_health_bar = _bar(190, 5, Color(0.78, 0.22, 0.18))
	_health_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_health_bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0)
	stack.add_child(_health_bar)
	_health_text = _label(16, TEXT)
	_health_text.custom_minimum_size = Vector2(34, 0)
	hr.add_child(_health_text)
	_rest_row = HBoxContainer.new()
	_rest_row.name = "Rested"
	_rest_row.add_theme_constant_override("separation", 8)
	_rest_row.visible = false
	v.add_child(_rest_row)
	_rest_row.add_child(_icon_rect("need_rest", 22, RESTED))
	_rest_bar = _bar(190, 4, RESTED)
	_rest_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rest_row.add_child(_rest_bar)
	_rest_text = _label(15, TEXT)
	_rest_row.add_child(_rest_text)
	_torch_row = HBoxContainer.new()
	_torch_row.add_theme_constant_override("separation", 8)
	v.add_child(_torch_row)
	_torch_row.add_child(_icon_rect("hud_torch", 22, Color(1.0, 0.64, 0.28)))
	_torch_bar = _bar(130, 4, Color(0.98, 0.62, 0.24))
	_torch_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_torch_row.add_child(_torch_bar)
	_torch_text = _label(15, TEXT)
	_torch_row.add_child(_torch_text)
	_needs_row = HBoxContainer.new()
	_needs_row.name = "Needs"
	_needs_row.add_theme_constant_override("separation", 10)
	_needs_row.visible = false
	v.add_child(_needs_row)
	for nd: Array in NEED_BADGES:
		var ic := _icon_rect(String(nd[1]), 20, Color.WHITE)
		ic.tooltip_text = String(nd[2])
		_needs_row.add_child(ic)
		_need_icons[String(nd[0])] = ic
	_root.add_child(v)
	_place(v, Vector2(0, 1), Vector2(24, -22), Vector2(0, 1))


func _build_slots() -> void:
	var col := VBoxContainer.new()
	col.name = "Slots"
	col.add_theme_constant_override("separation", 0)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 2)
	_slots_row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(_slots_row)
	_ammo = _label(16, TEXT)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(_ammo)
	quick_row = HBoxContainer.new()
	quick_row.name = "Quick"
	quick_row.alignment = BoxContainer.ALIGNMENT_END
	quick_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	quick_row.add_theme_constant_override("separation", 6)
	quick_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick_row.add_child(BendStrip.make_chip())
	quick_name = hud_label(16, INK)
	quick_name.name = "QuickName"
	quick_row.add_child(quick_name)
	quick_row.visible = false
	col.add_child(quick_row)
	quick_help = hud_label(13, DIM)
	quick_help.name = "QuickHelp"
	quick_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quick_help.size_flags_horizontal = Control.SIZE_SHRINK_END
	quick_help.visible = false
	col.add_child(quick_help)
	var sh := _shaded(col, Vector2(34, 10))
	_root.add_child(sh)
	_place(sh, Vector2(1, 1), Vector2(-6, -8), Vector2(1, 1))
	_slots_box = sh


func _build_compass() -> void:
	var v := VBoxContainer.new()
	v.name = "Compass"
	v.add_theme_constant_override("separation", 0)
	_compass = Control.new()
	_compass.custom_minimum_size = Vector2(480, 36)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	v.add_child(_compass)
	var cr := HBoxContainer.new()
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.add_theme_constant_override("separation", 6)
	v.add_child(cr)
	_clock_icon = _icon_rect("hud_sun", 16, GOLD)
	cr.add_child(_clock_icon)
	_clock = _label(16, TEXT)
	cr.add_child(_clock)
	_root.add_child(v)
	_place(v, Vector2(0.5, 0), Vector2(0, 8), Vector2(0.5, 0))


## Arena mode on or off (see the header): the world's readouts hidden, the BendStrip, the MatchBar, the water bar and the
## status words shown (built the first time).
func set_arena(on: bool) -> void:
	arena = on
	if on and bend_strip == null:
		_build_arena()
	var compass := _root.get_node_or_null(^"Compass") as Control
	if compass != null:
		compass.visible = not on
	if bend_strip != null:
		(bend_strip.get_parent() as Control).visible = on
		match_bar.visible = on
		(_status.get_parent() as Control).visible = on
	if _help_label != null:
		_help_label.text = help_text()
	if on:
		_rest_row.visible = false
		_torch_row.visible = false
		_needs_row.visible = false
		_slots_box.visible = false


func _build_arena() -> void:
	bend_strip = BendStrip.new()
	bend_strip.name = "BendStrip"
	bend_strip.player = player
	var sh := _shaded(bend_strip, Vector2(40, 10))
	sh.name = "BendStripShade"
	_root.add_child(sh)
	_place(sh, Vector2(0.5, 1), Vector2(0, -6), Vector2(0.5, 1))
	match_bar = MatchBar.new()
	match_bar.name = "MatchBar"
	match_bar.player = player
	_root.add_child(match_bar)
	_place(match_bar, Vector2(0.5, 0), Vector2(0, 10), Vector2(0.5, 0))
	# a water fighter's water and the status words: over the health (the vitals' own rows are the world's)
	var box := VBoxContainer.new()
	box.name = "ArenaVitals"
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = _label(16, GOLD)
	_status.name = "Status"
	_status.visible = false
	box.add_child(_status)
	_water_row = HBoxContainer.new()
	_water_row.name = "Water"
	_water_row.add_theme_constant_override("separation", 8)
	_water_row.visible = false
	box.add_child(_water_row)
	var wspace := Control.new()
	wspace.custom_minimum_size = Vector2(22, 4)
	wspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_row.add_child(wspace)
	_water_bar = _bar(190, 4, WATER)
	_water_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_water_row.add_child(_water_bar)
	_water_text = _label(15, TEXT)
	_water_row.add_child(_water_text)
	_root.add_child(box)
	_place(box, Vector2(0, 1), Vector2(24, -50), Vector2(0, 1))
	if player != null and player.has_signal(&"winded"):
		player.winded.connect(func(_by: Node) -> void: _winded_t = WINDED_S)
	# (a knock the player dealt: the hit mark at the centre, the bending's hit confirmation; BendKnock tells its listeners)
	add_to_group(BendKnock.LISTENERS)


## BendKnock's listeners: a body knocked by the player (not himself) flashes the hit mark at the centre (never at the body).
func on_knocked(n: Node, _v: Vector3, by: Node) -> void:
	if arena and player != null and by == player and n != player:
		_hit_flash = 1.0
		_hits += 1


## The arena's readouts each frame: the water (a water fighter's), the status words.
func _update_arena(delta: float) -> void:
	_rest_row.visible = false
	_torch_row.visible = false
	_needs_row.visible = false
	var b := player.get_node_or_null(NodePath(String(Bending.NODE_NAME))) as Bending
	# (round 2: with the water's spending off, moves.json water_meter.spend false, the meter is dormant and not shown)
	var spends := bool((SwayMoves.data().get("water_meter", {}) as Dictionary).get("spend", true))
	var wet := b != null and b.element == "water" and spends
	_water_row.visible = wet
	if wet:
		_water_bar.value = clampf(b.water / maxf(b.water_max, 1.0), 0.0, 1.0)
		_water_text.text = "water %d" % roundi(b.water)
	_winded_t = maxf(_winded_t - delta, 0.0)
	_status.text = "  ·  ".join(status_words())
	_status.visible = _status.text != ""


## The words for what holds the player now: "rooted", "slowed", "anchored", "winded" (a few seconds after it).
func status_words() -> PackedStringArray:
	var out := PackedStringArray()
	if player == null:
		return out
	if BendStatus.until(player, &"bend_root") > 0.0:
		out.append("rooted")
	if BendStatus.until(player, &"bend_slow") > 0.0:
		out.append("slowed")
	if player.has_meta(&"bend_anchor") and float(player.get_meta(&"bend_anchor")) > BendStatus.now():
		out.append("anchored")
	if _winded_t > 0.0:
		out.append("winded")
	return out


## A label in the HUD's lettering (its serif from the theme it is under, the soft shadow): for the HUD's own pieces
## (BendStrip, MatchBar).
static func hud_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.42))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## `content` with the soft shade drawn behind it, `pad` px round it (the shade reaches past the content's edges
## and fades out there, so it never shows an edge).
func _shaded(content: Control, pad: Vector2) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(pad.x))
	m.add_theme_constant_override("margin_right", int(pad.x))
	m.add_theme_constant_override("margin_top", int(pad.y))
	m.add_theme_constant_override("margin_bottom", int(pad.y))
	m.draw.connect(func() -> void: m.draw_texture_rect(shade(), Rect2(Vector2.ZERO, m.size), false))
	m.add_child(content)
	return m


func _label(size: int, col := color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.42))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A slim bar: a faint track, the fill, no frame.
func _bar(w: float, h: float, fill: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.015, 0.01, 0.5)
	bg.set_corner_radius_all(int(h * 0.5))
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(int(h * 0.5))
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


func icon_texture(id: String) -> Texture2D:
	if not _tex.has(id):
		var path := ICON_DIR + id + ".svg"
		_tex[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex[id]


func _icon_rect(id: String, px: int, tint: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon_texture(id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# --- toasts -------------------------------------------------------------------------------------------

## A line at the right that slides in and fades after TOAST_S: `icon` is an ItemIcons kind ("log") or a HUD icon id
## prefixed "ui:" ("ui:skill_woodcutting"). A toast with a `key` that is still showing is updated instead (several
## levels of one skill at once show the last).
func toast(text: String, icon := "", key := "") -> void:
	if _toasts == null:
		return
	if key != "":
		for c in _toasts.get_children():
			if c.get_meta(&"key", "") == key and not c.is_queued_for_deletion():
				(c.find_children("*", "Label", true, false)[0] as Label).text = text
				c.set_meta(&"t", TOAST_S)
				return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var l := _label(18, INK)
	l.text = text
	row.add_child(l)
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(32, 32)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon.begins_with("ui:"):
		tr.texture = icon_texture(icon.substr(3))
		tr.modulate = GOLD
		l.add_theme_color_override("font_color", GOLD.lerp(INK, 0.35))
	elif icon != "" and _icons:
		tr.texture = _icons.get_icon(icon)
		if tr.texture == null:
			tr.set_meta(&"kind", icon)       # the picture is still rendering: _process looks again
	row.add_child(tr)
	var sh := _shaded(row, Vector2(30, 6))
	sh.set_meta(&"t", TOAST_S)
	sh.set_meta(&"key", key)
	sh.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toasts.add_child(sh)
	while _toasts.get_child_count() > TOAST_MAX:
		_toasts.get_child(0).free()


func _hook_gathering() -> void:
	var g: GatherTools = player.gather if player else null
	if g == null:
		return
	g.gathered.connect(func(item: String, n: int) -> void: toast(gain_line(g, item, n), item))
	if g.skills:
		g.skills.leveled.connect(func(id: String, lvl: int, tier: Dictionary) -> void:
			var nm := String(g.data.skill(id).get("name", id.capitalize()))
			toast("%s %d%s" % [nm, lvl, "" if tier.is_empty() else "  ·  " + String(tier.name)], "ui:skill_" + id, "level:" + id))


## Names that take no plural ("+3 Venison", "+2 Jerky").
const MASS := ["Firewood", "Flint", "Stone", "Venison", "Wintergreen", "Jerky", "Cornmeal"]


## "+2 Firewood", "+1 Deer Hide", "+3 Fox Pelts": the gathering data's name, or the pack's (what skinning and
## foraging give).
static func gain_line(g: GatherTools, item: String, n: int) -> String:
	var nm := g.data.name_of(item) if g else ""
	if nm == "":
		nm = InventoryState.name_of(item)
	if n != 1 and not nm in MASS:
		nm = GatherTools._plural(nm)
	return "+%d %s" % [n, nm]


func _tick_toasts(delta: float) -> void:
	for t in _toasts.get_children():
		var left := float(t.get_meta(&"t", 0.0)) - delta
		t.set_meta(&"t", left)
		var age := TOAST_S - left
		var c := t as Control
		c.modulate.a = clampf(left / 0.6, 0.0, 1.0) * clampf(age / TOAST_IN, 0.0, 1.0)
		# slides in from the right, easing out
		var k := clampf(age / TOAST_IN, 0.0, 1.0)
		var row := c.get_child(0) as Control
		row.position.x = c.get_theme_constant("margin_left") + 36.0 * (1.0 - k) * (1.0 - k)
		for tr in row.get_children():
			if tr is TextureRect and (tr as TextureRect).texture == null and tr.has_meta(&"kind"):
				(tr as TextureRect).texture = _icons.get_icon(String(tr.get_meta(&"kind")))
		if left <= 0.0:
			t.queue_free()


# --- frame --------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			show_debug = not show_debug
		elif event.physical_keycode == KEY_F1:
			_help_label.text = help_text()       # (the element and the keys as they are now)
			_help_box.visible = not _help_box.visible
			_help_t = 0.0


func _process(delta: float) -> void:
	_hit_flash = maxf(_hit_flash - delta * 4.0, 0.0)
	_kill_flash = maxf(_kill_flash - delta * 2.0, 0.0)
	_cross.queue_redraw()
	_help_t = maxf(0.0, _help_t - delta)
	_help_hint.modulate.a = clampf(_help_t / 2.0, 0.0, 1.0)
	_tick_toasts(delta)
	if player == null:
		return
	_update_vitals()
	_update_edges(delta)
	if arena:
		_update_arena(delta)              # (no world readouts: no clock, no slot strip; the BendStrip and MatchBar run themselves)
		_slots_box.visible = false
	else:
		_update_card()
		_update_clock()
	var cam := get_viewport().get_camera_3d()
	if cam:
		var f := -cam.global_transform.basis.z
		_heading = fposmod(rad_to_deg(atan2(f.x, -f.z)) - WorldClock.north_offset_deg(), 360.0)
	_compass.queue_redraw()
	# A thrown weapon in key reach (ThrownPickup; E takes it, walking over it too).
	var pk := ThrownPickup.nearest_for(player)
	_pickup.text = pk.prompt(player) if pk else ""
	_debug.visible = show_debug
	if show_debug and player.weapon:
		var w := player.weapon
		_debug.text = "spread %.2f°\nspeed  %.1f m/s %s\nhits   %d / %d\nfps    %d" % [
			w.spread, player.horizontal_speed(),
			"(crouch)" if player.is_crouching else ("(walk)" if player.is_walking else ("(sprint)" if player.is_sprinting else "")),
			_hits, _shots, Engine.get_frames_per_second()]


func _update_vitals() -> void:
	var mh := maxf(float(player.max_health), 1.0)
	_health_bar.value = clampf(player.health / mh, 0.0, 1.0)
	_bleed_bar.value = clampf((player.health + (player.wounds.pool if player.wounds else 0.0)) / mh, 0.0, 1.0)
	_health_text.text = "%d" % int(ceil(player.health))
	var b := SurvivalBridge.find(get_tree())
	_cap_bar.value = clampf(1.0 - (b.health_cap() if b else mh) / mh, 0.0, 1.0)
	_cap_bar.visible = _cap_bar.value > 0.005
	# well rested: the sleep's boost counting down; the empty track, dimmed, when there is none
	_rest_row.visible = b != null
	if b:
		var left := b.rested_hours_left()
		_rest_bar.value = clampf(left / REST_FULL_H, 0.0, 1.0)
		_rest_text.text = "%d h" % maxi(ceili(left - 0.01), 1) if left > 0.0 else ""
		_rest_row.modulate.a = 1.0 if left > 0.0 else 0.5
	var t: PlayerTorch = player.torch
	var held: TorchState = t.held if t else null
	var n := t.count() if t else 0
	_torch_row.visible = held != null or n > 0
	if held != null:
		_torch_bar.visible = true
		_torch_bar.value = clampf(held.burn_left / maxf(held.burn_total, 1.0), 0.0, 1.0)
		var left := int(ceil(held.burn_left))
		_torch_text.text = "%d:%02d%s%s" % [left / 60, left % 60, "" if held.lit else "  out", "   ×%d" % n if n > 0 else ""]
	else:
		_torch_bar.visible = false
		_torch_text.text = "Torches ×%d  (T)" % n
	# the needs as badges (the grip's stamina is GripRing's circle, not here)
	_needs_row.visible = b != null and b.core != null
	_needs_t -= get_process_delta_time()
	if _needs_row.visible and _needs_t <= 0.0:
		_needs_t = 0.5           # (the stages change over game minutes: twice a second is plenty)
		var st := b.core.need_stages()
		for id: String in _need_icons:
			var ic := _need_icons[id] as TextureRect
			ic.visible = st.has(id)
			if ic.visible:
				var sev := SurvivalNeeds.stage_severity(b.core, id, String(st[id]))
				ic.modulate = BADGE_OK if sev <= 0 else BADGE_WARN if sev == 1 else BADGE_BAD
	# all well: the vitals step back
	var vit := _health_bar.get_parent().get_parent().get_parent() as Control
	var calm := _health_bar.value >= 0.999 and held == null
	vit.modulate.a = move_toward(vit.modulate.a, 0.55 if calm else 1.0, get_process_delta_time() * 2.0)


## Low health: a slow red heartbeat at the edges, quicker and stronger the lower it goes; a flash on each hurt.
func _update_edges(delta: float) -> void:
	var h := clampf(player.health / maxf(float(player.max_health), 1.0), 0.0, 1.0)
	if _last_health >= 0.0 and player.health < _last_health - 0.5:
		_hurt = minf(1.0, _hurt + 0.35 + (_last_health - player.health) / maxf(float(player.max_health), 1.0))
	_last_health = player.health
	_hurt = maxf(0.0, _hurt - delta * 1.6)
	var low := clampf((LOW_HEALTH - h) / LOW_HEALTH, 0.0, 1.0) if not player.is_dead else 0.0
	_beat = fposmod(_beat + delta * lerpf(0.9, 1.6, low), 1.0)
	# lub-dub: two quick swells, then rest
	var pulse := maxf(exp(-pow((_beat - 0.1) / 0.06, 2.0)), 0.7 * exp(-pow((_beat - 0.3) / 0.07, 2.0)))
	var a := low * (0.7 + 0.3 * pulse) + _hurt * 0.6
	_edge.visible = a > 0.005
	if _edge.visible:
		(_edge.material as ShaderMaterial).set_shader_parameter(&"amount", clampf(a, 0.0, 0.9))


func _update_card() -> void:
	var g: GatherTools = player.gather
	var tool := g.in_hand() if g else ""
	var line := ""
	var hb: Hotbar = player.hotbar
	var sp := hb.spell if hb != null else String(player.get_meta(&"sway_spell", ""))   # (spells only from the bar: Hotbar.spell)
	if sp != "":
		line = _spell_line(sp)
	elif tool == "" and player.weapon != null and player.weapon.active and not player.hands_free:
		var w := player.weapon
		var parts := PackedStringArray()
		for x: String in [w.ammo_text(), w.status_text()]:
			if x != "":
				parts.append(x)
		line = "  ·  ".join(parts)
	_ammo.text = line
	_ammo.visible = line != ""
	_update_slots(tool)
	_update_quick()
	_slots_box.visible = _ammo.visible or _slots_shown > 0 or quick_row.visible


## The world HUD's quick spell row (outside the arena, the player with an element: the duel): "LMB  Rock Jab (pebbles)"
## and the help line; hidden in the open world without an element (LMB is the weapon's there).
func _update_quick() -> void:
	var c := SwayCaster.of(player)
	var ql := KitWords.move_name(c.quick_id(), c.quick_mode()) if c != null and c.quick_ready() else ""
	quick_name.text = ql
	quick_row.visible = ql != ""
	quick_help.text = BendStrip.q_text(c) if ql != "" else ""
	quick_help.visible = quick_help.text != ""


## A readied spell's line: its name and mode, the caster's motes and its mastery when there is one ("Stone Form (cannonball)
##  ·  motes 2/3  ·  practised"; SwayCaster.spell_label, tier_name). No motes with free use (SwayCaster.free_use; the user,
## 2026-10-03: "lets make the spells free use right now"): nothing is spent.
func _spell_line(id: String) -> String:
	var c := player.get_node_or_null("SwayCaster")
	var line := String(c.call(&"spell_label", id)) if c != null and c.has_method(&"spell_label") else Hotbar.spell_label(id)
	# (what the Form spell would raise from the place aimed at, the aim held: "Earth Wall: mud"; FormCast.matter_label; the
	# user, 2026-10-03: "if the terrain is mud its a mud wall if its a tree i can make a tree wall")
	var fm: Variant = c.get("form") if c != null else null
	if fm is FormCast:
		var ml := (fm as FormCast).matter_label(id)
		if ml != "":
			line += ": " + ml
	# (a bending skill: its variation's place, the key's other skill, a waterbender's water; docs/bending_design.md)
	var ms: Array = SwayMoves.move(id).get("modes", [])
	if ms.size() > 1 and c != null and c.has_method(&"base_mode_of"):
		line += "  %d/%d" % [ms.find(String(c.call(&"base_mode_of", id))) + 1, ms.size()]     # (the key's: never the quick lock's)
	var other := Bending.partner_of(id)
	if other != "":
		line += "  ·  again: " + String(SwayMoves.move(other).get("label", other))
	if Bending.element_of(id) == "water":
		var b := Bending.of(player)
		line += "  ·  water %d" % roundi(b.water)
	if c != null and c.get("motes") != null and c.get("belt_max") != null and not SwayCaster.free_use():
		line += "  ·  motes %d/%d" % [int(c.get("motes")), int(c.get("belt_max"))]
	if c != null and c.has_method(&"tier_name"):
		line += "  ·  " + String(c.call(&"tier_name", id))
	return line


## Spell `id`'s mode on the player's caster as its key has it ("" none; never the quick lock's frozen one).
func _spell_mode(id: String) -> String:
	var c := player.get_node_or_null("SwayCaster")
	return String(c.call(&"base_mode_of", id)) if c != null and c.has_method(&"base_mode_of") else ""


var _slots_shown := 0


func _update_slots(tool: String) -> void:
	var entries := []
	var hb: Hotbar = player.hotbar
	if hb != null:
		# the hotbar: only its filled slots, numbered by slot
		var sel := hb.selected()
		for i in Hotbar.SLOTS:
			if hb.filled(i):
				entries.append([str(i + 1), hb.icon_kind(i), i == sel])
	else:
		for i in player.weapon_order.size():
			var k := String(player.weapon_order[i])
			entries.append([str(i + 1), k, k == player.weapon_key and tool == "" and not player.hands_free])
		if player.gather:
			for tk: String in GatherTools.ORDER:
				if player.gather.owns(tk):
					entries.append(["7", tk, tk == tool])
	_slots_shown = entries.size()
	while _slot_boxes.size() < entries.size():
		var ov := Control.new()
		ov.custom_minimum_size = Vector2(56, 56)
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.draw.connect(_draw_slot.bind(ov))
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3
		tr.offset_top = 3
		tr.offset_right = -3
		tr.offset_bottom = -7
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.add_child(tr)
		var l := _label(14, TEXT)
		l.position = Vector2(1, -4)
		ov.add_child(l)
		# (a spell's mode mark over the icon: its own layer, drawn after the picture)
		var mk := Control.new()
		mk.name = "Mark"
		mk.set_anchors_preset(Control.PRESET_FULL_RECT)
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mk.draw.connect(_draw_mark.bind(ov, mk))
		ov.add_child(mk)
		_slots_row.add_child(ov)
		_slot_boxes.append([ov, tr, l])
	for i in _slot_boxes.size():
		var box: Array = _slot_boxes[i]
		var ov: Control = box[0]
		ov.visible = i < entries.size()
		if i >= entries.size():
			continue
		var e: Array = entries[i]
		var on := bool(e[2])
		var l: Label = box[2]
		l.text = String(e[0])
		l.add_theme_color_override("font_color", GOLD if on else TEXT)
		var tr: TextureRect = box[1]
		var spell := String(e[1]).begins_with("spell:")
		var sp_tex: Texture2D = spell_texture(String(e[1]).trim_prefix("spell:"), get_tree()) \
				if spell and (tr.get_meta(&"kind", "") != e[1] or tr.texture == null) else null
		if spell and (tr.get_meta(&"kind", "") != e[1] or sp_tex != null):
			# a spell: its own icon when there is one (spell_texture: the svg, else ItemIcons' painting as it comes), else its
			# circle is drawn
			tr.texture = sp_tex
			tr.modulate = GOLD if sp_tex != null and sp_tex.resource_path.ends_with(".svg") else Color.WHITE
			tr.set_meta(&"kind", e[1])
			ov.set_meta(&"spell", tr.texture == null)
			ov.queue_redraw()
		elif not spell and _icons and (tr.texture == null or tr.get_meta(&"kind", "") != e[1]):
			tr.texture = _icons.get_icon(String(e[1]))
			tr.modulate = Color.WHITE
			tr.set_meta(&"kind", e[1])
			ov.set_meta(&"spell", false)
			ov.queue_redraw()
		if bool(ov.get_meta(&"active", false)) != on:
			ov.set_meta(&"active", on)
			ov.queue_redraw()
		var md := _spell_mode(String(e[1]).trim_prefix("spell:")) if spell else ""
		if String(ov.get_meta(&"mode", "")) != md:
			ov.set_meta(&"mode", md)             # (a spell's mode: its corner mark, draw_mode_mark)
			ov.queue_redraw()
			(ov.get_node(^"Mark") as Control).queue_redraw()
		ov.modulate.a = move_toward(ov.modulate.a, 1.0 if on else 0.62, get_process_delta_time() * 4.0)


## A slot: the icon's own shadow under it (it reads over snow or sky); the one in the hands a warm glow behind it
## and a gold rule under it.
func _draw_slot(ov: Control) -> void:
	var s := ov.size
	var tr := ov.get_child(0) as TextureRect
	if bool(ov.get_meta(&"active", false)):
		ov.draw_texture_rect(shade(), Rect2(Vector2(-8, 0), s + Vector2(16, 0)), false, Color(1.0, 0.78, 0.4, 0.4))
		ov.draw_line(Vector2(10, s.y - 2), Vector2(s.x - 10, s.y - 2), Color(0, 0, 0, 0.5), 4.0)
		ov.draw_line(Vector2(10, s.y - 2), Vector2(s.x - 10, s.y - 2), GOLD, 2.0)
	if bool(ov.get_meta(&"spell", false)):
		draw_spell_circle(ov, Rect2(tr.position, tr.size))
	if tr.texture:
		var r := Rect2(tr.position, tr.size)
		var ts := tr.texture.get_size()
		var k := minf(r.size.x / ts.x, r.size.y / ts.y)
		var fit := Rect2(r.position + (r.size - ts * k) * 0.5, ts * k)
		for o: Vector2 in [Vector2(1.5, 1.5), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			ov.draw_texture_rect(tr.texture, Rect2(fit.position + o, fit.size), false, Color(0, 0, 0, 0.45))


## A spell slot's mode mark: a badge on the icon's bottom-right corner (over the picture, clear of the next slot's number).
func _draw_mark(ov: Control, mk: Control) -> void:
	var md := String(ov.get_meta(&"mode", ""))
	if md != "":
		var s := mk.size
		draw_mode_mark(mk, Rect2(Vector2(s.x - 21, s.y - 27), Vector2(19, 19)), md, true)


## A spell with no icon of its own: the Form circle's look in ink (FormCircle, shaders/sway/form_circle.gdshader: a surveyor's
## compass card): a double outer ring, a band of compass ticks (the four quarters long), an inner ring, the quartering lines,
## two crossed squares (one on the points, one on the faces) and a small ring at the heart; over a shadow.
static func draw_spell_circle(ov: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.46
	for pass_i in 2:
		var shadow := pass_i == 0
		var col := Color(0, 0, 0, 0.45) if shadow else Color(0.8, 0.9, 1.0, 0.95)
		var w := 2.6 if shadow else 1.2
		var o := Vector2(1.2, 1.2) if shadow else Vector2.ZERO
		var m := c + o
		# the outer double ring
		ov.draw_arc(m, rad, 0.0, TAU, 48, col, w, true)
		ov.draw_arc(m, rad * 0.9, 0.0, TAU, 44, col, w * 0.7, true)
		# the compass ticks: sixteen, the four quarters reaching in further
		for k in 16:
			var a := TAU * float(k) / 16.0 - PI * 0.5
			var d := Vector2(cos(a), sin(a))
			var r0 := 0.66 if k % 4 == 0 else 0.74
			ov.draw_line(m + d * rad * r0, m + d * rad * 0.84, col, w * (0.9 if k % 4 == 0 else 0.6), true)
		# the inner ring
		ov.draw_arc(m, rad * 0.58, 0.0, TAU, 36, col, w * 0.8, true)
		# the quartering lines, ring to ring
		for k in 4:
			var a := TAU * float(k) / 4.0
			var d := Vector2(cos(a), sin(a))
			ov.draw_line(m + d * rad * 0.16, m + d * rad * 0.58, col, w * 0.55, true)
		# two crossed squares inside the inner ring: one on the points (a diamond), one on the faces
		for k in 2:
			var pts := PackedVector2Array()
			for j in 5:
				var a := TAU * float(j % 4) / 4.0 + (PI * 0.25 if k == 1 else 0.0)
				pts.append(m + Vector2(cos(a), sin(a)) * rad * 0.56)
			ov.draw_polyline(pts, col, w * 0.7, true)
		# the small ring at the heart
		ov.draw_arc(m, rad * 0.14, 0.0, TAU, 20, col, w * 0.7, true)


## A spell's mode as a small mark in the corner `r` of its slot (the mode key flips it: SwayCaster.flip_mode): "spike" a jagged
## spike, "cannonball" a ringed ball (a ball with a ring round it and a dark pit: no plain dot, which is the fallback's and the
## motes'), "self" a column under a figure's mark (an arrow up from a bar), "free" a small aiming circle; any other a dot. In
## the HUD's ink over a shadow; `badge`: on a dark disc with a gold rim (over an icon, so it reads as a mark, not the icon's).
static func draw_mode_mark(ci: CanvasItem, r: Rect2, mode: String, badge := false) -> void:
	var c := r.get_center()
	var k := minf(r.size.x, r.size.y) * 0.5
	if badge:
		ci.draw_circle(c, k * 1.02, Color(0.07, 0.06, 0.05, 0.82))
		ci.draw_arc(c, k * 1.02, 0.0, TAU, 28, Color(GOLD.r, GOLD.g, GOLD.b, 0.9), 1.2, true)
		k *= 0.78
	for pass_i in 2:
		var shadow := pass_i == 0
		var col := Color(0, 0, 0, 0.55) if shadow else Color(1.0, 0.92, 0.7, 1.0)
		var o := Vector2(1.0, 1.0) if shadow else Vector2.ZERO
		var w := 2.6 if shadow else 1.4
		var m := c + o
		match mode:
			"spike":
				var pts := PackedVector2Array([m + Vector2(-0.55, 0.85) * k, m + Vector2(-0.3, 0.1) * k, m + Vector2(-0.42, -0.05) * k,
						m + Vector2(-0.05, -0.9) * k, m + Vector2(0.12, -0.25) * k, m + Vector2(0.25, -0.33) * k, m + Vector2(0.5, 0.85) * k])
				if shadow:
					ci.draw_polyline(pts + PackedVector2Array([pts[0]]), col, w, true)
				else:
					ci.draw_colored_polygon(pts, col)
			"cannonball":
				ci.draw_circle(m, k * 0.48, col)
				ci.draw_arc(m, k * 0.8, 0.0, TAU, 24, col, w * 0.8, true)
				if not shadow:
					ci.draw_circle(m + Vector2(-0.17, -0.17) * k, k * 0.13, Color(0.2, 0.17, 0.12, 0.9))
			"self":
				ci.draw_line(m + Vector2(-0.6, 0.8) * k, m + Vector2(0.6, 0.8) * k, col, w, true)
				ci.draw_line(m + Vector2(0.0, 0.6) * k, m + Vector2(0.0, -0.75) * k, col, w, true)
				ci.draw_polyline(PackedVector2Array([m + Vector2(-0.42, -0.32) * k, m + Vector2(0.0, -0.8) * k, m + Vector2(0.42, -0.32) * k]), col, w, true)
			"free":
				ci.draw_arc(m, k * 0.55, 0.0, TAU, 20, col, w, true)
				for a in 4:
					var dv := Vector2.from_angle(TAU * a / 4.0)
					ci.draw_line(m + dv * k * 0.3, m + dv * k * 0.9, col, w * 0.8, true)
			_:
				ci.draw_circle(m, k * 0.3, col)


## A spell's picture for the strip and the Tab screen: its own icon (assets/ui/icons/spell_<id>.svg), else ItemIcons'
## painting of it (SwayCaster.spell_icon: null until painted); null: draw_spell_circle.
static func spell_texture(id: String, tree: SceneTree) -> Texture2D:
	var path := ICON_DIR + "spell_" + id + ".svg"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return SwayCaster.spell_icon(id, tree)


func _update_clock() -> void:
	var scene := get_tree().current_scene
	var rig: Variant = scene.get("environment_rig") if scene else null
	var dn: DayNight = (rig as EnvironmentRig).clock_driver if rig is EnvironmentRig else null
	if dn == null or dn.clock == null:
		_clock.text = ""
		_clock_icon.visible = false
		return
	var c: WorldClock = dn.clock
	_clock.text = "%s  ·  %s" % [c.date_string(), c.time_string()]
	_clock_icon.visible = true
	var want := "hud_sun" if c.sun_direction().y > -0.05 else "hud_moon"
	if _clock_icon.get_meta(&"id", "") != want:
		_clock_icon.texture = icon_texture(want)
		_clock_icon.set_meta(&"id", want)


# --- drawing ------------------------------------------------------------------------------------------

## The compass: a thin line fading at both ends, a tick every 15 degrees, N E S W on it (N red), the between-points
## smaller, and a gold notch under the heading.
func _draw_compass() -> void:
	var w := _compass.size.x
	var h := _compass.size.y
	var mid := w * 0.5
	var span := 160.0                    ## degrees across the strip
	var base := h - 9.0
	var font := serif()
	var fade := func(x: float) -> float: return clampf(1.0 - pow(absf(x - mid) / (w * 0.5), 2.2), 0.0, 1.0)
	# the line, in pieces so it fades out
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 25:
		var x := w * i / 24.0
		pts.append(Vector2(x, base))
		cols.append(Color(INK.r, INK.g, INK.b, 0.75 * fade.call(x)))
	var shadow := PackedColorArray()
	for c in cols:
		shadow.append(Color(0, 0, 0, c.a * 0.5))
	_compass.draw_polyline_colors(pts, shadow, 3.0)
	_compass.draw_polyline_colors(pts, cols, 1.0)
	var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	for d in range(0, 360, 15):
		var rel := wrapf(float(d) - _heading, -180.0, 180.0)
		if absf(rel) > span * 0.5:
			continue
		var x := mid + rel / span * w
		var a: float = fade.call(x)
		if names.has(d):
			var nm: String = names[d]
			var big := nm.length() == 1
			var fs := 20 if big else 14
			var col := NORTH if d == 0 else (INK if big else DIM)
			col.a = a
			var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := Vector2(x - tw * 0.5, base - 5.0)
			_compass.draw_string_outline(font, at, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.45 * a))
			_compass.draw_string(font, at, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		else:
			_compass.draw_line(Vector2(x, base - 4.0), Vector2(x, base + 3.0), Color(TEXT.r, TEXT.g, TEXT.b, a * 0.6), 1.0)
	# the heading: a small gold notch pointing up at the line
	var notch := PackedVector2Array([Vector2(mid, base + 2.0), Vector2(mid - 5.0, base + 9.0), Vector2(mid + 5.0, base + 9.0)])
	_compass.draw_colored_polygon(PackedVector2Array([notch[0] + Vector2(0, -1.5), notch[1] + Vector2(-1.5, 1), notch[2] + Vector2(1.5, 1)]), Color(0, 0, 0, 0.5))
	_compass.draw_colored_polygon(notch, GOLD)


func on_projectile_hit(collider: Object, _pos: Vector3) -> void:
	if collider is Node and _is_target(collider as Node):
		_hits += 1
		_hit_flash = 1.0


func on_target_killed(_target: Node) -> void:
	_kill_flash = 1.0


static func _is_target(n: Node) -> bool:
	while n:
		if n.has_method("apply_hit"):
			return true
		n = n.get_parent()
	return false


func _draw_overlay() -> void:
	if player == null:
		return
	if player.weapon == null:
		_draw_spell_dot()
		return
	var w := player.weapon
	var vp := _cross.get_viewport_rect().size
	var c := vp * 0.5
	var col := color
	if w is Bow and (w as Bow).fatigue() > 0.0:
		col = color.lerp(Color(1.0, 0.55, 0.2), (w as Bow).fatigue())
	var tool_out := player.gather != null and player.gather.in_hand() != ""
	if tool_out:
		# a tool out: a small ring where it is aimed (a piece of wall is chopped where the camera aims)
		_cross.draw_arc(c, 5.0, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 3.0)
		_cross.draw_arc(c, 5.0, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.85), 1.5)
	elif not player.is_sprinting:
		# Aim dot. It is solid when the weapon is fully up and faint while lowered.
		var alpha := lerpf(0.45, 1.0, w.aim)
		_cross.draw_circle(c, dot_radius + 1.2, Color(0, 0, 0, 0.55 * alpha))
		_cross.draw_circle(c, dot_radius, Color(col.r, col.g, col.b, alpha))

	# Draw / reload bar under the crosshair.
	var prog := w.progress()
	if not prog.is_empty():
		var bw := 64.0
		var r := Rect2(c + Vector2(-bw * 0.5, 30), Vector2(bw, 3))
		_cross.draw_rect(r.grow(1), Color(0, 0, 0, 0.5))
		_cross.draw_rect(Rect2(r.position, Vector2(bw * clampf(prog[1], 0.0, 1.0), 3)), col)

	_draw_hit_mark(c)


## The hit mark at the centre (a hit or a kill a moment ago).
func _draw_hit_mark(c: Vector2) -> void:
	var mark := maxf(_hit_flash, _kill_flash)
	if mark > 0.0:
		var mc := Color(1, 0.25, 0.2, _kill_flash) if _kill_flash > 0.0 else Color(1, 1, 1, _hit_flash)
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_cross.draw_line(c + d * 8.0, c + d * 17.0, mc, 2.5)


## No weapon (the arena's empty roster): the aim dot at the centre while a move is readied (the crosshair the casts aim by),
## the hit mark; nothing anywhere else.
func _draw_spell_dot() -> void:
	var c := _cross.get_viewport_rect().size * 0.5
	var hb: Hotbar = player.hotbar
	var readied := hb != null and hb.spell != ""
	if readied and not player.is_sprinting and not player.is_dead:
		_cross.draw_circle(c, dot_radius + 1.2, Color(0, 0, 0, 0.55))
		_cross.draw_circle(c, dot_radius, color)
	_draw_hit_mark(c)


## Whether the aim dot is drawn now (tests: the dot with a move readied and no weapon).
func aim_dot_shown() -> bool:
	if player == null or player.is_sprinting or player.is_dead:
		return false
	if player.weapon == null:
		return player.hotbar != null and player.hotbar.spell != ""
	return player.gather == null or player.gather.in_hand() == ""
