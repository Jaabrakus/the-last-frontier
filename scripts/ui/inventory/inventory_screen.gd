class_name InventoryScreen
extends CanvasLayer
## The character inventory (Tab; user 2026-09-25: "a Char inventory system with drag and drop with gear"; first
## cut of graph_analysis/inventory/inventory_design.md). The Gear tab, as the owner set it (2026-10-02: "no more rigs on
## the char slots"; the minecraft approach, Hotbar):
##   left      the pack: a list, a row an item (what is not on the hotbar: a weapon or a tool kept off the bar is here,
##             worn on the body or not), then the Spells list (every spell the caster has, those on the bar marked with
##             their slot) and the clothes carried. Drag a row onto a hotbar slot or onto the figure; right-click uses it
##             (food eaten, a herb or remedy applied, a torch, a drink or a pipe fill taken in hand); a double-click does
##             what dropping it on the figure does
##   middle    a live 3D copy of the character (SlingRig on Actor_B) wearing what is worn and carrying only what is on the
##             hotbar (as the body in play: SlingRig hides what is off the bar), and a DROP TARGET to use things ("drag
##             cloths ... food we can drag onto the body of the char screen"): a garment is worn in its slot (what was
##             there comes off into the pack; the figure redresses: ClothesSlots), food eaten (SurvivalBridge.eat), a
##             drink drunk, a gill (Vices), tobacco or the pipe smoked, a pipeful (Vices), a remedy or a herb applied
##             (Remedies, ForageUse), laudanum, snuff or a quid taken (Vices), rope gear put on, a weapon, a tool or a
##             spell put in the first free hotbar slot (body_verdict, body_drop). A drop it cannot use turns its frame
##             red and says why (the survival code's own reasons). There are no rig places to drop on any more
##   right     what the item pointed at (or clicked) is and does (ItemInfo)
##   bottom    the hotbar's nine slots (HotbarRow): drag between them, onto the pack to empty one; 1-9 over an item puts it
##             in that slot
## Tab or Done closes the screen and the player wears the result (FrontierPlayer.apply_loadout(): the pack eaten from,
## rope gear put on). The game is paused while it is open. The doll's rig and clips are Actor_B; weapon and gear models
## are the project's own.

const IDLE_CLIP := "actor_b-p-stealth-idle"

var player: Node
var inv: InventoryState
var _root: Control
var _msg: Label
var _view: SubViewport
var _view_box: SubViewportContainer
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
## The player's notice and prompt layer (PlayerInteractor's), hidden while the screen is open: under the backdrop its line
## would show through as ghost text (the screen has its own lines: say, figure_says).
var _hid_layer: CanvasLayer
## The character screen's tabs (user 2026-09-26: "the char screen the skills tab"): Gear (this inventory) and
## Skills (SkillsPanel); K opens the screen on Skills.
var start_tab := "gear"
var tab := ""
var _gear: VBoxContainer
var _skills: SkillsPanel
var _clothes: ClothesPanel
var _craft: CraftPanel
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
	var it: Variant = player.get("interactor") if player != null else null
	var lay: Variant = (it as Object).get("_layer") if it is Object else null
	if lay is CanvasLayer and (lay as CanvasLayer).visible:
		_hid_layer = lay
		_hid_layer.visible = false
	_build_ui()
	_build_doll()
	var hb := Hotbar.find(player)
	if hb != null:
		hb.changed.connect(_on_bar_changed)        # (the figure carries what is on the bar; the pack lists the rest)
	_refresh()
	show_tab(start_tab)


func close() -> void:
	if player and is_instance_valid(player) and player.has_method("apply_loadout"):
		player.apply_loadout(inv.worn, inv.pack)
		if _take_torch and player.get("torch") != null:
			(player.get("torch") as PlayerTorch).take_out()
	get_tree().paused = false
	Input.mouse_mode = _was_mouse if _was_mouse != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	_show_layer()
	queue_free()


func _show_layer() -> void:
	if _hid_layer != null and is_instance_valid(_hid_layer):
		_hid_layer.visible = true
	_hid_layer = null


func _exit_tree() -> void:
	_show_layer()


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
	elif event is InputEventKey and event.pressed and not event.echo and tab == "gear" and _number(event as InputEventKey) >= 0:
		get_viewport().set_input_as_handled()
		hotbar_key(_number(event as InputEventKey))     # (the item pointed at onto the hotbar: Hotbar)
	elif tab == "gear" and _shown.begins_with("spell:") and InputMap.has_action(SwayCaster.MODE_ACTION) \
			and event.is_action_pressed(SwayCaster.MODE_ACTION):
		get_viewport().set_input_as_handled()
		flip_mode(_shown.trim_prefix("spell:"))         # (the mode key here too: the spell pointed at or picked)


## The mode key over a spell (its card, its row): its next mode, as in play (SwayCaster.flip_mode); the rows and the card
## follow. "" when it has none.
func flip_mode(id: String) -> String:
	var c := SwayCaster.of(player)
	if c == null or SwayCaster.modes_of(id).is_empty():
		return ""
	var m := c.flip_mode(id)
	_refresh()
	return m


## 0..8 for the keys 1-9, -1 for any other.
static func _number(k: InputEventKey) -> int:
	var c := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	return int(c - KEY_1) if c >= KEY_1 and c <= KEY_9 else -1


const SKILLS_KEY := KEY_K


## Shows a tab: "gear", "skills" or "condition".
func show_tab(t: String) -> void:
	var was := tab
	tab = t if t in ["gear", "clothes", "craft", "skills", "condition"] else "gear"
	_gear.visible = tab == "gear"
	_clothes.visible = tab == "clothes"
	if tab == "clothes":
		_clothes.refresh()
	_craft.visible = tab == "craft"
	if tab == "craft":
		_craft.refresh()
	_skills.visible = tab == "skills"
	_condition.visible = tab == "condition"
	if tab == "condition":
		_condition.refresh()
	if tab == "gear" and was != "" and was != "gear":
		_refresh()                     # (the Clothes tab may have changed what is carried)
	for k: String in _tab_buttons:
		var b: Button = _tab_buttons[k]
		b.button_pressed = k == tab
		b.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45) if k == tab else Color(0.75, 0.7, 0.6))


# --- layout -------------------------------------------------------------------------------------

## The pack list's width, the figure's size, and the item detail's width.
const PACK_LIST_W := 300
const LIST_H := 444
const FIG_W := 300
const FIG_H := 444
const DETAIL_W := 330
const FIG_HINT := "Drag here to wear, eat or use"

var _pack_grid: VBoxContainer     ## the pack's rows (PackCell; the name is the grid's it replaced: tools read it)
var _list_box: VBoxContainer      ## the pack's rows, then the spells, then the clothes
var _spells_head: Label
var _spells_list: VBoxContainer
var _items_head: Label            ## "Items" over the pack's rows, shown when the spells are over them
var _cloth_head: Label
var _cloth_list: VBoxContainer
## The figure's drop target (FigureDrop) and the line under it.
var figure: FigureDrop
var fig_hint: Label
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
	for pair: Array in [["gear", "Gear  (Tab)"], ["clothes", "Clothes"], ["craft", "Craft"], ["skills", "Skills  (K)"], ["condition", "Condition"]]:
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
	_clothes = ClothesPanel.make(self)
	outer.add_child(_clothes)
	_craft = CraftPanel.make(self)
	outer.add_child(_craft)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_gear.add_child(row)
	# the pack: a list, the spells first (a spell granted is found at once: the story's "Tab: drag a spell to 1-9"), then a
	# row an item (its icon, name and count; user 2026-09-27: the wheelbarrow's rows "look better") and the clothes carried
	var pk := _panel("Pack", 0)
	row.add_child(pk)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PACK_LIST_W, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pk.get_child(0).add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 4)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box.mouse_filter = Control.MOUSE_FILTER_STOP
	# a hotbar slot dropped anywhere on the list comes off the bar (into the pack)
	_list_box.set_drag_forwarding(Callable(), _list_can_drop, _list_drop)
	scroll.add_child(_list_box)
	_spells_head = _label("Spells", 20, Color(0.93, 0.8, 0.52))
	_list_box.add_child(_spells_head)
	_spells_list = VBoxContainer.new()
	_spells_list.add_theme_constant_override("separation", 1)
	_spells_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_list_box.add_child(_spells_list)
	_items_head = _label("Items", 20, Color(0.93, 0.8, 0.52))
	_list_box.add_child(_items_head)
	_pack_grid = VBoxContainer.new()
	_pack_grid.add_theme_constant_override("separation", 1)
	_pack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pack_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_list_box.add_child(_pack_grid)
	_cloth_head = _label("Clothes", 20, Color(0.93, 0.8, 0.52))
	_list_box.add_child(_cloth_head)
	_cloth_list = VBoxContainer.new()
	_cloth_list.add_theme_constant_override("separation", 1)
	_cloth_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_list_box.add_child(_cloth_list)
	# the character in the middle: a drop target to wear, eat or use
	var eq := _panel("Character", 0)
	row.add_child(eq)
	var doll_box := Control.new()
	doll_box.custom_minimum_size = Vector2(FIG_W, FIG_H)
	eq.get_child(0).add_child(doll_box)
	_view_box = SubViewportContainer.new()
	_view_box.stretch = true
	_view_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll_box.add_child(_view_box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS     # (the Clothes tab shows the same figure)
	_view_box.add_child(_view)
	figure = FigureDrop.new()
	figure.name = "FigureDrop"
	figure.screen = self
	figure.set_anchors_preset(Control.PRESET_FULL_RECT)
	doll_box.add_child(figure)
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
	fig_hint = _label(FIG_HINT, 16, DIM)
	fig_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fig_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fig_hint.custom_minimum_size = Vector2(FIG_W, 0)
	eq.get_child(0).add_child(fig_hint)
	# what the item pointed at does
	var dp := _panel("Item", 0)
	row.add_child(dp)
	dp.get_child(0).add_child(_build_detail())
	# messages, Done
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	_gear.add_child(bottom)
	_msg = _label("Drag from the pack onto the hotbar to carry it, or onto the character to wear, eat or use it. Point at an item to see what it does.", 17, Color(0.9, 0.85, 0.75))
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(PACK_LIST_W + FIG_W + DETAIL_W, 0)
	bottom.add_child(_msg)
	var done := Button.new()
	done.text = "Done (Tab)"
	done.custom_minimum_size = Vector2(140, 40)
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(close)
	bottom.add_child(done)
	_hotbar_row = HotbarRow.make(self)                 # the hotbar's nine slots (Hotbar, HotbarRow)
	_gear.add_child(_hotbar_row)


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


## The mouse over an item (a pack row, a spell "spell:<id>"); "" when it leaves: back to the picked one.
func hover(kind: String) -> void:
	hovered = kind
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
	if kind.begins_with("spell:"):
		_show_spell(kind.trim_prefix("spell:"))
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


## A spell's card: its name and mode, its art, what it costs (moves.json; "free" with free use, SwayCaster.cost_of: the user,
## 2026-10-03, "lets make the spells free use right now"), its mastery (casts landed, the next tier) and its modes
## (SwayCaster: mode_of, the mode key), how it is used.
func _show_spell(id: String) -> void:
	var d := SwayMoves.move(id)
	var c := SwayCaster.of(player)
	_d_icon.texture = FrontierHUD.spell_texture(id, get_tree())
	_d_name.text = c.spell_label(id) if c != null else Hotbar.spell_label(id)
	_d_tag.text = ("SPELL  ·  " + String(d.get("art", "")).to_upper()).strip_edges()
	_d_text.text = "Drag it onto a hotbar slot; its number readies it, then hold the aim on the target until the ring fills and let go."
	var tm := c.tier_mult(id) if c != null else 1.0
	var reach := c.range_of(id) if c != null else float(d.get("range_m", 0.0))
	var rows: Array = [["Motes", "free" if SwayCaster.free_use() else str(SwayCaster.cost_of(id)), "good" if SwayCaster.free_use() else ""],
			["Lock", "%.1f s" % (float(d.get("lock_s", 1.0)) * tm), ""],
			["Reach", "%d m" % roundi(reach), ""]]
	var st: Dictionary = d.get("stone", {})
	if not st.is_empty():
		# Gust's other jobs: a stone held up and hurled (GustLift), the wind held in a sail
		var hd: Dictionary = st.get("hold", {})
		_d_text.text += "\n\nOn a stone (Stone Form's spike or cannonball, a ship's boulder, a loose rock) it is a hold: at the full lock the stone tears free and rises while you keep the aim, drawn like a bowstring; let go to hurl it along the aim (a spike flies like a lance, a ball rolls on). Held too long the hold breaks: it drops, you stagger%s. On a sail it keeps the wind in it while held." % ("" if SwayCaster.free_use() else ", the mote is lost")
		rows.append(["On a stone", "lock %.1f s, reach %d m, breaks after %.0f s; over %d kg it needs two" % [float(st.get("lock_s", 0.8)) * tm,
				roundi(float(st.get("range_m", 14.0))), float(hd.get("break_s", 5.0)), roundi(float(st.get("mass_kg", 90.0)))], "use"])
	if id == "stone_form":
		_d_text.text += "\n\nWhat it raises is a stone for Gust: lock Gust on the spike or the cannonball, hold, and hurl it."
	if c != null:
		var t := c.tier(id)
		var n := c.uses_of(id)
		var u := SwayCaster.tier_uses(id)
		var nxt := "" if t >= 2 else ", %s at %d" % [String(SwayCaster.TIERS[t + 1]), int(u[t + 1])]
		rows.append(["Mastery", "%s (%d cast%s%s)" % [c.tier_name(id), n, "" if n == 1 else "s", nxt], "good" if t >= 2 else ""])
		rows.append(["Hands", "both empty" if t < 2 else "the left; the right may hold a pistol, tomahawk or saber", ""])
		var ms := SwayCaster.modes_of(id)
		if not ms.is_empty():
			var now := c.mode_of(id)
			var names := PackedStringArray()
			for m: Variant in ms:
				var lb := SwayCaster.mode_label(id, String(m))
				names.append("[b]%s[/b]" % lb if String(m) == now else lb)
			rows.append(["Mode", "%s  (middle mouse; here too, over it)" % " / ".join(names), "use"])
	var b := "[table=2]"
	for r: Array in rows:
		b += "[cell][color=#a0968a]%s[/color][/cell][cell][color=%s]%s[/color][/cell]" % [r[0], TONES.get(r[2], TONES[""]), r[1]]
	_d_rows.text = b + "[/table]"


func _mark_picked() -> void:
	_fill_pack()


## The pack's rows: what the pack holds that is not on the hotbar, and the weapons and tools worn but kept off the bar
## (off the bar they are in the pack: Hotbar; the body carries only the bar's).
func pack_rows() -> Array[Dictionary]:
	var hb := Hotbar.find(player)
	var out: Array[Dictionary] = []
	var seen := {}
	for e: Dictionary in inv.pack:
		var k := String(e.get("kind", ""))
		if k == "" or (hb != null and _on_bar(hb, k)):
			continue
		out.append(e)
		seen[k] = true
	if hb != null:
		for it: Dictionary in inv.worn.items:
			var k := String(it.kind)
			if seen.has(k) or Hotbar.entry_for_kind(player, k).is_empty() or _on_bar(hb, k):
				continue
			out.append({"kind": k, "count": 1 if k == "tomahawk" else int(it.get("count", 1)), "state": it.get("state", {}), "worn": true})
			seen[k] = true
	return out


## Whether the pack kind `k` is on the hotbar (its weapon, its tool, or the tool it stands in for).
func _on_bar(hb: Hotbar, k: String) -> bool:
	var e := Hotbar.entry_for_kind(player, k)
	return not e.is_empty() and hb.slot_of(String(e.kind), String(e.id)) >= 0


var _rows: Array[Dictionary] = []


## The pack's rows, one a row of pack_rows() in its order (made as the pack grows, hidden when it shrinks).
func _fill_pack() -> void:
	_rows = pack_rows()
	while _pack_grid.get_child_count() < _rows.size():
		var c := PackCell.new()
		c.screen = self
		c.index = _pack_grid.get_child_count()
		_pack_grid.add_child(c)
	for c in _pack_grid.get_children():
		var pc := c as PackCell
		pc.set_entry(_rows[pc.index] if pc.index < _rows.size() else {})


## The spells the caster has (SwayCaster.known_spells), each a row to drag onto the bar: its name with its mode ("Stone
## Form (cannonball)"), its mastery at the right and under it its slot when it is on the bar ("practised / on 9"); its mode's mark on
## the picture (FrontierHUD.draw_mode_mark). Dragged onto a slot, that slot's key readies it.
func _fill_spells() -> void:
	for c in _spells_list.get_children():
		_spells_list.remove_child(c)
		c.queue_free()
	var c := SwayCaster.of(player)
	var known: Array = c.known_spells() if c != null else []
	_spells_head.visible = not known.is_empty()
	_items_head.visible = not known.is_empty()
	var hb := Hotbar.find(player)
	for e: Dictionary in known:
		var id := String(e.id)
		var at := hb.slot_of(Hotbar.SPELL, id) if hb != null else -1
		var r := ListRow.new()
		r.screen = self
		r.payload = {"from": "spell", "id": id}
		r.text = c.spell_label(id)
		r.side = ("%s\non %d" % [c.tier_name(id), at + 1]) if at >= 0 else c.tier_name(id)
		r.mode = c.mode_of(id)
		r.texture = FrontierHUD.spell_texture(id, get_tree())
		r.circle = r.texture == null
		_spells_list.add_child(r)


## The garments carried and not worn (the survival core's: ClothesSlots), each a row to drag onto the figure.
func _fill_clothes() -> void:
	for c in _cloth_list.get_children():
		_cloth_list.remove_child(c)
		c.queue_free()
	var br := _bridge()
	var n := 0
	if br != null and br.core != null:
		for z: String in ClothesSlots.zone_ids():
			for id: String in ClothesSlots.owned(br.core, z):
				if ClothesSlots.worn_in(br.core, z) == id:
					continue
				var r := ListRow.new()
				r.screen = self
				r.payload = {"from": "cloth", "id": id}
				r.text = ClothesSlots.name_of(br.core, id)
				r.side = ClothesSlots.zone_name(z)
				_cloth_list.add_child(r)
				n += 1
	_cloth_head.visible = n > 0


func _list_can_drop(_at: Vector2, d: Variant) -> bool:
	return d is Dictionary and String(d.get("from", "")) == "hotbar"


func _list_drop(_at: Vector2, d: Variant) -> void:
	if String(d.get("from", "")) == "hotbar":
		hotbar_off(int(d.slot))


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
	_redress()
	_poser = LoadoutClipPoser.new(_sk, _ap)
	_rig = SlingRig.new()
	_rig.name = "SlingRig"
	_doll.add_child(_rig)
	_rig.setup(_sk, _body, figure_loadout())
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_doll.add_child(_cam)
	_cam.current = true


## The doll dressed as the player looks now (PlayerAppearance: a garment put on in a start with nothing shows).
func _redress() -> void:
	var app = player.get("appearance") if player else null
	if _body and app is PlayerAppearance:
		PlayerAppearance.dress(_body, (app as PlayerAppearance).look)


## What the figure carries: the worn loadout less the weapons and tools kept off the hotbar (they are in the pack, and the
## body in play does not show them either: SlingRig, Hotbar).
func figure_loadout() -> Loadout:
	var hb := Hotbar.find(player)
	if hb == null:
		return inv.worn
	var lo := inv.worn.copy()
	for it: Dictionary in inv.worn.items:
		if not hb.on_body(String(it.kind)):
			lo.remove_item(String(it.id))
	return lo


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
	_fill_pack()
	_fill_spells()
	_fill_clothes()
	if _rig:
		_rig.set_loadout(figure_loadout())
	if _hotbar_row:
		_hotbar_row.refresh()
	if picked != "" and not _owns(picked):
		picked = ""
	_show_detail(_shown if _shown != "" and (_shown.begins_with("spell:") or _owns(_shown)) else picked)


var _bar_dirty := false


func _on_bar_changed() -> void:
	if _bar_dirty or not is_inside_tree():
		return
	_bar_dirty = true
	_refresh_bar.call_deferred()


func _refresh_bar() -> void:
	_bar_dirty = false
	if is_inside_tree():
		_refresh()


## In the pack or worn.
func _owns(kind: String) -> bool:
	if inv.pack_count(kind) > 0:
		return true
	for it: Dictionary in inv.worn.items:
		if String(it.kind) == kind:
			return true
	return false


var _icons_dirty := false


## An icon painted (ItemIcons.ready_icon, many in a row on the first open): one refresh a frame for them all.
func _refresh_icons() -> void:
	if _icons_dirty or not is_inside_tree():
		return
	_icons_dirty = true
	_refresh_icons_now.call_deferred()


func _refresh_icons_now() -> void:
	_icons_dirty = false
	if is_inside_tree():
		_refresh()
		if _d_icon and _shown != "" and _d_icon.texture == null and not _shown.begins_with("spell:"):
			_d_icon.texture = icons.get_icon(_shown)


func say(text: String, bad := false) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if bad else Color(0.9, 0.85, 0.75))


## The line under the figure: what a drag over it would do, or why not (red); "" back to the hint.
func figure_says(text: String, bad := false) -> void:
	if fig_hint == null:
		return
	fig_hint.text = text if text != "" else FIG_HINT
	fig_hint.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42) if bad else (Color(0.62, 0.86, 0.5) if text != "" else DIM))


func _bridge() -> SurvivalBridge:
	return SurvivalBridge.find(player.get_tree()) if player else null


func _vices() -> Vices:
	var br := _bridge()
	return br.vices if br else null


## Right-click on a pack row: food eaten from this screen's copy of the pack, a herb or a remedy applied, laudanum, snuff
## or a quid taken, a drink or a pipe fill taken in hand (U, Y), a torch into the left hand when the screen closes (push
## n01b: T in play does the same).
func use_item(kind: String) -> void:
	var br := _bridge()
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


# --- the figure: dropped on, worn, eaten or used -------------------------------------------------

static func _yes(what: String) -> Dictionary:
	return {"ok": true, "reason": what}


static func _no(why: String) -> Dictionary:
	return {"ok": false, "reason": why}


## What a drag dropped on the figure would do: {ok, reason} (`reason`: what it will do, or why it cannot). The drags: a pack
## row {from "pack", kind}, a garment carried {from "cloth", id}, a spell {from "spell", id}; a hotbar slot is on the bar.
func body_verdict(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return _no("")
	var p := d as Dictionary
	match String(p.get("from", "")):
		"pack":
			return _pack_verdict(String(p.get("kind", "")))
		"cloth":
			return _cloth_verdict(String(p.get("id", "")))
		"spell":
			var id := String(p.get("id", ""))
			return _bar_verdict(Hotbar.make(Hotbar.SPELL, id), Hotbar.spell_label(id))
		"hotbar":
			return _no("On the hotbar already")
	return _no("")


## Drops `d` on the figure: worn, eaten, drunk, smoked, applied or put on the hotbar. False (and why, in red) when it
## cannot be.
func body_drop(d: Variant) -> bool:
	var v := body_verdict(d)
	if not bool(v.ok):
		if String(v.reason) != "":
			say(String(v.reason), true)
		return false
	var p := d as Dictionary
	match String(p.get("from", "")):
		"pack":
			return use_on_body(String(p.kind))
		"cloth":
			return wear_cloth(String(p.id))
		"spell":
			return to_bar(Hotbar.make(Hotbar.SPELL, String(p.id))) >= 0
	return false


## A pack item used on the body (dropped on the figure, or double-clicked): rope gear put on, food eaten, a herb or remedy
## applied, a vice taken, a drink drunk (a gill), the pipe smoked (a pipeful), a torch taken in hand; a weapon or a tool
## into the first free hotbar slot.
func use_on_body(kind: String) -> bool:
	var v := _pack_verdict(kind)
	if not bool(v.ok):
		say(String(v.reason), true)
		return false
	var br := _bridge()
	if InventoryState.GEAR_KINDS.has(kind):
		# rope gear (a belt, a sling): put on
		var ok := inv.wear_gear(kind)
		say(("The %s is on." if ok else "The %s is on already.") % InventoryState.name_of(kind).to_lower(), not ok)
		_refresh()
		return ok
	if kind == InventoryState.TORCH or (br and br.can_eat(kind)) or ForageUse.can_use(kind) or Remedies.can_use(kind) \
			or Vices.can_use(kind):
		var before := inv.pack_count(kind)
		use_item(kind)
		return kind == InventoryState.TORCH or inv.pack_count(kind) < before
	if Vices.DRINKS.has(kind):
		return _drink(kind)
	if Vices.FILLS.has(kind) or kind == "clay_pipe":
		return _smoke(kind)
	var e := Hotbar.entry_for_kind(player, kind)
	if not e.is_empty():
		return to_bar(e) >= 0
	return false


func _pack_verdict(kind: String) -> Dictionary:
	if kind == "":
		return _no("")
	var nm := InventoryState.name_of(kind)
	var e := Hotbar.entry_for_kind(player, kind)
	if inv.pack_count(kind) <= 0 and (e.is_empty() or not _owns(kind)):
		return _no("No %s in the pack" % nm.to_lower())
	if InventoryState.GEAR_KINDS.has(kind):
		return _no("The %s is on already" % nm.to_lower()) if inv.gear_worn(kind) else _yes("Put the %s on" % nm.to_lower())
	if kind == InventoryState.TORCH:
		return _yes("A torch in your left hand, lit, when you close the pack")
	var br := _bridge()
	if br and br.can_eat(kind):
		var why := br.why_not(kind)
		return _no(why) if why != "" else _yes("Eat the %s" % nm.to_lower())
	if ForageUse.can_use(kind) or Remedies.can_use(kind):
		var why := _dressing_refusal(kind)
		return _no(why) if why != "" else _yes("Use the %s" % nm.to_lower())
	var vc := _vices()
	if Vices.can_use(kind):
		return _yes("Take the %s" % nm.to_lower()) if vc else _no("Not now")
	if Vices.DRINKS.has(kind) or Vices.FILLS.has(kind) or kind == "clay_pipe":
		var what := "drink" if Vices.DRINKS.has(kind) else "tobacco"
		var why := vc.why_not(what, inv) if vc else "."
		if why == ".":
			why = "Not now"
		return _no(why) if why != "" else _yes("Drink a gill of the %s" % nm.to_lower() if what == "drink" else "Smoke a pipeful")
	if not e.is_empty():
		return _bar_verdict(e, nm)
	return _no("The %s cannot be worn or used" % nm.to_lower())


## Why a herb or a remedy would do nothing now ("" when it would): the dressing's own rules (ForageUse.use, Remedies.use:
## a wound to dress, not one under a poultice already; the tonic needs the survival rules).
func _dressing_refusal(kind: String) -> String:
	if not (ForageUse.can_use(kind) or kind == "plantain_salve"):
		var br := _bridge()
		return "Nothing comes of it now" if kind == "ginseng_tonic" and (br == null or br.core == null) else ""
	var hurt := float(player.get("health")) < float(player.get("max_health")) - 0.5
	var w: Variant = player.get("wounds")
	var bleeding: bool = w is PlayerWounds and (w as PlayerWounds).bleeding()
	if not hurt and not bleeding:
		return "You have no wound to dress"
	if player.get_node_or_null("Poultice") != null and not bleeding:
		return "A poultice is on the wound already"
	return ""


func _cloth_verdict(id: String) -> Dictionary:
	var br := _bridge()
	if br == null or br.core == null:
		return _no("Not now")
	var zone := ClothesSlots.zone_of(br.core, id)
	if zone == "":
		return _no("That is not something to wear")
	var nm := ClothesSlots.name_of(br.core, id)
	if ClothesSlots.worn_in(br.core, zone) == id:
		return _no("The %s is worn already" % nm.to_lower())
	if not ClothesSlots.owned(br.core, zone).has(id):
		return _no("You have no %s to put on" % nm.to_lower())
	return _yes("Wear the %s (%s)" % [nm.to_lower(), ClothesSlots.zone_name(zone).to_lower()])


func _bar_verdict(e: Dictionary, nm: String) -> Dictionary:
	var hb := Hotbar.find(player)
	if hb == null:
		return _no("No hotbar")
	var at := hb.slot_of(String(e.kind), String(e.id))
	if at >= 0:
		return _no("The %s is on the hotbar already: %d" % [nm.to_lower(), at + 1])
	if not hb.has_thing(e):
		return _no("You do not have the %s" % nm.to_lower())
	var free := hb.first_free()
	if free < 0:
		return _no("No free slot on the hotbar: drag it onto a slot to swap")
	return _yes("Onto the hotbar: %d" % (free + 1))


## A garment carried put on in its slot (what was there comes off into the pack); the figure redresses (ClothesSlots).
func wear_cloth(id: String) -> bool:
	var br := _bridge()
	if br == null or br.core == null:
		return false
	var zone := ClothesSlots.zone_of(br.core, id)
	var there := ClothesSlots.worn_in(br.core, zone)
	var ok := ClothesSlots.wear(br, id)
	if ok:
		say("%s on.%s" % [ClothesSlots.name_of(br.core, id),
				(" The %s into the pack." % ClothesSlots.name_of(br.core, there).to_lower()) if there != "" and there != id else ""])
	else:
		say("The %s will not go on." % ClothesSlots.name_of(br.core, id).to_lower(), true)
	_redress()
	_refresh()
	return ok


## A gill of `kind` drunk (Vices.take: the bottle open is finished first; it soaks in over the next hour).
func _drink(kind: String) -> bool:
	var vc := _vices()
	if vc == null:
		return false
	vc.choose(kind)
	if vc.take("drink", 1.0, inv) <= 0.0:
		say(vc.why_not("drink", inv), true)
		return false
	say("You drink a gill of %s." % InventoryState.name_of(String(vc._st().get("flask_kind", kind))).to_lower())
	_refresh()
	return true


## A pipeful smoked (Vices.take): of `kind` when it is a fill, else of what the pipe is packed with next.
func _smoke(kind: String) -> bool:
	var vc := _vices()
	if vc == null:
		return false
	if Vices.FILLS.has(kind):
		vc.choose(kind)
	if vc.take("tobacco", 1.0, inv) <= 0.0:
		say(vc.why_not("tobacco", inv), true)
		return false
	say("You smoke a pipeful of %s." % InventoryState.name_of(String(vc._st().get("bowl_kind", kind))).to_lower())
	_refresh()
	return true


# --- the hotbar (Hotbar, HotbarRow) -------------------------------------------------------------

var hovered := ""                   ## the item kind under the pointer ("spell:<id>" a spell; "" none)
var hovered_slot := -1              ## the hotbar slot under the pointer (-1 none)
var _hotbar_row: HotbarRow


## 1-9 on the Gear tab (`i` from 0): the item pointed at goes in that hotbar slot; a hotbar slot pointed at swaps with it.
func hotbar_key(i: int) -> void:
	var hb := Hotbar.find(player)
	if hb == null:
		return
	if hovered_slot >= 0:
		hb.swap(hovered_slot, i)
		say("Hotbar slots %d and %d swapped." % [hovered_slot + 1, i + 1])
		hovered_slot = i                 # (the pointer is on the slot the thing left: it shows what came there)
	elif hovered.begins_with("spell:"):
		var id := hovered.trim_prefix("spell:")
		hotbar_put_entry(Hotbar.make(Hotbar.SPELL, id), i, Hotbar.spell_label(id))
	elif hovered != "":
		hotbar_put(hovered, i)
	else:
		say("Point at a weapon, a tool or a spell, then press 1-9 to put it on the hotbar.")
	if _hotbar_row:
		_hotbar_row.refresh()


## Puts the item `kind` (the inventory's kind) in hotbar slot `i` (the one there goes off the bar into the pack; one
## already on the bar swaps places with it).
func hotbar_put(kind: String, i: int) -> void:
	if Hotbar.find(player) == null or kind == "":
		return
	var e := Hotbar.entry_for_kind(player, kind)
	if e.is_empty():
		say("The %s does not go on the hotbar." % InventoryState.name_of(kind).to_lower(), true)
		return
	hotbar_put_entry(e, i, InventoryState.name_of(kind))


## Puts the hotbar entry `e` ({kind, id}; `nm` its name) in slot `i`.
func hotbar_put_entry(e: Dictionary, i: int, nm: String) -> void:
	var hb := Hotbar.find(player)
	if hb == null:
		return
	var was := hb.entry(i)
	var was_name := hb.label(i)
	if not hb.assign(i, e):
		say("You do not have the %s." % nm.to_lower(), true)
		return
	var off := not was.is_empty() and hb.slot_of(String(was.kind), String(was.id)) < 0
	say("%s on the hotbar: %d.%s" % [nm, i + 1, (" The %s goes into the pack." % was_name.to_lower()) if off else ""])
	_refresh()


## Puts `e` in the first free hotbar slot (dropped on the figure, double-clicked): the slot, -1 when none.
func to_bar(e: Dictionary) -> int:
	var hb := Hotbar.find(player)
	if hb == null:
		return -1
	var i := hb.add(e)
	if i >= 0:
		say("%s on the hotbar: %d." % [hb.label(i), i + 1])
	else:
		say("No free slot on the hotbar: drag it onto a slot to swap.", true)
	_refresh()
	return i


## Hotbar slot `i` emptied: its thing stays in the pack, off the bar (not drawn, not on the body).
func hotbar_off(i: int) -> void:
	var hb := Hotbar.find(player)
	if hb == null or not hb.filled(i):
		return
	var nm := hb.label(i)
	hb.clear(i)
	say("%s off the hotbar: in the pack." % nm)
	_refresh()


## The inventory kind a drag carries (a pack row; "" otherwise).
func drag_kind(d: Variant) -> String:
	if not (d is Dictionary):
		return ""
	if String((d as Dictionary).get("from", "")) == "pack":
		return String(d.get("kind", ""))
	return ""


## The hotbar entry a drag carries: a pack row's weapon or tool, a spell; {} for anything else.
func drag_entry(d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var p := d as Dictionary
	if String(p.get("from", "")) == "spell":
		return Hotbar.make(Hotbar.SPELL, String(p.get("id", "")))
	var k := drag_kind(d)
	return Hotbar.entry_for_kind(player, k) if k != "" else {}


# --- drag and drop widgets ----------------------------------------------------------------------

## The figure's drop target over the 3D view: what is dropped on it is worn, eaten or used (body_verdict, body_drop). Its
## frame shows green over a drag it takes, red over one it does not (the reason under it).
class FigureDrop extends Panel:
	var screen: InventoryScreen
	## "", "ok" or "no": the frame now.
	var state := ""
	var _sb: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_sb = StyleBoxFlat.new()
		_sb.set_border_width_all(3)
		_sb.set_corner_radius_all(6)
		add_theme_stylebox_override("panel", _sb)
		show_state("")

	func show_state(s: String) -> void:
		state = s
		if _sb == null:
			return
		match s:
			"ok":
				_sb.border_color = Color(0.5, 0.88, 0.42, 0.95)
				_sb.bg_color = Color(0.4, 0.8, 0.3, 0.08)
			"no":
				_sb.border_color = Color(0.95, 0.34, 0.28, 0.95)
				_sb.bg_color = Color(0.9, 0.2, 0.15, 0.12)
			_:
				_sb.border_color = Color(0.5, 0.4, 0.26, 0.35)
				_sb.bg_color = Color(0, 0, 0, 0)

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		var v := screen.body_verdict(d)
		show_state("ok" if bool(v.ok) else "no")
		screen.figure_says(String(v.reason), not bool(v.ok))
		return bool(v.ok)

	func _drop_data(_at: Vector2, d: Variant) -> void:
		show_state("")
		screen.figure_says("")
		screen.body_drop(d)

	func _notification(what: int) -> void:
		if (what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT) and state != "":
			show_state("")
			screen.figure_says("")


## A row of the pack's list (user 2026-09-27: the wheelbarrow screen's rows "look better" than the grid of squares):
## the item's icon, its name and how many, no box; the pointer over it a faint wash, the picked one a gold rule at its
## left. Dragged onto a hotbar slot it goes on the bar, onto the figure it is worn or used; a hotbar slot dropped on it
## comes off the bar; right-click uses it (food, a herb, a torch), a double-click does what the figure would, a click
## picks it (its stats stay beside the list).
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
		return screen._list_can_drop(_at, d)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed or kind == "":
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			screen.use_item(kind)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			screen.use_on_body(kind)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			screen.pick("" if screen.picked == kind else kind)

	func _drop_data(_at: Vector2, d: Variant) -> void:
		screen._list_drop(_at, d)


## A row of the Spells list or the clothes carried: its picture (a spell with none: its circle, FrontierHUD
## .draw_spell_circle), its name, a word at the right; dragged onto a hotbar slot or the figure (`payload`), a double-click
## does what the figure would.
class ListRow extends PanelContainer:
	var screen: InventoryScreen
	var payload := {}
	var text := ""
	var side := ""
	var texture: Texture2D
	var circle := false
	var mode := ""                ## a spell's mode: its mark in the picture's corner ("" none)
	var _sb: StyleBoxFlat
	var _icon: TextureRect

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 40)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_sb = StyleBoxFlat.new()
		_sb.bg_color = Color(0, 0, 0, 0)
		_sb.content_margin_left = 11
		_sb.content_margin_right = 10
		_sb.set_corner_radius_all(2)
		add_theme_stylebox_override("panel", _sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		_icon = TextureRect.new()
		_icon.custom_minimum_size = Vector2(34, 34)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.texture = texture
		_icon.visible = texture != null or circle or String(payload.get("from", "")) == "spell"
		if circle:
			_icon.draw.connect(func() -> void: FrontierHUD.draw_spell_circle(_icon, Rect2(Vector2.ZERO, _icon.size)))
		if mode != "":
			_icon.draw.connect(func() -> void: FrontierHUD.draw_mode_mark(_icon, Rect2(Vector2(_icon.size.x - 13, -2), Vector2(14, 14)), mode))
		h.add_child(_icon)
		var spell := String(payload.get("from", "")) == "spell"
		# (a spell's name carries its mode, "Stone Form (cannonball)": a size smaller, so it fits beside its slot and mastery)
		var nm := InventoryScreen._label(text, 15 if spell else 17, Color(0.93, 0.88, 0.76))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(nm)
		var sd := InventoryScreen._label(side, 13 if spell else 14, Color(0.72, 0.66, 0.55))
		sd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if spell:
			sd.add_theme_constant_override("line_spacing", -3)
		sd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sd)
		tooltip_text = text

	func _notification(what: int) -> void:
		if _sb == null or screen == null:
			return
		if what == NOTIFICATION_MOUSE_ENTER:
			_sb.bg_color = Color(1, 0.95, 0.85, 0.05)
			if String(payload.get("from", "")) == "spell":
				screen.hover("spell:" + String(payload.get("id", "")))
		elif what == NOTIFICATION_MOUSE_EXIT:
			_sb.bg_color = Color(0, 0, 0, 0)
			screen.hover("")

	func _get_drag_data(_at: Vector2) -> Variant:
		var pv: Control
		if texture != null:
			var t := TextureRect.new()
			t.texture = texture
			t.size = Vector2(56, 56)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pv = t
		else:
			pv = InventoryScreen._label(text, 16, Color(1, 0.9, 0.6))
		set_drag_preview(pv)
		return payload.duplicate()

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		return screen._list_can_drop(_at, d)

	func _drop_data(_at: Vector2, d: Variant) -> void:
		screen._list_drop(_at, d)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			screen.body_drop(payload)
