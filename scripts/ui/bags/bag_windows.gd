class_name BagWindows
extends CanvasLayer
## The bag windows in play (the owner 2026-10-03: "can we do the inventory similar to world of warcraft with the bags and
## etc?", then "WoW-style bags ... i just need you to do these"), on both HUD styles (FrontierHUD; classic and minimal):
## each worn bag (PlayerBags) its own small classic window (BagGrid: the leather and brass of ClassicSkin, the bag's
## picture and name in the title, a close button, its slots 4 wide), stacked upward from above the bag bar on the bottom
## right, the haversack lowest and the Loose strip under it while anything rides loose; a column full, the next one left.
##   opening   M toggles all the bags (ACTION "bags", rebindable; B is build mode, BuildMode: M is the nearest free key, in
##             the F1 controls); a bag-bar socket toggles its bag, the pack button the haversack (ClassicBagBar); Escape
##             closes the open bags first (the split box and the drop question before them); Tab still opens the character
##             screen. Not while dead, in the command mode or a talk; not in the middle of a shot, a draw or a cast (fire
##             or a spell's aim held: "Let the shot down first")
##   in play   the game runs on and the cursor is free while a bag is open; the camera does not turn, and no attack, aim,
##             cast or fire comes of a click (the owner has seen muskets go off by themselves): the hands' actions (HANDS:
##             fire, aim, the club grip, the spell's mode) lose their bindings while a bag is open (kept and given back on
##             closing, and while the game is paused under a screen), so a click is no press of them at all, not even a
##             "just pressed" a frame long (the Input singleton sees every click, the GUI's too: letting go of the action
##             is not enough, the melee's reverse attack and the musket read the press); a click on the world is the
##             WorldDrop's (no capture). Walking still works. A screen that captured the mouse closing over open bags (the
##             Tab screen, the pause menu): freed again. All closed: captured again (if it was)
##   the mouse drag between slots and bags (move, swap, merge; a specialty bag refuses with its reason in red: BagUI),
##             onto the action bar or a bag-bar socket (a bag item is put on there), the title's picture into a slot (the
##             bag taken off: "Empty the bag first" unless empty), out of every window onto the world ("Drop 12
##             Venison?", then it lies there: DroppedItem); right-click uses it (BagUI.use_stack: eat, apply, drink, smoke,
##             wear, put a bag on); shift-click splits a stack (BagUI.SplitBox); the pointer resting on a stack, its
##             tooltip (a classic tooltip box: the name, then ItemInfo's rows; a bag's slots and what it holds)
##   lines     what was done goes to the interactor's notice (the classic HUD's chat log writes it); a refusal in red over
##             the middle of the screen (ERROR_S)
##   BagWindows.install(hud)   FrontierHUD._ready (the player's HUD); BagWindows.of(hud)
## The public calls (the tests' and the bag bar's): toggle_all(), open_bag(b), close_bag(b), toggle_bag(b), close_all(),
## any_open(), is_open(b), window(b), loose_window(), slot_ctrl(b, i), payload(b, i), loose_payload(li), drop_on_slot(d, b, i),
## drop_on_bag(d, b), drop_on_socket(d, s), drop_on_bar(d, slot), drop_on_world(d) (asks), confirm_drop(), keep(),
## use_slot(b, i), split_slot(b, i) (then split_box.confirm()), blocks_input(), error_text.

const ACTION := &"bags"
const KEY := KEY_M
const NODE_NAME := "BagWindows"
## Over the HUD (1), the prompts and the story's hints (5) and the death line (6); under the command mode's HUD (8), the
## controls help (12) and the screens (20 and up).
const LAYER := 7
## The hands' actions: unbound while a bag is open (_hands_off), so no click presses them.
const HANDS := [&"fire", &"aim", &"club_grip", &"sway_mode"]
const MARGIN := 14.0
## px from the screen's foot to the windows' (over the bag bar and the micro menu; over the minimal HUD's slot strip).
const FOOT := 100.0
const WIN_GAP := 6.0
const COL_GAP := 8.0
const TIP_DELAY := 0.3
const ERROR_S := 2.6

var hud: FrontierHUD
var player: FrontierPlayer
## The panel everything is in (this layer's).
var root: Control
## Bag b (0 the haversack, 1-4 the sockets) -> its window, made when first opened.
var windows := {}
var loose_win: BagGrid
## The world under the windows: a drop there is a drop on the ground; a click there does nothing (FrontierHUD's root, under
## its frames).
var world: WorldDrop
var tip: TipBox
var split_box: BagUI.SplitBox
var ask: AskBox
## The red line now ("" none) and its time left.
var error_text := ""
var _error_t := 0.0
var _err: Control
## Which bags are open (0-4).
var open: Array[bool] = [false, false, false, false, false]
var _mode := false                  ## a bag open: the cursor ours
var _was_captured := false
## action -> its bindings, kept while a bag is open (HANDS; _hands_off).
var _stash := {}
var _dirty := false
var _tip_slot: BagSlot
var _tip_t := 0.0
var _pending := {}                  ## the drag the drop question is about
var _hooked: PlayerBags
var _icons: ItemIcons


static func install(h: FrontierHUD) -> BagWindows:
	var have := of(h)
	if have != null:
		return have
	ensure_input()
	var w := BagWindows.new()
	w.name = NODE_NAME
	w.hud = h
	w.player = h.player
	h.add_child(w)
	return w


static func of(h: Node) -> BagWindows:
	return h.get_node_or_null(NODE_NAME) as BagWindows if h != null else null


## The player's (through its HUD).
static func for_player(p: Node) -> BagWindows:
	var h: Variant = p.get("hud") if p != null and is_instance_valid(p) else null
	return of(h as Node) if h is Node else null


## ACTION on KEY, made when missing (the player may rebind it). Safe to call again.
static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY
	InputMap.action_add_event(ACTION, e)


## The bound key's name ("M"; "?" unbound).
static func key_label() -> String:
	if not InputMap.has_action(ACTION):
		return "?"
	for e in InputMap.action_get_events(ACTION):
		if e is InputEventKey:
			var k := (e as InputEventKey).physical_keycode
			return OS.get_keycode_string(k if k != KEY_NONE else (e as InputEventKey).keycode)
	return "?"


func _ready() -> void:
	layer = LAYER
	get_viewport().size_changed.connect(func() -> void:
		if any_open():
			_layout())
	root = Control.new()
	root.name = "Bags"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ClassicSkin.theme()
	add_child(root)
	_err = Control.new()
	_err.name = "ErrorLine"
	_err.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_err.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_err.draw.connect(_draw_error)
	root.add_child(_err)
	tip = TipBox.new()
	root.add_child(tip)
	split_box = BagUI.SplitBox.new()
	root.add_child(split_box)
	ask = AskBox.new()
	ask.windows = self
	root.add_child(ask)
	world = WorldDrop.new()
	world.windows = self
	if hud != null and hud._root != null:
		hud._root.add_child(world)
		hud._root.move_child(world, 0)          # (under the HUD's frames: the action bar and the bag bar take their drops)
	_icons = ItemIcons.shared(get_tree())
	_icons.ready_icon.connect(func(_k: String) -> void: _dirty = true)


func _exit_tree() -> void:
	if _mode:
		_set_mode(false)
	_hands_off(false)
	if world != null and is_instance_valid(world):
		world.queue_free()


func bags() -> PlayerBags:
	var g := PlayerBags.find(player)
	if g != null and g != _hooked:
		_hooked = g
		g.changed.connect(func() -> void: _dirty = true)
	return g


func icon(k: String) -> Texture2D:
	return _icons.get_icon(k) if _icons != null and k != "" and not k.begins_with(BagUI.CLOTH) else null


# --- opening and closing --------------------------------------------------------------------------------------------

func any_open() -> bool:
	return open.has(true)


func is_open(b: int) -> bool:
	return b >= 0 and b < open.size() and open[b]


## While a bag is open the cursor is free and the hands' clicks are let go (see the header).
func blocks_input() -> bool:
	return _mode


## Opens bag b's window. False when it cannot be (no bag there, dead, a screen up, mid-shot: the reason in red).
func open_bag(b: int) -> bool:
	var g := bags()
	if g == null or b < 0 or b >= open.size() or g.bag_kind(b) == "":
		return false
	if not _mode and not _may_open():
		return false
	open[b] = true
	_set_mode(true)
	refresh_now()
	return true


func close_bag(b: int) -> void:
	if b < 0 or b >= open.size() or not open[b]:
		return
	open[b] = false
	refresh_now()


func toggle_bag(b: int) -> bool:
	if is_open(b):
		close_bag(b)
		return false
	return open_bag(b)


## M: every bag open; all open already, all closed.
func toggle_all() -> bool:
	var g := bags()
	if g == null:
		return false
	var all := true
	for b in open.size():
		if g.bag_kind(b) != "" and not open[b]:
			all = false
	if all and any_open():
		close_all()
		return false
	if not _mode and not _may_open():
		return false
	for b in open.size():
		open[b] = g.bag_kind(b) != ""
	_set_mode(true)
	refresh_now()
	return true


func close_all() -> void:
	for b in open.size():
		open[b] = false
	refresh_now()


func window(b: int) -> BagGrid:
	return windows.get(b) as BagGrid


func loose_window() -> BagGrid:
	return loose_win


## The slot control of bag b's slot i (its window made; null none).
func slot_ctrl(b: int, i: int) -> BagSlot:
	var w := loose_win if b == BagSlot.LOOSE else window(b)
	return w.slots[i] if w != null and i >= 0 and i < w.slots.size() else null


func _may_open() -> bool:
	if not _game_has_mouse():
		return false
	if _mid_action():
		error("Let the shot down first")
		return false
	return true


## The game view has the player (no screen over it, not dead).
func _game_has_mouse() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree() or player.is_dead:
		return false
	var tree := get_tree()
	if tree.paused or StoryDialogue.is_open(tree):
		return false
	return not (player.rts != null and is_instance_valid(player.rts) and player.rts.active)


## In the middle of a shot, a draw, a wind-up, a swing or a cast: fire held with something in the hands, or a spell's lock
## under way (freeing the cursor then would loose it).
func _mid_action() -> bool:
	if InputMap.has_action(&"fire") and Input.is_action_pressed(&"fire"):
		var tool_out := player.gather != null and player.gather.in_hand() != ""
		if not player.hands_free or tool_out:
			return true
	var c := SwayCaster.of(player)
	if c != null and c.state != SwayCaster.State.IDLE:
		return true
	return InputMap.has_action(&"aim") and Input.is_action_pressed(&"aim") and player.hotbar != null and player.hotbar.spell != ""


func _set_mode(on: bool) -> void:
	if on == _mode:
		return
	_mode = on
	if on:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hands_off(true)
		world.visible = true
		world.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		world.visible = false
		world.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hide_tip()
		split_box.close()
		ask.visible = false
		_pending = {}
		_hands_off(false)
		if _was_captured and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and _game_has_mouse():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_bar_refresh()


## `off`: the hands' actions (HANDS) let go and their bindings kept aside (a click presses none of them); else given back.
func _hands_off(off: bool) -> void:
	if off:
		for a: StringName in HANDS:
			if not InputMap.has_action(a) or _stash.has(a):
				continue
			_stash[a] = InputMap.action_get_events(a)
			InputMap.action_erase_events(a)
			if Input.is_action_pressed(a):
				Input.action_release(a)
		return
	for a: StringName in _stash:
		if not InputMap.has_action(a):
			continue
		for ev: InputEvent in _stash[a]:
			if not InputMap.action_has_event(a, ev):
				InputMap.action_add_event(a, ev)
	_stash.clear()


## Bindings for the screens over the game (the pause menu's controls show them): given back while paused, kept aside again
## after.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _mode:
		_hands_off(false)
	elif what == NOTIFICATION_UNPAUSED and _mode:
		_hands_off(true)


func _bar_refresh() -> void:
	if hud != null and hud.classic != null and hud.classic.bags != null:
		hud.classic.bags.refresh(player)


# --- the windows ----------------------------------------------------------------------------------------------------

## Every open window from the bags now, and laid out.
func refresh_now() -> void:
	var g := bags()
	if g == null:
		return
	g.sync()
	_dirty = false
	var icon_of := Callable(self, &"icon")
	for b in open.size():
		if open[b] and g.bag_kind(b) == "":
			open[b] = false                      # (its bag taken off: the window goes)
		var w := window(b)
		if open[b] and w == null:
			w = _make_grid(b)
			windows[b] = w
		if w != null:
			w.visible = open[b]
			if open[b]:
				w.refresh(g, icon_of)
	var want_loose := any_open() and g.loose_slots() > 0
	if want_loose and loose_win == null:
		loose_win = _make_grid(BagSlot.LOOSE)
		loose_win.closable = false
	if loose_win != null:
		loose_win.visible = want_loose
		if want_loose:
			loose_win.refresh(g, icon_of)
	_layout()
	if not any_open() and _mode:
		_set_mode(false)
	elif _mode:
		_bar_refresh()


func _make_grid(b: int) -> BagGrid:
	var w := BagGrid.new()
	w.name = "Loose" if b == BagSlot.LOOSE else "Bag%d" % b
	w.host = self
	w.bag = b
	w.slot_px = BagUI.SLOT_HUD
	w.closable = b != BagSlot.LOOSE
	root.add_child(w)
	root.move_child(w, 0)                       # (under the red line, the tooltip, the split box and the question)
	return w


## The windows stacked up from over the bag bar at the bottom right, the Loose strip lowest, then the haversack, then the
## bags in socket order; a column that would pass the top (under the classic map) starts another to its left.
func _layout() -> void:
	var vp := root.get_viewport_rect().size
	var base := vp.y - FOOT
	var top := 24.0
	var mp := HudClassicMap.find(hud) if hud != null else null
	if mp != null and mp.minimap != null and mp.minimap.is_visible_in_tree():
		top = mp.minimap.get_global_rect().end.y + 30.0
	var order: Array[BagGrid] = []
	if loose_win != null and loose_win.visible:
		order.append(loose_win)
	for b in open.size():
		var w := window(b)
		if w != null and w.visible:
			order.append(w)
	var right := vp.x - MARGIN
	var bottom := base
	var col_w := 0.0
	for w in order:
		var h := w.size.y
		if bottom - h < top and bottom < base:
			right -= col_w + COL_GAP
			bottom = base
			col_w = 0.0
		w.position = Vector2(right - w.size.x, bottom - h)
		bottom -= h + WIN_GAP
		col_w = maxf(col_w, w.size.x)


# --- the slots' and the windows' calls (BagSlot, BagGrid) --------------------------------------------------------------

func slot_hover(s: BagSlot, on: bool) -> void:
	if on and s.kind != "":
		_tip_slot = s
		_tip_t = TIP_DELAY
	elif _tip_slot == s:
		_hide_tip()


func slot_click(_s: BagSlot) -> void:
	_hide_tip()


func slot_double_click(_s: BagSlot) -> void:
	pass


func slot_shift_click(s: BagSlot) -> void:
	if s.bag != BagSlot.LOOSE:
		split_slot(s.bag, s.index)


func slot_right_click(s: BagSlot) -> void:
	_hide_tip()
	if s.bag == BagSlot.LOOSE:
		var g := bags()
		if g != null and s.index < g.loose.size():
			_report(BagUI.use_stack(player, g, String(g.loose[s.index].kind)))
		return
	use_slot(s.bag, s.index)


func slot_drag(s: BagSlot) -> Variant:
	_hide_tip()
	return loose_payload(s.index) if s.bag == BagSlot.LOOSE else payload(s.bag, s.index)


func slot_drop_check(s: BagSlot, d: Variant) -> Dictionary:
	var g := bags()
	if g == null:
		return {"ok": false, "reason": ""}
	if s.bag == BagSlot.LOOSE:
		return {"ok": s._is_self(d), "reason": "" if s._is_self(d) else "Into a bag, not onto the loose things"}
	return BagUI.verdict_slot(player, g, s.bag, s.index, d)


func slot_drop(s: BagSlot, d: Variant) -> void:
	if s.bag == BagSlot.LOOSE:
		if not s._is_self(d):
			error("Into a bag, not onto the loose things")
		return
	drop_on_slot(d, s.bag, s.index)


func slot_icon(k: String) -> Texture2D:
	return icon(k)


func grid_close(w: BagGrid) -> void:
	close_bag(w.bag)


func grid_drag(w: BagGrid) -> Variant:
	var g := bags()
	return BagUI.socket_payload(g, w.bag - 1) if g != null and w.bag >= 1 else null


func grid_drop_check(w: BagGrid, d: Variant) -> Dictionary:
	var g := bags()
	return BagUI.verdict_into(player, g, w.bag, d) if g != null else {"ok": false, "reason": ""}


func grid_drop(w: BagGrid, d: Variant) -> void:
	drop_on_bag(d, w.bag)


# --- what the mouse does (also the tests' calls) ----------------------------------------------------------------------

func payload(b: int, i: int) -> Dictionary:
	var g := bags()
	return BagUI.slot_payload(g, b, i) if g != null else {}


func loose_payload(li: int) -> Dictionary:
	var g := bags()
	return BagUI.loose_payload(g, li) if g != null else {}


## `d` dropped on slot (b, i): moved, swapped, merged, put away, a bag taken off, a hotbar slot emptied into it.
func drop_on_slot(d: Variant, b: int, i: int) -> Dictionary:
	var g := bags()
	if g == null:
		return {"ok": false, "reason": ""}
	var r := BagUI.drop_slot(player, g, b, i, d)
	_report(r, false)
	refresh_now()
	return r


## `d` dropped on bag b as a whole (its window's title, the pack button): into its first free slot.
func drop_on_bag(d: Variant, b: int) -> Dictionary:
	var g := bags()
	if g == null:
		return {"ok": false, "reason": ""}
	var r := BagUI.drop_into(player, g, b, d)
	_report(r, false)
	refresh_now()
	return r


## `d` dropped on bag-bar socket `s`: a bag item put on there, the sockets' bags changing places, else into the bag there.
func drop_on_socket(d: Variant, s: int) -> Dictionary:
	var g := bags()
	if g == null:
		return {"ok": false, "reason": ""}
	var had := g.sockets.duplicate()
	var r := BagUI.drop_socket(player, g, s, d)
	_report(r)
	if bool(r.ok) and any_open() and had[s] != g.sockets[s] and g.sockets[s] != "":
		open[s + 1] = true                      # (a bag put on with the bags open: its window too)
	refresh_now()
	return r


## `d` dropped on hotbar slot `slot` (the HUD's action bar).
func drop_on_bar(d: Variant, slot: int) -> Dictionary:
	var r := BagUI.drop_bar(player, slot, d)
	_report(r)
	refresh_now()
	return r


## `d` dropped on the world: the question ("Drop 12 Venison?"); a hotbar slot dropped there comes off the bar. {ok, reason}.
func drop_on_world(d: Variant) -> Dictionary:
	if d is Dictionary and String((d as Dictionary).get("from", "")) == "hotbar":
		var hb := Hotbar.find(player)
		if hb != null and hb.filled(int(d.slot)):
			var nm := hb.label(int(d.slot))
			hb.clear(int(d.slot))
			_say("%s off the hotbar: in the pack." % nm)
			refresh_now()
		return {"ok": true, "reason": ""}
	var g := bags()
	if g == null:
		return {"ok": false, "reason": ""}
	var v := BagUI.verdict_ground(g, d)
	if not bool(v.ok):
		if String(v.reason) != "":
			error(String(v.reason))
		return v
	_pending = (d as Dictionary).duplicate()
	_hide_tip()
	ask.ask(String(v.reason))
	return v


## The drop question answered "Drop": it lies on the ground in front of the player.
func confirm_drop() -> Dictionary:
	ask.visible = false
	if _pending.is_empty():
		return {"ok": false, "reason": ""}
	var g := bags()
	var r := BagUI.drop_ground(player, g, _pending) if g != null else {"ok": false, "reason": ""}
	_pending = {}
	_report(r)
	refresh_now()
	return r


## The drop question answered "Keep".
func keep() -> void:
	ask.visible = false
	_pending = {}


## A right-click on slot (b, i): used (BagUI.use_stack).
func use_slot(b: int, i: int) -> Dictionary:
	var g := bags()
	if g == null:
		return {"ok": false, "reason": ""}
	var e := g.slot(b, i)
	if e.is_empty():
		return {"ok": false, "reason": ""}
	var had := g.sockets.duplicate()
	var r := BagUI.use_stack(player, g, String(e.kind))
	_report(r)
	if bool(r.ok) and any_open() and had != g.sockets:
		for s in PlayerBags.SOCKETS:
			if had[s] != g.sockets[s] and g.sockets[s] != "":
				open[s + 1] = true
	refresh_now()
	return r


## Shift-click on slot (b, i): the split box opens by it (a stack of 2 or more).
func split_slot(b: int, i: int) -> bool:
	var g := bags()
	var e := g.slot(b, i) if g != null else {}
	if e.is_empty() or int(e.count) < 2:
		return false
	_hide_tip()
	var s := slot_ctrl(b, i)
	var at := s.get_global_rect().position - Vector2(BagUI.SplitBox.W + 8.0, 0.0) if s != null else root.get_viewport_rect().size * 0.5
	var k := String(e.kind)
	split_box.open_for(at, int(e.count), g.kind_name(k), func(n: int) -> void:
		var gg := bags()
		if gg == null or String(gg.slot(b, i).get("kind", "")) != k:
			return
		var r := gg.split(b, i, n)
		_report(r, false)
		refresh_now())
	return true


# --- lines ----------------------------------------------------------------------------------------------------------

## A refusal, in red over the middle of the screen.
func error(text: String) -> void:
	error_text = text
	_error_t = ERROR_S if text != "" else 0.0
	_err.queue_redraw()


func _say(text: String) -> void:
	if text == "":
		return
	var it: Variant = player.get("interactor") if player != null else null
	if it is Object and (it as Object).has_method(&"notice"):
		(it as Object).call(&"notice", text)


## A result: a refusal in red, what was done (when `tell`) to the notice line.
func _report(r: Dictionary, tell := true) -> void:
	var why := String(r.get("reason", ""))
	if not bool(r.get("ok", false)):
		if why != "":
			error(why)
	elif tell and why != "":
		_say(why)


func _draw_error() -> void:
	if error_text == "" or _error_t <= 0.0:
		return
	var vp := _err.size
	var a := clampf(_error_t / 0.6, 0.0, 1.0)
	var col := Color(1.0, 0.36, 0.28, a)
	var f := ClassicSkin.font()
	var w := f.get_string_size(error_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	ClassicSkin.text(_err, Vector2((vp.x - w) * 0.5, vp.y * 0.2), error_text, 19, col)


# --- the tooltip --------------------------------------------------------------------------------------------------------

func _hide_tip() -> void:
	_tip_slot = null
	_tip_t = 0.0
	if tip != null:
		tip.visible = false


## Shows slot `s`'s tooltip now (the pointer resting on it does after TIP_DELAY).
func show_tip(s: BagSlot) -> void:
	var g := bags()
	if g == null or s == null or s.kind == "":
		return
	tip.show_info(BagUI.tip(player, g, s.kind, s.count, s.bag == BagSlot.LOOSE), s.get_global_rect(), root.get_viewport_rect().size)


# --- input --------------------------------------------------------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if (k.physical_keycode == KEY_ESCAPE or e.is_action_pressed(&"ui_cancel")) and any_open():
			if ask.visible:
				keep()
			elif split_box.visible:
				split_box.close()
			else:
				close_all()
			get_viewport().set_input_as_handled()
		elif InputMap.has_action(ACTION) and e.is_action_pressed(ACTION) and not split_box.visible and _game_has_mouse():
			toggle_all()
			get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	# (what the windows and the world did not take: no capture by a click, no hotbar step by the wheel)
	if _mode and e is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _error_t > 0.0:
		_error_t -= delta
		_err.queue_redraw()
	if not _mode:
		return
	if player == null or not is_instance_valid(player) or player.is_dead \
			or (player.rts != null and is_instance_valid(player.rts) and player.rts.active):
		close_all()
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _game_has_mouse():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # (a screen closed over the open bags took the mouse: ours again)
	if _dirty:
		refresh_now()
	if _tip_slot != null and _tip_t > 0.0:
		_tip_t -= delta
		if _tip_t <= 0.0 and is_instance_valid(_tip_slot) and _tip_slot.is_visible_in_tree() and not get_viewport().gui_is_dragging():
			show_tip(_tip_slot)


# --- the parts ----------------------------------------------------------------------------------------------------------

## The world under the windows while a bag is open (FrontierHUD's root, under its frames): a click there does nothing; a
## drag let go there is dropped on the ground (BagWindows.drop_on_world: the question first).
class WorldDrop:
	extends Control
	var windows: BagWindows

	func _init() -> void:
		name = "BagWorldDrop"
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			accept_event()

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		return windows != null and d is Dictionary and String((d as Dictionary).get("from", "")) in ["pack", "cloth", "socket", "hotbar"]

	func _drop_data(_at: Vector2, d: Variant) -> void:
		windows.drop_on_world(d)


## The classic tooltip box: the name, its kind, ItemInfo's rows (a label and its value in its tone), what it is.
class TipBox:
	extends Control
	const W := 300.0
	const PAD := 10.0
	const LABEL_W := 74.0
	const TONES := {"good": Color(0.663, 0.839, 0.478), "warn": Color(0.941, 0.635, 0.306), "use": Color(0.91, 0.757, 0.439),
			"": Color(0.902, 0.863, 0.776)}
	var info := {}
	var _lines: Array = []              ## [y, kind, ...] laid out by show_info

	func _init() -> void:
		name = "BagTip"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	## Shows `inf` (BagUI.tip) beside `near` (a slot's rect), kept on the screen `vp`.
	func show_info(inf: Dictionary, near: Rect2, vp: Vector2) -> void:
		info = inf
		var f := ClassicSkin.font()
		var y := PAD + 16.0
		_lines = [[y, "name", String(inf.get("name", ""))]]
		if String(inf.get("tag", "")) != "":
			y += 16.0
			_lines.append([y, "tag", String(inf.tag).to_upper()])
		y += 6.0
		for r: Array in inf.get("rows", []):
			var lab := String(r[0])
			var val := String(r[1])
			var wv := W - PAD * 2.0 - (LABEL_W if lab != "" else 0.0)
			var h := f.get_multiline_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, wv, 13).y
			_lines.append([y, "row", lab, val, String(r[2]) if r.size() > 2 else "", wv])
			y += maxf(h, 16.0) + 1.0
		var text := String(inf.get("text", ""))
		if text != "":
			y += 4.0
			var th := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 13).y
			_lines.append([y, "text", text])
			y += th
		size = Vector2(W, y + PAD)
		var at := Vector2(near.position.x - W - 10.0, near.position.y)
		if at.x < 8.0:
			at.x = near.end.x + 10.0
		at.y = clampf(at.y, 8.0, vp.y - size.y - 8.0)
		position = at
		visible = true
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		ClassicSkin.panel(self, r, false)
		draw_rect(r.grow(-3.0), Color(0.05, 0.035, 0.025, 0.55))
		var f := ClassicSkin.font()
		for ln: Array in _lines:
			var y := float(ln[0])
			match String(ln[1]):
				"name":
					ClassicSkin.text(self, Vector2(PAD, y), String(ln[2]), 17, ClassicSkin.GOLD, W - PAD * 2.0)
				"tag":
					ClassicSkin.text(self, Vector2(PAD, y), String(ln[2]), 11, ClassicSkin.DIM, W - PAD * 2.0)
				"row":
					var x := PAD
					if String(ln[2]) != "":
						draw_string(f, Vector2(PAD, y + 12.0), String(ln[2]), HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 6.0, 13, Color(0.63, 0.59, 0.54))
						x += LABEL_W
					draw_multiline_string(f, Vector2(x, y + 12.0), String(ln[3]), HORIZONTAL_ALIGNMENT_LEFT, float(ln[5]), 13, -1,
							TONES.get(String(ln[4]), TONES[""]))
				"text":
					draw_multiline_string(f, Vector2(PAD, y + 12.0), String(ln[2]), HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 13, -1,
							Color(0.8, 0.75, 0.64))


## The drop question ("Drop 12 Venison?"): Drop (Enter) or Keep (Escape), over the middle of the screen.
class AskBox:
	extends Control
	const W := 300.0
	const H := 86.0
	var windows: BagWindows
	var question := ""

	func _init() -> void:
		name = "DropAsk"
		size = Vector2(W, H)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		var yes := BagUI.LeatherButton.new("Drop", func() -> void: windows.confirm_drop())
		yes.name = "Drop"
		yes.position = Vector2(24.0, H - 36.0)
		yes.size = Vector2(110, 26)
		add_child(yes)
		var no := BagUI.LeatherButton.new("Keep", func() -> void: windows.keep())
		no.name = "Keep"
		no.position = Vector2(W - 134.0, H - 36.0)
		no.size = Vector2(110, 26)
		add_child(no)

	func ask(q: String) -> void:
		question = q
		var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
		position = Vector2((vp.x - W) * 0.5, vp.y * 0.26)
		visible = true
		queue_redraw()

	func _input(e: InputEvent) -> void:
		if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
			return
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			windows.confirm_drop()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			windows.keep()
			get_viewport().set_input_as_handled()

	func _draw() -> void:
		ClassicSkin.panel(self, Rect2(Vector2.ZERO, size))
		ClassicSkin.text_centred(self, Rect2(0, 8, W, 30), question, 17, ClassicSkin.INK)
