class_name InventoryScreen
extends CanvasLayer
## The character inventory (Tab; user 2026-09-25: "a Char inventory system with drag and drop with gear"; first
## cut of graph_analysis/inventory/inventory_design.md). The Gear tab, as the owner set it (2026-10-02: "no more rigs on
## the char slots"; the minecraft approach, Hotbar):
##   left      the Spells list (every spell the caster has, those on the bar marked with their slot), then the pack as
##             its bags (the owner 2026-10-03, "WoW-style bags": PlayerBags, the same grids as the HUD's bag windows,
##             BagGrid): every worn bag in one scrolling column, the haversack first, the Loose strip under them (what is
##             not on the hotbar: a weapon or a tool kept off the bar is in a bag, worn on the body or not), then the
##             clothes carried. Drag a stack onto a hotbar slot or onto the figure, between slots and bags (move, swap,
##             merge; a specialty bag refuses with its reason), a bag's picture into a slot to take it off; right-click
##             uses it (food eaten, a herb or remedy applied, a torch, a drink or a pipe fill taken in hand; a bag put on,
##             a garment worn); a double-click does what dropping it on the figure does; shift-click splits a stack
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
## rope gear put on). The pack (`inv`, this screen's copy) is written back to the player at every change too, so the bags
## lay it out as it is (they follow the player's pack: PlayerBags.sync); what the bags change (a bag put on or taken off)
## comes into `inv` the same way (_follow_bags). The game is paused while it is open. The doll's rig and clips are Actor_B; weapon and gear models
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

var _pack_grid: VBoxContainer     ## the pack's bags (BagGrid, its slots PackCell; the name is the grid's it replaced: tools read it)
var _list_box: VBoxContainer      ## the pack's rows, then the spells, then the clothes
var _spells_head: Label
var _spells_list: VBoxContainer
var _items_head: Label            ## "Bags" over the pack's bags, shown when the spells are over them
var _grids := {}                  ## bag b (BagSlot.LOOSE the loose) -> its BagGrid
var split_box: BagUI.SplitBox
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
	_items_head = _label("Bags", 20, Color(0.93, 0.8, 0.52))
	_list_box.add_child(_items_head)
	_pack_grid = VBoxContainer.new()
	_pack_grid.add_theme_constant_override("separation", 6)
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
	split_box = BagUI.SplitBox.new()                   # shift-click on a stack (over everything)
	split_box.theme = ClassicSkin.theme()
	_root.add_child(split_box)


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
	if kind.begins_with(BagUI.CLOTH):
		# a garment carried, in a bag (its rows: BagUI.tip)
		var g := _bags()
		var t := BagUI.tip(player, g, kind, 1) if g != null else {"name": kind, "tag": "", "rows": []}
		_d_icon.texture = null
		_d_name.text = String(t.name)
		_d_tag.text = String(t.tag).to_upper()
		_d_text.text = "Drag it onto the figure to wear it, or right-click it."
		var bb := "[table=2]"
		for r: Array in t.rows:
			bb += "[cell][color=#a0968a]%s[/color][/cell][cell][color=%s]%s[/color][/cell]" % [r[0], TONES.get(r[2], TONES[""]), r[1]]
		_d_rows.text = bb + "[/table]"
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


## A spell's card: its name and mode, its art, what it costs (moves.json), its mastery (casts landed, the next tier) and its
## modes (SwayCaster: mode_of, the mode key), how it is used.
func _show_spell(id: String) -> void:
	var d := SwayMoves.move(id)
	var c := SwayCaster.of(player)
	_d_icon.texture = FrontierHUD.spell_texture(id, get_tree())
	_d_name.text = c.spell_label(id) if c != null else Hotbar.spell_label(id)
	_d_tag.text = ("SPELL  ·  " + String(d.get("art", "")).to_upper()).strip_edges()
	_d_text.text = "Drag it onto a hotbar slot; its number readies it, then hold the aim on the target until the ring fills and let go."
	var tm := c.tier_mult(id) if c != null else 1.0
	var reach := c.range_of(id) if c != null else float(d.get("range_m", 0.0))
	var rows: Array = [["Motes", str(int(d.get("motes", 0))), ""],
			["Lock", "%.1f s" % (float(d.get("lock_s", 1.0)) * tm), ""],
			["Reach", "%d m" % roundi(reach), ""]]
	var st: Dictionary = d.get("stone", {})
	if not st.is_empty():
		# Gust's other jobs: a stone held up and hurled (GustLift), the wind held in a sail
		var hd: Dictionary = st.get("hold", {})
		_d_text.text += "\n\nOn a stone (Stone Form's spike or cannonball, a ship's boulder, a loose rock) it is a hold: at the full lock the stone tears free and rises while you keep the aim, drawn like a bowstring; let go to hurl it along the aim (a spike flies like a lance, a ball rolls on). Held too long the hold breaks: it drops, you stagger, the mote is lost. On a sail it keeps the wind in it while held."
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


## The pack's bags (PlayerBags): a grid a worn bag, the haversack first, the Loose strip under them while anything rides
## loose (BagGrid; its slots PackCell). The screen's pack is written to the player first, so the bags lay out what this
## screen holds (_push_pack).
func _fill_pack() -> void:
	_rows = pack_rows()
	var g := _push_pack()
	if g == null:
		return
	var icon_of := func(k: String) -> Texture2D: return slot_icon(k)
	var order: Array[int] = [0, 1, 2, 3, 4, BagSlot.LOOSE]
	var at := 0
	for b in order:
		var want := g.loose_slots() > 0 if b == BagSlot.LOOSE else g.bag_kind(b) != ""
		var w: BagGrid = _grids.get(b)
		if want and w == null:
			w = BagGrid.new()
			w.name = "Loose" if b == BagSlot.LOOSE else "Bag%d" % b
			w.host = self
			w.bag = b
			w.slot_px = BagUI.SLOT_TAB
			w.closable = false
			w.make_slot = func() -> BagSlot: return PackCell.new()
			w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_pack_grid.add_child(w)
			_grids[b] = w
		if w == null:
			continue
		_pack_grid.move_child(w, at)
		at += 1
		w.visible = want
		if want:
			w.refresh(g, icon_of)
			for c: BagSlot in w.slots:
				c.set_picked(picked != "" and c.kind == picked)


## The screen's pack written to the player (the bags follow the player's pack) and the bags laid out from it now (the game
## is paused under the screen: PlayerBags.sync by hand). The player's bags; null none.
func _push_pack() -> PlayerBags:
	if player == null or not is_instance_valid(player):
		return null
	player.set("inventory_pack", inv.pack.duplicate(true))
	var g := PlayerBags.find(player)
	if g != null:
		g.sync()
	return g


## The bags changed the player's pack under the screen (a bag put on or taken off): the same change into `inv` (each kind's
## count as the player's now; the weapons' kinds and the torches are worked out, not kept: InventoryState.from_player).
func _follow_bags() -> void:
	var live := _counts(player.get("inventory_pack") if player.get("inventory_pack") != null else [])
	var mine := _counts(inv.pack)
	for k: String in live.keys() + mine.keys():
		var d := int(live.get(k, 0)) - int(mine.get(k, 0))
		if d > 0:
			inv.add(k, d)
		elif d < 0:
			inv.take(k, -d)
		mine[k] = int(live.get(k, 0))


static func _counts(pack: Array) -> Dictionary:
	var out := {}
	for e: Variant in pack:
		if not (e is Dictionary):
			continue
		var k := String((e as Dictionary).get("kind", ""))
		if k == "" or k == InventoryState.TORCH or InventoryState._derived(k):
			continue
		out[k] = int(out.get(k, 0)) + int((e as Dictionary).get("count", 0))
	return out


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
	return ItemUse.owns(inv, kind)


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
	# food eaten from this screen's copy of the pack, a herb or a remedy applied, a vice taken, a drink or a pipe fill
	# chosen (ItemUse.use)
	var r := ItemUse.use(player, inv, kind)
	if bool(r.done):
		say(String(r.text), not bool(r.ok))
		if bool(r.refresh):
			_refresh()
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
	if PlayerBags.is_bag(kind):
		return equip_bag(kind)
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


## What a pack item dropped on the figure would do (ItemUse.verdict: the rules the bags' right-click keeps too).
func _pack_verdict(kind: String) -> Dictionary:
	return ItemUse.verdict(player, inv, kind)


## Why a herb or a remedy would do nothing now ("" when it would): ItemUse.dressing_refusal.
func _dressing_refusal(kind: String) -> String:
	return ItemUse.dressing_refusal(player, kind)


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
	return ItemUse.bar_verdict(player, e, nm)


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
	var r := ItemUse.drink(player, inv, kind)
	if String(r.text) != "":
		say(String(r.text), not bool(r.ok))
	if bool(r.ok):
		_refresh()
	return bool(r.ok)


## A pipeful smoked (Vices.take): of `kind` when it is a fill, else of what the pipe is packed with next.
func _smoke(kind: String) -> bool:
	var r := ItemUse.smoke(player, inv, kind)
	if String(r.text) != "":
		say(String(r.text), not bool(r.ok))
	if bool(r.ok):
		_refresh()
	return bool(r.ok)


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


# --- the bags (BagSlot's and BagGrid's host; PlayerBags) ----------------------------------------

func _bags() -> PlayerBags:
	return PlayerBags.find(player) if player != null and is_instance_valid(player) else null


## A slot's or a bag's picture (a garment carried has none: its mark is drawn).
func slot_icon(k: String) -> Texture2D:
	return icons.get_icon(k) if icons != null and k != "" and not k.begins_with(BagUI.CLOTH) else null


func slot_hover(c: BagSlot, on: bool) -> void:
	hover(c.kind if on and c.kind != "" else "")


func slot_click(c: BagSlot) -> void:
	if c.kind != "":
		pick("" if picked == c.kind else c.kind)


func slot_double_click(c: BagSlot) -> void:
	_use_stack(c, true)


func slot_right_click(c: BagSlot) -> void:
	_use_stack(c, false)


## A right-click (`body` false) or a double-click on a stack: a bag put on, a garment worn, else use_item / use_on_body.
func _use_stack(c: BagSlot, body: bool) -> void:
	var k := c.kind
	if k == "":
		return
	if PlayerBags.is_bag(k):
		equip_bag(k, -1, c.bag if c.bag != BagSlot.LOOSE else -1, c.index if c.bag != BagSlot.LOOSE else -1)
	elif k.begins_with(BagUI.CLOTH):
		wear_cloth(k.trim_prefix(BagUI.CLOTH))
	elif body:
		use_on_body(k)
	else:
		use_item(k)


func slot_shift_click(c: BagSlot) -> void:
	var g := _bags()
	if g == null or c.bag == BagSlot.LOOSE or c.count < 2:
		return
	var b := c.bag
	var i := c.index
	var k := c.kind
	split_box.open_for(c.get_global_rect().position + Vector2(c.size.x + 8.0, 0.0), c.count, g.kind_name(k), func(n: int) -> void:
		var gg := _bags()
		if gg == null or String(gg.slot(b, i).get("kind", "")) != k:
			return
		var r := gg.split(b, i, n)
		if not bool(r.ok):
			say(String(r.reason), true)
		_refresh())


func slot_drag(c: BagSlot) -> Variant:
	var g := _bags()
	if g == null:
		return null
	return BagUI.loose_payload(g, c.index) if c.bag == BagSlot.LOOSE else BagUI.slot_payload(g, c.bag, c.index)


func slot_drop_check(c: BagSlot, d: Variant) -> Dictionary:
	var g := _bags()
	if g == null:
		return _no("")
	if c.bag == BagSlot.LOOSE:
		return _yes("") if c._is_self(d) else _no("Into a bag, not onto the loose things")
	return BagUI.verdict_slot(player, g, c.bag, c.index, d)


func slot_drop(c: BagSlot, d: Variant) -> void:
	var g := _bags()
	if g == null:
		return
	if c.bag == BagSlot.LOOSE:
		if not c._is_self(d):
			say("Into a bag, not onto the loose things", true)
		return
	_bag_done(BagUI.drop_slot(player, g, c.bag, c.index, d))


func grid_close(_w: BagGrid) -> void:
	pass


func grid_drag(w: BagGrid) -> Variant:
	var g := _bags()
	return BagUI.socket_payload(g, w.bag - 1) if g != null and w.bag >= 1 else null


func grid_drop_check(w: BagGrid, d: Variant) -> Dictionary:
	var g := _bags()
	return BagUI.verdict_into(player, g, w.bag, d) if g != null else _no("")


func grid_drop(w: BagGrid, d: Variant) -> void:
	var g := _bags()
	if g != null:
		_bag_done(BagUI.drop_into(player, g, w.bag, d))


## A bag from the pack put on (PlayerBags.equip: `socket`, -1 the first empty one; from slot (from_b, from_i) when given).
func equip_bag(kind: String, socket := -1, from_b := -1, from_i := -1) -> bool:
	var g := _push_pack()
	if g == null:
		return false
	var r := g.equip(kind, socket, from_b, from_i)
	_bag_done({"ok": bool(r.ok), "reason": ("The %s is on: bag %d." % [InventoryState.name_of(kind).to_lower(), int(r.socket) + 1])
			if bool(r.ok) else String(r.reason)})
	return bool(r.ok)


## After a change the bags made: the screen's pack follows the player's (_follow_bags), the result said (a refusal in red).
func _bag_done(r: Dictionary) -> void:
	_follow_bags()
	if String(r.get("reason", "")) != "":
		say(String(r.reason), not bool(r.get("ok", false)))
	_refresh()


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


## A slot of the pack's bags (the owner 2026-10-03, "WoW-style bags": BagSlot, in the bags' grids, BagGrid; before them
## a row of a list): dragged onto a hotbar slot it goes on the bar, onto the figure it is worn or used, onto another slot
## or bag it moves; a hotbar slot dropped on it comes off the bar into it; right-click uses it (food, a herb, a torch; a
## bag put on, a garment worn), a double-click does what the figure would, a click picks it (its stats stay beside the
## list), shift-click splits it. The screen is its host (slot_* below).
class PackCell extends BagSlot:
	pass


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
