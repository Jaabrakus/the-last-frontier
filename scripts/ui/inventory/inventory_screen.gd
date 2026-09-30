class_name InventoryScreen
extends CanvasLayer
## The character inventory (Tab; user 2026-09-25: "a Char inventory system with drag and drop with gear"; first
## cut of graph_analysis/inventory/inventory_design.md): the pack on the left, a live 3D copy of the character
## in the middle wearing what is worn (SlingRig on Actor_B, as the loadout preview), with a drop spot on every
## place the worn gear offers (the back slings, the quiver strap, the tomahawk frog, the belt and sash hooks),
## and kits on the right. Drag an item from the pack onto a spot to wear it (LoadoutRules decides; a spot that
## cannot take it turns red and says why), or onto the figure, or double-click it, and it goes to the best spot
## (InventoryState.best_point()); drag a worn item off onto the pack to take it off, right-click a worn item to
## take it off too. Tab or Done closes the screen and the player wears the result
## (FrontierPlayer.apply_loadout(); everything stays usable, the screen arranges what rides on the body).
## The game is paused while it is open.
## The doll's rig and clips are Actor_B; weapon and gear models are the project's own.

const KITS_PATH := "user://frontier_kits.json"
const KIT_SLOTS := 3
const IDLE_CLIP := "actor_b-p-stealth-idle"

var player: Node
var inv: InventoryState
var _root: Control
var _msg: Label
var _view: SubViewport
var _view_box: SubViewportContainer
var _spots_layer: Control
var _kits_box: BoxContainer
var _sk: Skeleton3D
var _ap: AnimationPlayer
var _poser: LoadoutClipPoser
var _body: CharacterBodyMesh
var _rig: SlingRig
var _cam: Camera3D
var _doll: Node3D
var _t := 0.0
var _yaw := 200.0
var _take_torch := false
var _was_mouse := Input.MOUSE_MODE_VISIBLE
## The character screen's tabs (user 2026-09-26: "the char screen the skills tab"): Gear (this inventory) and
## Skills (SkillsPanel); K opens the screen on Skills.
var start_tab := "gear"
var tab := ""
var _gear: VBoxContainer
var _skills: SkillsPanel
var _condition: ConditionPanel    ## the body and the vices (user 2026-09-27: "add these stats when we hit tab")
var _tab_buttons := {}


static func open_for(p: Node, tab := "gear") -> InventoryScreen:
	var s := InventoryScreen.new()
	s.player = p
	s.start_tab = tab
	p.get_tree().root.add_child(s)
	return s


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	inv = InventoryState.from_player(player)
	_was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_build_ui()
	_build_doll()
	_refresh()
	show_tab(start_tab)


func close() -> void:
	if player and is_instance_valid(player) and player.has_method("apply_loadout"):
		player.apply_loadout(inv.worn, inv.pack)
		if _take_torch and player.get("torch") != null:
			(player.get("torch") as PlayerTorch).take_out()
	get_tree().paused = false
	Input.mouse_mode = _was_mouse if _was_mouse != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == SKILLS_KEY:
		get_viewport().set_input_as_handled()
		if tab == "skills":
			close()
		else:
			show_tab("skills")


const SKILLS_KEY := KEY_K


## Shows a tab: "gear", "skills" or "condition".
func show_tab(t: String) -> void:
	tab = t if t in ["gear", "skills", "condition"] else "gear"
	_gear.visible = tab == "gear"
	_skills.visible = tab == "skills"
	_condition.visible = tab == "condition"
	if tab == "condition":
		_condition.refresh()
	for k: String in _tab_buttons:
		var b: Button = _tab_buttons[k]
		b.button_pressed = k == tab
		b.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45) if k == tab else Color(0.75, 0.7, 0.6))


# --- layout -------------------------------------------------------------------------------------

## Equipment slots: the left column, then the right, beside the character (only those the worn gear offers
## take items; the rest show locked).
const LEFT_SLOTS := ["long_A", "long_B", "quiver", "back", "back_2"]
const RIGHT_SLOTS := ["R_hip", "L_hip", "back_right", "chest_R", "chest_L", "tool_loop"]
const SHORT := {"long_A": "Back", "long_B": "Back 2", "quiver": "Quiver", "back": "Frog", "back_2": "Frog 2",
		"R_hip": "R hip", "L_hip": "L hip", "back_right": "Belt", "chest_R": "Chest R", "chest_L": "Chest L",
		"tool_loop": "Tool"}
const CELL := 84
## The pack list's width, and the item detail's beside it.
const PACK_LIST_W := 300
const DETAIL_W := 330

var _slot_cells := {}               ## point -> SlotCell
var _pack_grid: VBoxContainer     ## the pack's list (the name is the grid's it replaced: tools read it)
var icons: ItemIcons


func _build_ui() -> void:
	icons = ItemIcons.shared(get_tree())
	icons.ready_icon.connect(func(_k: String) -> void: _refresh_icons())
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	th.default_font = FrontierHUD.serif()
	_root.theme = th
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.04, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	outer.grow_vertical = Control.GROW_DIRECTION_BOTH
	outer.add_theme_constant_override("separation", 12)
	_root.add_child(outer)
	# the tabs: Gear (this screen's inventory) and Skills
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	outer.add_child(tabs)
	for pair: Array in [["gear", "Gear  (Tab)"], ["skills", "Skills  (K)"], ["condition", "Condition"]]:
		var tb := Button.new()
		tb.text = String(pair[1])
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(150, 36)
		tb.add_theme_font_size_override("font_size", 17)
		var key := String(pair[0])
		tb.pressed.connect(func() -> void: show_tab(key))
		tabs.add_child(tb)
		_tab_buttons[key] = tb
	_gear = VBoxContainer.new()
	_gear.add_theme_constant_override("separation", 12)
	outer.add_child(_gear)
	var gs: Variant = player.get("gather")
	var br := SurvivalBridge.find(player.get_tree()) if player else null
	_skills = SkillsPanel.make((gs as GatherTools).skills if gs != null else null, br.core if br else null)
	outer.add_child(_skills)
	_condition = ConditionPanel.make(player)
	outer.add_child(_condition)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_gear.add_child(row)
	# equipment: slot column, character, slot column
	var eq := _panel("Equipment", 0)
	row.add_child(eq)
	var eq_row := HBoxContainer.new()
	eq_row.add_theme_constant_override("separation", 10)
	eq.get_child(0).add_child(eq_row)
	eq_row.add_child(_slot_column(LEFT_SLOTS))
	var doll_box := Control.new()
	doll_box.custom_minimum_size = Vector2(240, CELL * 5 + 6 * 4)
	eq_row.add_child(doll_box)
	_view_box = SubViewportContainer.new()
	_view_box.stretch = true
	_view_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll_box.add_child(_view_box)
	# dropping an item from the pack on the figure wears it at its best spot
	var drop := Control.new()
	drop.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop.set_drag_forwarding(Callable(), _doll_can_drop, _doll_drop)
	doll_box.add_child(drop)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view_box.add_child(_view)
	eq_row.add_child(_slot_column(RIGHT_SLOTS))
	var turn := HBoxContainer.new()
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	eq.get_child(0).add_child(turn)
	for pair in [["<", -45.0], ["Front", 20.0], ["Back", 200.0], [">", 45.0]]:
		var bt := Button.new()
		bt.text = String(pair[0])
		var v := float(pair[1])
		var rel := String(pair[0]) in ["<", ">"]
		bt.pressed.connect(func() -> void: _yaw = _yaw + v if rel else v)
		turn.add_child(bt)
	# the pack: a list, a row an item (its icon, name and count; user 2026-09-27: the wheelbarrow's rows "look better"),
	# what the picked item does beside it
	var pk := _panel("Pack", 0)
	row.add_child(pk)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	pk.get_child(0).add_child(cols)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PACK_LIST_W, CELL * 5 + 6 * 4)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	_pack_grid = VBoxContainer.new()
	_pack_grid.add_theme_constant_override("separation", 1)
	_pack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pack_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pack_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	# a worn item dropped anywhere on the list comes off into the pack
	_pack_grid.set_drag_forwarding(Callable(), _list_can_drop, _list_drop)
	scroll.add_child(_pack_grid)
	cols.add_child(_build_detail())
	# kits and messages
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	_gear.add_child(bottom)
	_kits_box = HBoxContainer.new()
	_kits_box.add_theme_constant_override("separation", 14)
	bottom.add_child(_kits_box)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var done := Button.new()
	done.text = "Done (Tab)"
	done.custom_minimum_size = Vector2(140, 40)
	done.pressed.connect(close)
	bottom.add_child(done)
	_msg = _label("Drag items onto the equipment slots to wear them; right-click a slot to take it off. Point at an item to see what it does.", 17, Color(0.9, 0.85, 0.75))
	_gear.add_child(_msg)
	_spots_layer = Control.new()


func _slot_column(points: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	for p: String in points:
		var c := SlotCell.new()
		c.screen = self
		c.point = p
		v.add_child(c)
		_slot_cells[p] = c
	return v


# --- what an item is and does (ItemInfo) -------------------------------------------------------

const DETAIL_ICON := 72
const INK := Color(0.96, 0.9, 0.76)
const DIM := Color(0.66, 0.61, 0.52)
const TONES := {"good": "#a9d67a", "warn": "#f0a24e", "use": "#e8c170", "": "#e6dcc6"}

var picked := ""                    ## the item clicked in the pack (its stats stay up)
var _shown := ""
var _d_icon: TextureRect
var _d_name: Label
var _d_tag: Label
var _d_text: Label
var _d_rows: RichTextLabel


func _build_detail() -> Control:
	var v := VBoxContainer.new()
	v.name = "Detail"
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(DETAIL_W, 0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	_d_icon = TextureRect.new()
	_d_icon.custom_minimum_size = Vector2(DETAIL_ICON, DETAIL_ICON)
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(_d_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(names)
	_d_name = _label("", 25, INK)
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_name.custom_minimum_size = Vector2(DETAIL_W - DETAIL_ICON - 14, 0)
	names.add_child(_d_name)
	_d_tag = _label("", 15, DIM)
	names.add_child(_d_tag)
	_d_text = _label("", 17, Color(0.86, 0.81, 0.71))
	_d_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_text.custom_minimum_size = Vector2(DETAIL_W, 0)
	v.add_child(_d_text)
	_d_rows = RichTextLabel.new()
	_d_rows.bbcode_enabled = true
	_d_rows.fit_content = true
	_d_rows.scroll_active = false
	_d_rows.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_rows.custom_minimum_size = Vector2(DETAIL_W, 0)
	_d_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_rows.add_theme_font_size_override("normal_font_size", 17)
	_d_rows.add_theme_font_size_override("bold_font_size", 17)
	_d_rows.add_theme_constant_override("table_h_separation", 14)
	_d_rows.add_theme_constant_override("table_v_separation", 1)
	v.add_child(_d_rows)
	_show_detail("")
	return v


## Clicks an item in the pack: its stats stay up while the mouse is elsewhere ("" clears).
func pick(kind: String) -> void:
	picked = kind
	_show_detail(kind)
	_mark_picked()


## The mouse over an item (a pack cell or a worn slot); "" when it leaves: back to the picked one.
func hover(kind: String) -> void:
	_show_detail(kind if kind != "" else picked)


func _show_detail(kind: String) -> void:
	_shown = kind
	if _d_name == null:
		return
	if kind == "":
		_d_icon.texture = null
		_d_name.text = ""
		_d_tag.text = ""
		_d_text.text = "Point at an item to see what it does; click it to keep it here."
		_d_rows.text = ""
		return
	var info := ItemInfo.of(kind, player, inv.pack_count(kind))
	_d_icon.texture = icons.get_icon(kind)
	_d_name.text = String(info.name)
	_d_tag.text = String(info.tag).to_upper()
	_d_text.text = String(info.text)
	if String(info.get("history", "")) != "":
		_d_text.text += "\n\nHistory. " + String(info.history)
	var b := "[table=2]"
	for r: Array in info.rows:
		b += "[cell][color=#a0968a]%s[/color][/cell][cell][color=%s]%s[/color][/cell]" % [r[0], TONES.get(r[2], TONES[""]), r[1]]
	_d_rows.text = b + "[/table]"


func _mark_picked() -> void:
	_fill_pack()


## The pack's rows, one an entry of the pack in its order (made as the pack grows, hidden when it shrinks).
func _fill_pack() -> void:
	while _pack_grid.get_child_count() < inv.pack.size():
		var c := PackCell.new()
		c.screen = self
		c.index = _pack_grid.get_child_count()
		_pack_grid.add_child(c)
	for c in _pack_grid.get_children():
		var pc := c as PackCell
		pc.set_entry(inv.pack[pc.index] if pc.index < inv.pack.size() else {})


func _list_can_drop(_at: Vector2, d: Variant) -> bool:
	return d is Dictionary and String(d.get("from", "")) == "body"


func _list_drop(_at: Vector2, d: Variant) -> void:
	take_off(String(d.point))


func _panel(title: String, w: float) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.08, 0.7)
	sb.border_color = Color(0.5, 0.4, 0.26, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	v.add_child(_label(title, 24, Color(0.93, 0.8, 0.52)))
	return pc


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# --- the doll -----------------------------------------------------------------------------------

func _build_doll() -> void:
	_doll = Node3D.new()
	_view.add_child(_doll)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.17, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.45)
	e.ambient_light_energy = 0.9
	env.environment = e
	_doll.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.4
	_doll.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 210, 0)
	fill.light_energy = 0.6
	_doll.add_child(fill)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	_doll.add_child(inst)
	_sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(_sk, _ap)
	_body = CharacterBodyMesh.attach(_sk, _ap)
	# the player's face, skin and hair (PlayerAppearance) on the doll too
	var app = player.get("appearance") if player else null
	if _body and app is PlayerAppearance:
		PlayerAppearance.dress(_body, (app as PlayerAppearance).look)
	_poser = LoadoutClipPoser.new(_sk, _ap)
	_rig = SlingRig.new()
	_rig.name = "SlingRig"
	_doll.add_child(_rig)
	_rig.setup(_sk, _body, inv.worn)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_doll.add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	if _poser and _poser.has_clip(IDLE_CLIP):
		_poser.pose([[IDLE_CLIP, fmod(_t, maxf(_poser.length(IDLE_CLIP), 0.01))]])
	var a := deg_to_rad(_yaw)
	var target := Vector3(0, 1.05, 0)
	_cam.global_position = target + Vector3(sin(a), 0.12, cos(a)) * 4.2
	_cam.look_at(target, Vector3.UP)


# --- contents -----------------------------------------------------------------------------------

func _refresh() -> void:
	var offered := inv.points()
	for p: String in _slot_cells:
		(_slot_cells[p] as SlotCell).set_state(offered.has(p), inv.item_at(p))
	_fill_pack()
	if _rig:
		_rig.set_loadout(inv.worn)
	_refresh_kits()
	if picked != "" and not _owns(picked):
		picked = ""
	_show_detail(_shown if _shown != "" and _owns(_shown) else picked)


## In the pack or worn.
func _owns(kind: String) -> bool:
	if inv.pack_count(kind) > 0:
		return true
	for it: Dictionary in inv.worn.items:
		if String(it.kind) == kind:
			return true
	return false


func _refresh_icons() -> void:
	if is_inside_tree():
		_refresh()
		if _d_icon and _shown != "" and _d_icon.texture == null:
			_d_icon.texture = icons.get_icon(_shown)


func _refresh_kits() -> void:
	for c in _kits_box.get_children():
		c.queue_free()
	var kits := _load_kits()
	for i in KIT_SLOTS:
		var k: Dictionary = kits[i] if i < kits.size() else {}
		var v := VBoxContainer.new()
		var kl := _label("Kit %d%s" % [i + 1, (": " + String(k.get("name", ""))) if not k.is_empty() else " (empty)"], 15, Color(0.92, 0.85, 0.7))
		kl.custom_minimum_size = Vector2(200, 0)
		kl.clip_text = true
		v.add_child(kl)
		var h := HBoxContainer.new()
		var wear := Button.new()
		wear.text = "Wear"
		wear.disabled = k.is_empty()
		var idx := i
		wear.pressed.connect(func() -> void: _wear_kit(idx))
		h.add_child(wear)
		var save := Button.new()
		save.text = "Save current"
		save.pressed.connect(func() -> void: _save_kit(idx))
		h.add_child(save)
		v.add_child(h)
		_kits_box.add_child(v)


func say(text: String, bad := false) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if bad else Color(0.9, 0.85, 0.75))


func try_wear(kind: String, p: String) -> void:
	var r := inv.can_wear(kind, p)
	if not bool(r.ok):
		say(String(r.reason), true)
		return
	inv.wear(kind, p)
	say("%s on the %s.%s" % [InventoryState.name_of(kind), InventoryState.point_name(p).to_lower(),
			(" Note: " + String(r.reason)) if String(r.reason) != "" else ""])
	_refresh()


## Right-click on the pack's torches (push n01b): one comes into the left hand, lit, when the screen closes (T in
## play does the same).
func use_item(kind: String) -> void:
	var br := SurvivalBridge.find(player.get_tree()) if player else null
	if br and br.can_eat(kind):
		# food: eaten from this screen's copy of the pack (SurvivalBridge.eat)
		var r := br.eat(kind, inv)
		say(String(r.text), not bool(r.ok))
		_refresh()
		return
	if ForageUse.can_use(kind):
		# a herb (plantain: a poultice on a wound; scripts/forage/forage_use.gd)
		say(ForageUse.use(player, kind, inv))
		_refresh()
		return
	if Remedies.can_use(kind):
		# a remedy from the alchemy table (salve, tea, tonic; scripts/survival_game/remedies.gd)
		say(Remedies.use(player, kind, inv))
		_refresh()
		return
	var vc: Vices = br.vices if br else null
	if vc and Vices.can_use(kind):
		# laudanum, snuff, a quid (Vices)
		say(vc.use_item(kind, inv))
		_refresh()
		return
	if vc and Vices.can_choose(kind):
		# a drink or a pipe fill: the next gill (U) or pipeful (Y) is of it
		say(vc.choose(kind))
		return
	if kind != InventoryState.TORCH:
		return
	var t: Variant = player.get("torch") if player else null
	if not (t is PlayerTorch) or (t as PlayerTorch).holding():
		say("A torch is already in your hand.", true)
		return
	_take_torch = not _take_torch
	say("A torch will be in your left hand, lit, when you close the pack (T)." if _take_torch else "The torch stays in the pack.")


## Wears one `kind` from the pack at its best spot (dropped on the figure, or double-clicked in the pack).
func auto_wear(kind: String) -> void:
	var br := SurvivalBridge.find(player.get_tree()) if player else null
	if kind == InventoryState.TORCH or ForageUse.can_use(kind) or Remedies.can_use(kind) or (br and br.can_eat(kind)) \
			or Vices.can_use(kind) or Vices.can_choose(kind):
		use_item(kind)   # a torch or a herb is not worn: double-clicking it uses it, like right-clicking
		return
	var p := inv.best_point(kind)
	if p == "":
		say("No place on the body for the %s with this gear." % InventoryState.name_of(kind).to_lower(), true)
		return
	try_wear(kind, p)


func _doll_can_drop(_at: Vector2, d: Variant) -> bool:
	if not (d is Dictionary) or String(d.get("from", "")) != "pack":
		return false
	var k := String(d.kind)
	var p := inv.best_point(k)
	if p == "":
		say("No place on the body for the %s with this gear." % InventoryState.name_of(k).to_lower(), true)
		return false
	say("%s: %s" % [InventoryState.point_name(p), InventoryState.name_of(k)])
	return true


func _doll_drop(_at: Vector2, d: Variant) -> void:
	auto_wear(String(d.kind))


func take_off(p: String) -> void:
	var it := inv.item_at(p)
	if it.is_empty():
		return
	inv.unwear_point(p)
	say("%s into the pack." % InventoryState.name_of(String(it.kind)))
	_refresh()


# --- kits ---------------------------------------------------------------------------------------

func _load_kits() -> Array:
	if not FileAccess.file_exists(KITS_PATH):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(KITS_PATH))
	return d if d is Array else []


func _save_kit(i: int) -> void:
	var kits := _load_kits()
	while kits.size() < KIT_SLOTS:
		kits.append({})
	var names := []
	for it: Dictionary in inv.worn.items:
		names.append(InventoryState.name_of(String(it.kind)))
	kits[i] = {"name": ", ".join(names.slice(0, 3)) + ("..." if names.size() > 3 else ""), "items": inv.worn.to_dict().get("items", [])}
	var f := FileAccess.open(KITS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(kits))
	say("Saved as kit %d." % (i + 1))
	_refresh_kits()


func _wear_kit(i: int) -> void:
	var kits := _load_kits()
	if i >= kits.size() or (kits[i] as Dictionary).is_empty():
		return
	for p: String in inv.points():
		inv.unwear_point(p)
	var missing := []
	for it: Dictionary in kits[i].get("items", []):
		for p in it.get("points", []):
			var k := String(it.kind)
			if inv.pack_count(k) > 0 and bool(inv.can_wear(k, String(p)).ok):
				inv.wear(k, String(p))
			else:
				missing.append(InventoryState.name_of(k))
	say("Kit %d on.%s" % [i + 1, (" Not in the pack: " + ", ".join(missing)) if not missing.is_empty() else ""], not missing.is_empty())
	_refresh()


# --- drag and drop widgets ----------------------------------------------------------------------

## A square cell: an icon (the item's own model), its count, a caption.
class Cell extends PanelContainer:
	var screen: InventoryScreen
	var kind := ""
	var _sb: StyleBoxFlat
	var _icon: TextureRect
	var _count: Label
	var _cap: Label

	func _ready() -> void:
		custom_minimum_size = Vector2(InventoryScreen.CELL, InventoryScreen.CELL)
		_sb = StyleBoxFlat.new()
		_sb.set_corner_radius_all(4)
		_sb.set_border_width_all(2)
		add_theme_stylebox_override("panel", _sb)
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_icon = TextureRect.new()
		_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon.offset_left = 4
		_icon.offset_top = 4
		_icon.offset_right = -4
		_icon.offset_bottom = -4
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_icon)
		_count = InventoryScreen._label("", 16, Color(1, 0.95, 0.8))
		# top-left anchored at the cell's right: anchored top-right, the offset was taken before the box had its size
		# and the stack count landed past the cell's edge, under the next cell (push n01b: the torch stack's "x4");
		# right-aligned in a fixed box so a longer count (a stack of logs or stone) stays in the cell
		_count.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_count.position = Vector2(InventoryScreen.CELL - 44, 2)
		_count.size = Vector2(40, 20)
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_count.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_count.add_theme_constant_override("outline_size", 4)
		_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_count)
		_cap = InventoryScreen._label("", 13, Color(0.82, 0.74, 0.6))
		_cap.position = Vector2(5, InventoryScreen.CELL - 22)
		_cap.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_cap.add_theme_constant_override("outline_size", 3)
		_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_cap)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER and screen and kind != "":
			screen.hover(kind)
		elif what == NOTIFICATION_MOUSE_EXIT and screen:
			screen.hover("")
			if self is SlotCell and _sb:
				screen._refresh()

	func show_item(k: String, n: int, caption: String, tint: Color, border: Color) -> void:
		kind = k
		_icon.texture = screen.icons.get_icon(k) if k != "" else null
		_count.text = ("×%d" % n) if n > 1 else ""
		_cap.text = caption if caption != "" else (InventoryState.name_of(k) if k != "" and _icon.texture == null else "")
		_sb.bg_color = tint
		_sb.border_color = border
		tooltip_text = InventoryState.name_of(k) if k != "" else ""

	func drag_preview() -> Control:
		var t := TextureRect.new()
		t.texture = _icon.texture
		t.size = Vector2(64, 64)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if t.texture == null:
			return InventoryScreen._label(InventoryState.name_of(kind), 16, Color(1, 0.9, 0.6))
		return t


## A row of the pack's list (user 2026-09-27: the wheelbarrow screen's rows "look better" than the grid of squares):
## the item's icon, its name and how many, no box; the pointer over it a faint wash, the picked one a gold rule at its
## left. Dragged onto a slot or the figure it is worn; a worn item dropped on it comes off; right-click uses it (food,
## a herb, a torch), a double-click wears or uses it, a click picks it (its stats stay beside the list).
class PackCell extends PanelContainer:
	var screen: InventoryScreen
	var index := 0
	var kind := ""
	var _sb: StyleBoxFlat
	var _icon: TextureRect
	var _name: Label
	var _count: Label
	var _hover := false

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 44)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_sb = StyleBoxFlat.new()
		_sb.bg_color = Color(0, 0, 0, 0)
		_sb.border_color = Color(0, 0, 0, 0)
		_sb.border_width_left = 3
		_sb.set_corner_radius_all(2)
		_sb.content_margin_left = 8
		_sb.content_margin_right = 10
		_sb.content_margin_top = 2
		_sb.content_margin_bottom = 2
		add_theme_stylebox_override("panel", _sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		_icon = TextureRect.new()
		_icon.custom_minimum_size = Vector2(38, 38)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_icon)
		_name = InventoryScreen._label("", 18, Color(0.93, 0.88, 0.76))
		_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name.clip_text = true
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_name)
		_count = InventoryScreen._label("", 16, Color(0.8, 0.72, 0.58))
		_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_count)

	func set_entry(e: Dictionary) -> void:
		kind = String(e.get("kind", ""))
		visible = kind != ""
		if kind == "":
			return
		var n := int(e.get("count", 1))
		_icon.texture = screen.icons.get_icon(kind)
		_name.text = InventoryState.name_of(kind)
		_count.text = ("×%d" % n) if n > 1 else ""
		_style()

	func _style() -> void:
		var on := kind != "" and kind == screen.picked
		_sb.bg_color = Color(0.93, 0.74, 0.36, 0.12) if on else (Color(1, 0.95, 0.85, 0.05) if _hover else Color(0, 0, 0, 0))
		_sb.border_color = Color(0.93, 0.74, 0.36) if on else Color(0, 0, 0, 0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER and screen and kind != "":
			_hover = true
			_style()
			screen.hover(kind)
		elif what == NOTIFICATION_MOUSE_EXIT and screen:
			_hover = false
			if _sb:
				_style()
			screen.hover("")

	func drag_preview() -> Control:
		var t := TextureRect.new()
		t.texture = _icon.texture
		t.size = Vector2(64, 64)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if t.texture == null:
			return InventoryScreen._label(InventoryState.name_of(kind), 16, Color(1, 0.9, 0.6))
		return t

	func _get_drag_data(_at: Vector2) -> Variant:
		if kind == "":
			return null
		set_drag_preview(drag_preview())
		return {"from": "pack", "kind": kind}

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		return d is Dictionary and String(d.get("from", "")) == "body"

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed or kind == "":
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			screen.use_item(kind)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			screen.auto_wear(kind)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			screen.pick("" if screen.picked == kind else kind)

	func _drop_data(_at: Vector2, d: Variant) -> void:
		screen.take_off(String(d.point))


class SlotCell extends Cell:
	var point := ""
	var offered := true

	func set_state(on: bool, it: Dictionary) -> void:
		offered = on
		var cap := String(InventoryScreen.SHORT.get(point, point))
		if not on:
			show_item("", 0, cap, Color(0.08, 0.07, 0.06), Color(0.2, 0.17, 0.13))
			tooltip_text = "%s: needs other carry gear" % InventoryState.point_name(point)
			return
		if it.is_empty():
			show_item("", 0, cap, Color(0.12, 0.11, 0.09), Color(0.62, 0.5, 0.3))
			tooltip_text = InventoryState.point_name(point)
		else:
			var n := int(it.get("count", 1)) if String(it.kind) != "tomahawk" else 1
			show_item(String(it.kind), n, cap, Color(0.24, 0.2, 0.14), Color(0.95, 0.78, 0.42))
			tooltip_text = "%s: %s (right-click to take off)" % [InventoryState.point_name(point), InventoryState.name_of(String(it.kind))]

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		if not offered or not (d is Dictionary) or String(d.get("from", "")) != "pack":
			return false
		var r := screen.inv.can_wear(String(d.kind), point)
		_sb.border_color = Color(0.45, 0.9, 0.4) if bool(r.ok) else Color(0.95, 0.35, 0.3)
		screen.say(("%s: %s" % [InventoryState.point_name(point), InventoryState.name_of(String(d.kind))]) if bool(r.ok) else String(r.reason), not bool(r.ok))
		return bool(r.ok)

	func _drop_data(_at: Vector2, d: Variant) -> void:
		screen.try_wear(String(d.kind), point)

	func _get_drag_data(_at: Vector2) -> Variant:
		if kind == "":
			return null
		set_drag_preview(drag_preview())
		return {"from": "body", "point": point}

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			screen.take_off(point)

