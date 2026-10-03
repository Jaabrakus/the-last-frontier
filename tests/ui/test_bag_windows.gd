extends SceneTree
## The bag windows (BagWindows, BagGrid, BagSlot, BagUI; the owner 2026-10-03: "can we do the inventory similar to world of
## warcraft with the bags and etc?", then "WoW-style bags ... i just need you to do these") on the real level with the real
## player, the classic HUD, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_bag_windows.gd -- survival=on hud=classic
##
##   key        "bags" on M, no other action there (B is build mode); in the F1 controls
##   open       M opens every worn bag (the haversack and the linen satchel), a window each with a slot a bag slot, stacked
##              up from over the bag bar at the bottom right (the haversack lowest), on the screen; M again closes them;
##              the bag bar's socket toggles its bag (its rim gold while open), the pack the haversack; Escape closes them
##              (the drop question first) and the pause menu does not open
##   block      a bag open: the cursor ours (blocks_input); a click with fire held lets go of fire at once and the musket
##              in hand does not fire; a click and the mouse's motion on the world go nowhere (no turn, no capture: the
##              WorldDrop); fire held with the musket out: the bags do not open ("Let the shot down first"); closed: the
##              world's clicks go to the game again
##   drags      move to an empty slot, swap with another kind, split (the split box) and merge back; a game bag put on
##              (a bag item dropped on a socket) refuses stone with its reason in red (the slot red under the drag), takes
##              venison; its window opens beside; taken off: refused while it holds things ("Empty the game bag first"),
##              emptied it comes off into the slot it is dropped on; a knapsack right-clicked goes on; two sockets' bags
##              change places
##   hotbar     the musket's slot dragged into a bag: off the bar, into that slot; that slot dragged onto the action bar's
##              button: on the bar again; dropped on the pack button: into the haversack
##   use        right-click on jerky (hungry): eaten from the pack
##   ground     venison dragged onto the world: "Drop 5 Venison?", Drop: it lies on the ground (DroppedItem), E takes it back;
##              the musket refused ("put down with E")
##   loose      logs past every free slot: the Loose strip lowest under the bags, the slow-down at its foot
##   tooltip    a stack's: its name and ItemInfo's rows; a bag's: its slots and what it holds
##   bar        the bag bar's sockets show their bags' free slots and pictures' kinds, the pack the free total
##   tab        the Tab screen's pack is the same grids (the haversack's 16 slots, the satchel's 8; PackCell); the musket off
##              the bar lies in one and its drag goes onto the figure; a move between slots; a knapsack double-clicked
##              there goes on
##   minimal    the minimal HUD has the bag windows too
## Ends with "BAG WINDOWS TEST OK (<n> checks)" or "BAG WINDOWS TEST FAILED <f>/<n>: [...]".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var hud: FrontierHUD
var bw: BagWindows
var g: PlayerBags
var hb: Hotbar
var b: SurvivalBridge
var fr: ClassicFrames


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func pframes(n: int) -> void:
	for i in n:
		await process_frame


func add(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(p)
	inv.add(kind, n)
	p.inventory_pack = inv.pack.duplicate(true)
	g.sync()
	bw.refresh_now()


func set_count(kind: String, n: int) -> void:
	var out := []
	for e: Dictionary in p.inventory_pack:
		if String(e.get("kind", "")) != kind:
			out.append(e)
	if n > 0:
		out.append({"kind": kind, "count": n, "state": {}})
	p.inventory_pack = out
	g.sync()
	bw.refresh_now()


func count(kind: String) -> int:
	return Campfire._pack_count(p, kind)


## Where `kind` lies: [[b, i, count], ...].
func where(kind: String) -> Array:
	var out := []
	for bi in g.bag_count():
		for i in g.bag_size(bi):
			var e := g.slot(bi, i)
			if String(e.get("kind", "")) == kind:
				out.append([bi, i, int(e.count)])
	return out


func first_free(bi: int) -> int:
	for i in g.bag_size(bi):
		if g.slot(bi, i).is_empty():
			return i
	return -1


## A free slot of a bag that holds anything, the last bags first: [b, i] ([-1, -1] none).
func free_any(skip := -1) -> Array:
	for bi in range(g.bag_count() - 1, -1, -1):
		if bi == skip or g.bag_kind(bi) == "" or PlayerBags.is_specialty(g.bag_kind(bi)):
			continue
		var i := first_free(bi)
		if i >= 0:
			return [bi, i]
	return [-1, -1]


func key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = down
		root.push_input(e)


func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = at
		e.global_position = at
		root.push_input(e)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(150)
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	b = SurvivalBridge.find(self)
	hud = p.hud if p != null else null
	check(p != null and b != null and hud != null, "the level has the player, the survival bridge (survival=on) and the HUD")
	if p == null or b == null or hud == null:
		_end()
		return
	p.ignore_mouse_capture = true
	root.size = Vector2i(1600, 900)
	for cc in root.find_children("*", "CharacterCreator", true, false):
		if cc.has_method("close"):
			cc.close()
	await frames(int(Hotbar.KIT_S * Engine.physics_ticks_per_second) + 20)
	bw = BagWindows.of(hud)
	g = PlayerBags.find(p)
	hb = Hotbar.find(p)
	fr = hud.classic
	check(bw != null and hud.bag_windows == bw and g != null and hb != null and hb.kit_placed and fr != null,
			"the HUD has the bag windows (BagWindows), the player bags, the hotbar's kit placed, the classic frames (hud=classic)")
	if bw == null or g == null or fr == null:
		_end()
		return
	_key_checks()
	await _open_checks()
	await _block_checks()
	await _drag_checks()
	await _hotbar_checks()
	await _use_checks()
	await _ground_checks()
	await _loose_checks()
	_tooltip_checks()
	await _tab_checks()
	await _minimal_checks()
	_end()


func _end() -> void:
	if bw != null:
		bw.close_all()
	if fails.is_empty():
		print("BAG WINDOWS TEST OK (%d checks)" % checks)
	else:
		print("BAG WINDOWS TEST FAILED %d/%d: %s" % [fails.size(), checks, str(fails)])
	quit(0 if fails.is_empty() else 1)


# --- the key -------------------------------------------------------------------------------------------------------

func _key_checks() -> void:
	var on_m := []
	var on_b := []
	for a in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			var k := e as InputEventKey
			if k == null or k.ctrl_pressed or k.meta_pressed or k.alt_pressed or k.shift_pressed or k.command_or_control_autoremap:
				continue
			if k.physical_keycode == KEY_M or k.keycode == KEY_M:
				on_m.append(String(a))
			if k.physical_keycode == KEY_B or k.keycode == KEY_B:
				on_b.append(String(a))
	check(on_m == [String(BagWindows.ACTION)] and BagWindows.key_label() == "M", "bags on M and no other action there (%s)" % str(on_m))
	check(not on_b.has(String(BagWindows.ACTION)), "B is not the bags' (%s: build mode)" % str(on_b))
	var help := (hud._help_box.get_child(0) as Label).text
	check(help.contains("M bags"), "in the F1 controls")


# --- opening -------------------------------------------------------------------------------------------------------

func _open_checks() -> void:
	check(not bw.any_open() and not bw.blocks_input(), "closed at the start")
	key(KEY_M)
	await pframes(2)
	var hv := bw.window(0)
	var sa := bw.window(1)
	check(bw.is_open(0) and bw.is_open(1) and hv != null and sa != null and hv.visible and sa.visible,
			"M: the haversack and the linen satchel open (%s)" % str(g.sockets))
	if hv == null or sa == null:
		return
	check(hv.slots.size() == 16 and sa.slots.size() == 8 and hv.title == "Haversack" and sa.title == "Linen Satchel",
			"a slot a bag slot (16, 8), the bags' names in the titles")
	var vp := hv.get_viewport_rect().size
	var hr := hv.get_global_rect()
	var sr := sa.get_global_rect()
	var bar := fr.bags.get_global_rect()
	check(vp.x - hr.end.x < 30.0 and hr.end.y <= bar.position.y and hr.end.y > vp.y - 160.0 and sr.end.y <= hr.position.y + 0.5
			and Rect2(Vector2.ZERO, vp).encloses(hr) and Rect2(Vector2.ZERO, vp).encloses(sr),
			"stacked up from over the bag bar at the bottom right, the haversack lowest (%s, %s, bar %s)" % [hr, sr, bar])
	check(hr.size.x > 150.0 and hr.size.x < 200.0 and absf(hv.slots[0].size.x - BagUI.SLOT_HUD) < 0.5, "4 wide, %d px slots" % int(BagUI.SLOT_HUD))
	check(bw.blocks_input() and bw.world.visible and bw.world.mouse_filter == Control.MOUSE_FILTER_STOP,
			"open: the cursor is the bags' (the world under the windows takes the clicks)")
	key(KEY_M)
	await pframes(2)
	check(not bw.any_open() and not hv.visible and not bw.blocks_input() and not bw.world.visible, "M again: all closed")
	# the bag bar
	var s1: ClassicBagBar.BagSocket = null
	for btn in fr.bags.buttons:
		if btn.id == "bag_1":
			s1 = btn
	s1.press()
	await pframes(2)
	check(bw.is_open(1) and not bw.is_open(0) and s1.open, "bag 1's socket: the satchel's window alone, its rim gold")
	fr.bags.pack.press()
	await pframes(2)
	check(bw.is_open(0) and bw.is_open(1), "the pack: the haversack's too")
	s1.press()
	fr.bags.pack.press()
	await pframes(2)
	check(not bw.any_open() and not s1.open, "pressed again: both closed")
	# Escape: closes them, the pause menu stays shut
	bw.toggle_all()
	await pframes(1)
	key(KEY_ESCAPE)
	await pframes(2)
	var pm := current_scene.find_child("PauseMenu", false, false) as PauseMenu
	check(not bw.any_open() and (pm == null or not pm.is_open()) and not paused, "Escape: the bags closed, no pause menu")


# --- the cursor-free block -----------------------------------------------------------------------------------------

class MouseProbe extends Node:
	var got := 0

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			got += 1


func _block_checks() -> void:
	# the musket in hand
	var ms := hb.slot_of(Hotbar.WEAPON, "musket")
	if ms >= 0 and hb.selected() != ms:
		hb.select(ms)
		await frames(90)
	var w := p.weapon
	check(w != null and p.weapon_key == "musket" and not p.hands_free, "the musket in hand (%s)" % p.weapon_key)
	var shots := [0]
	if w != null:
		w.fired.connect(func() -> void: shots[0] += 1)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	var rmb := lmb.duplicate() as InputEventMouseButton
	rmb.button_index = MOUSE_BUTTON_RIGHT
	check(InputMap.event_is_action(lmb, &"fire") and InputMap.event_is_action(rmb, &"aim"), "closed: a left click is fire, a right click aim")
	# fire held with the musket out: the bags do not open
	Input.action_press(&"fire")
	var opened := bw.toggle_all()
	check(not opened and not bw.any_open() and bw.error_text == "Let the shot down first", "fire held: no bags (\"%s\")" % bw.error_text)
	Input.action_release(&"fire")
	await frames(240)                     # (that press was the game's, the bags shut: the musket may shoulder and fire on it)
	shots[0] = 0
	bw.toggle_all()
	await pframes(2)
	check(not InputMap.event_is_action(lmb, &"fire") and not InputMap.event_is_action(rmb, &"aim")
			and InputMap.action_get_events(&"fire").is_empty() and InputMap.has_action(&"fire"),
			"open: the hands' actions unbound (a click is no fire, no aim, not even for a frame)")
	var probe := MouseProbe.new()
	p.add_child(probe)
	p.move_child(probe, 0)
	# a click in a bag through the whole input path (Input.parse_input_event: the Input singleton and the viewport)
	var at := bw.slot_ctrl(0, 0).get_global_rect().get_center()
	var e := lmb.duplicate() as InputEventMouseButton
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	await pframes(1)
	check(not Input.is_action_pressed(&"fire") and not Input.is_action_just_pressed(&"fire"), "a click in a bag: no fire pressed")
	var up := e.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await frames(60)
	check(shots[0] == 0 and (w == null or (w as Firearm).state != Firearm.State.AIMING), "and the musket did not fire (%d)" % shots[0])
	# a click and the mouse's motion on the world: nowhere
	var world_at := Vector2(500, 300)
	probe.got = 0
	var yaw0 := p.yaw
	var mm := InputEventMouseMotion.new()
	mm.position = world_at
	mm.relative = Vector2(140, 30)
	root.push_input(mm)
	var yaw1 := p.yaw
	var e2 := e.duplicate() as InputEventMouseButton
	e2.position = world_at
	e2.global_position = world_at
	root.push_input(e2)
	var up2 := e2.duplicate() as InputEventMouseButton
	up2.pressed = false
	root.push_input(up2)
	var r2 := rmb.duplicate() as InputEventMouseButton
	r2.position = world_at
	Input.parse_input_event(r2)
	await pframes(1)
	check(not Input.is_action_pressed(&"aim"), "a right click on the world: no aim")
	var r2_up := r2.duplicate() as InputEventMouseButton
	r2_up.pressed = false
	Input.parse_input_event(r2_up)
	await frames(40)
	check(probe.got == 0 and absf(yaw1 - yaw0) < 0.0001 and shots[0] == 0 and bw.any_open(),
			"a click and the motion on the world go nowhere: no turn, no shot, the bags still open (%d, %.4f)" % [probe.got, yaw1 - yaw0])
	# a screen over the game (the Tab screen pauses it): the bindings back while it is up, kept aside again after
	var scr := InventoryScreen.open_for(p)
	await pframes(2)
	check(InputMap.event_is_action(lmb, &"fire"), "a screen over the open bags: fire bound again while it is up")
	scr.close()
	await pframes(2)
	paused = false
	await pframes(2)
	check(not InputMap.event_is_action(lmb, &"fire") and bw.any_open(), "closed: unbound again, the bags still open")
	bw.close_all()
	await pframes(2)
	check(InputMap.event_is_action(lmb, &"fire") and InputMap.event_is_action(rmb, &"aim") and not bw.blocks_input(),
			"the bags closed: fire and aim bound again")
	probe.got = 0
	click(world_at)
	check(probe.got > 0, "and the world's clicks go to the game again (%d)" % probe.got)
	probe.queue_free()
	# (the same click through the same path with the bags closed and the hands free: fire is pressed: the path is live)
	hb.hands_free()
	await frames(30)
	var c := lmb.duplicate() as InputEventMouseButton
	c.position = world_at
	c.global_position = world_at
	Input.parse_input_event(c)
	Input.flush_buffered_events()          # (parsed events are buffered until a flush or the frame's end)
	await pframes(1)
	var live := Input.is_action_pressed(&"fire")
	var c_up := c.duplicate() as InputEventMouseButton
	c_up.pressed = false
	Input.parse_input_event(c_up)
	await pframes(1)
	check(live, "the same click with the bags closed: fire pressed (the input path is live, so the checks above mean it)")
	if ms >= 0:
		hb.select(ms)
		await frames(60)


# --- drags ---------------------------------------------------------------------------------------------------------

func _drag_checks() -> void:
	# (room: a portmanteau on in bag 4; the start's things fill most of the haversack and the satchel)
	add("portmanteau", 1)
	g.equip("portmanteau", 3)
	set_count("venison", 5)
	set_count("stone", 3)
	bw.toggle_all()
	await pframes(1)
	check(g.sockets[3] == "portmanteau" and bw.is_open(4) and bw.window(4).slots.size() == 16, "a portmanteau on in bag 4, its window open")
	var v: Array = where("venison")
	var st: Array = where("stone")
	check(v.size() == 1 and st.size() == 1, "venison and stone each in a slot (%s, %s)" % [str(v), str(st)])
	if v.is_empty() or st.is_empty():
		return
	# move to an empty slot in the portmanteau
	var to := first_free(4)
	var r := bw.drop_on_slot(bw.payload(v[0][0], v[0][1]), 4, to)
	check(bool(r.ok) and String(g.slot(4, to).get("kind", "")) == "venison" and g.slot(v[0][0], v[0][1]).is_empty(),
			"venison dragged to an empty slot of the portmanteau: moved")
	check(bw.slot_ctrl(4, to).kind == "venison" and bw.slot_ctrl(4, to).count == 5, "and the window shows it there, 5")
	# swap with another kind
	st = where("stone")
	r = bw.drop_on_slot(bw.payload(4, to), st[0][0], st[0][1])
	check(bool(r.ok) and String(g.slot(st[0][0], st[0][1]).get("kind", "")) == "venison" and String(g.slot(4, to).get("kind", "")) == "stone",
			"venison onto the stone: they change places")
	# split and merge back
	v = where("venison")
	check(bw.split_slot(v[0][0], v[0][1]) and bw.split_box.visible, "shift-click: the split box opens")
	bw.split_box.set_n(2)
	bw.split_box.confirm()
	await pframes(1)
	v = where("venison")
	var ns := v.map(func(x: Array) -> int: return int(x[2]))
	ns.sort()
	check(v.size() == 2 and ns == [2, 3] and not bw.split_box.visible, "split off 2: stacks of 3 and 2 (%s)" % str(v))
	r = bw.drop_on_slot(bw.payload(v[1][0], v[1][1]), v[0][0], v[0][1])
	v = where("venison")
	check(bool(r.ok) and v.size() == 1 and int(v[0][2]) == 5, "dropped on the other: merged, 5 (%s)" % str(v))
	# a game bag put on (dropped on bag 2's socket)
	add("game_bag", 1)
	var gb: Array = where("game_bag")
	check(gb.size() == 1, "a game bag in the pack (%s)" % str(gb))
	var s2: ClassicBagBar.BagSocket = null
	for btn in fr.bags.buttons:
		if btn.id == "bag_2":
			s2 = btn
	var d := bw.payload(gb[0][0], gb[0][1])
	check(s2._can_drop_data(Vector2.ZERO, d) and s2.drop_state == "ok", "the game bag over bag 2's socket: green")
	s2._drop_data(Vector2.ZERO, d)
	await pframes(1)
	check(g.sockets[1] == "game_bag" and where("game_bag").is_empty() and bw.is_open(2) and bw.window(2).visible,
			"dropped: the game bag on in bag 2, its window open beside (%s)" % str(g.sockets))
	check(s2.bag_kind == "game_bag" and s2.count == str(g.free_slots(2)), "the socket shows it and its free slots (%s)" % s2.count)
	# the specialty refuses stone, red, with its reason
	st = where("stone")
	var free_gb := first_free(2)
	var cell := bw.slot_ctrl(2, free_gb)
	var ds := bw.payload(st[0][0], st[0][1])
	cell._can_drop_data(Vector2.ZERO, ds)
	check(cell.drop_state == "no", "stone over the game bag's slot: red")
	cell._drop_data(Vector2.ZERO, ds)
	check(g.slot(2, free_gb).is_empty() and bw.error_text.contains("holds only") and bw.error_text.contains("game"),
			"dropped: refused, the reason in red (\"%s\")" % bw.error_text)
	v = where("venison")
	var dv := bw.payload(v[0][0], v[0][1])
	cell._can_drop_data(Vector2.ZERO, dv)
	check(cell.drop_state == "ok", "venison over it: green")
	cell._drop_data(Vector2.ZERO, dv)
	check(String(g.slot(2, free_gb).get("kind", "")) == "venison", "dropped: the venison in the game bag")
	# taken off: refused while it holds things; emptied, into the slot it is dropped on
	var sock := BagUI.socket_payload(g, 1)
	var hfree := first_free(4)
	r = bw.drop_on_slot(sock, 4, hfree)
	check(not bool(r.ok) and String(r.reason).begins_with("Empty the game bag first") and g.sockets[1] == "game_bag",
			"the game bag dragged into a slot while it holds venison: refused (\"%s\")" % r.reason)
	r = bw.drop_on_slot(bw.payload(2, free_gb), 4, hfree)
	check(bool(r.ok) and g.used_slots(2) == 0, "the venison out of it")
	hfree = first_free(4)
	r = bw.drop_on_slot(BagUI.socket_payload(g, 1), 4, hfree)
	await pframes(1)
	check(bool(r.ok) and g.sockets[1] == "" and String(g.slot(4, hfree).get("kind", "")) == "game_bag" and not bw.is_open(2),
			"empty: it comes off into that slot, its window gone (%s)" % str(g.sockets))
	# a knapsack right-clicked goes on
	add("knapsack", 1)
	var kn: Array = where("knapsack")
	r = bw.use_slot(kn[0][0], kn[0][1])
	check(bool(r.ok) and g.sockets.has("knapsack") and where("knapsack").is_empty(), "a knapsack right-clicked: on (%s)" % str(g.sockets))
	# two sockets' bags change places (the knapsack's dragged onto the portmanteau's)
	var a := g.sockets.find("knapsack")
	r = bw.drop_on_socket(BagUI.socket_payload(g, a), 3)
	check(bool(r.ok) and g.sockets[3] == "knapsack" and g.sockets[a] == "portmanteau", "two sockets' bags change places (%s)" % str(g.sockets))
	set_count("stone", 0)


# --- the hotbar ----------------------------------------------------------------------------------------------------

func _hotbar_checks() -> void:
	var ms := hb.slot_of(Hotbar.WEAPON, "musket")
	check(ms >= 0, "the musket on the bar (%d)" % ms)
	if ms < 0:
		return
	var at := free_any()
	var r := bw.drop_on_slot({"from": "hotbar", "slot": ms}, at[0], at[1])
	await frames(4)
	check(bool(r.ok) and hb.slot_of(Hotbar.WEAPON, "musket") < 0 and String(g.slot(at[0], at[1]).get("kind", "")) == "musket",
			"the musket's slot dragged into a bag: off the bar, in that slot (%s, %s)" % [str(at), str(where("musket"))])
	var btn := fr.action_bar.buttons[ms]
	var d := bw.payload(at[0], at[1])
	check(btn._can_drop_data(Vector2.ZERO, d) and btn.drop_state == "ok", "that slot over the action bar's button: green")
	btn._drop_data(Vector2.ZERO, d)
	await frames(4)
	check(hb.slot_of(Hotbar.WEAPON, "musket") == ms and where("musket").is_empty() and g.slot(at[0], at[1]).is_empty(),
			"dropped: the musket on the bar again, its slot empty")
	check(not btn._can_drop_data(Vector2.ZERO, bw.payload(where("venison")[0][0], where("venison")[0][1])) or btn.drop_state == "no",
			"venison over the action bar: red")
	# the axe off the bar, moved out of the haversack, then dropped on the pack button: into the haversack
	var ax := hb.slot_of(Hotbar.TOOL, "felling_axe")
	if ax >= 0:
		hb.clear(ax)
		await frames(4)
		g.sync()
		var w0: Array = where("felling_axe")
		var other := free_any(0)
		if not w0.is_empty() and w0[0][0] == 0:
			bw.drop_on_slot(bw.payload(w0[0][0], w0[0][1]), other[0], other[1])
		if first_free(0) < 0:
			bw.drop_on_slot(bw.payload(0, 15), free_any(0)[0], free_any(0)[1])
		w0 = where("felling_axe")
		var pk := fr.bags.pack as ClassicBagBar.BagSocket
		pk._drop_data(Vector2.ZERO, bw.payload(w0[0][0], w0[0][1]))
		check(not where("felling_axe").is_empty() and where("felling_axe")[0][0] == 0, "the felling axe dropped on the pack: into the haversack (%s)"
				% str(where("felling_axe")))
		hb.assign(ax, Hotbar.make(Hotbar.TOOL, "felling_axe"))
		await frames(4)


# --- use -----------------------------------------------------------------------------------------------------------

func _use_checks() -> void:
	set_count("jerky", 3)
	b.core.state.needs["stomach"] = 200.0
	var j: Array = where("jerky")
	var s0 := float(b.core.state.needs.get("stomach", 0.0))
	var r := bw.use_slot(j[0][0], j[0][1])
	var s1 := float(b.core.state.needs.get("stomach", 0.0))
	check(bool(r.ok) and count("jerky") == 2 and s1 > s0 + 100.0, "jerky right-clicked, hungry: eaten (%d left, the stomach %.0f -> %.0f; \"%s\")"
			% [count("jerky"), s0, s1, r.reason])
	b.core.state.needs["stomach"] = 800.0
	set_count("jerky", 0)


# --- the ground ----------------------------------------------------------------------------------------------------

func _ground_checks() -> void:
	var v: Array = where("venison")
	var r := bw.drop_on_world(bw.payload(v[0][0], v[0][1]))
	check(bool(r.ok) and bw.ask.visible and bw.ask.question == "Drop 5 Venison?", "venison dragged onto the world: \"%s\"" % bw.ask.question)
	key(KEY_ESCAPE)
	await pframes(1)
	check(not bw.ask.visible and bw.any_open() and count("venison") == 5, "Escape: kept, the bags still open")
	bw.drop_on_world(bw.payload(v[0][0], v[0][1]))
	r = bw.confirm_drop()
	await frames(2)
	var item: DroppedItem = r.get("item") as DroppedItem
	check(bool(r.ok) and item != null and item.kind == "venison" and item.count == 5 and count("venison") == 0 and where("venison").is_empty(),
			"Drop: 5 venison on the ground, out of the bags (%s)" % r.reason)
	if item != null:
		check(item.global_position.distance_to(p.global_position) < 2.5, "in front of the player (%.2f m)" % item.global_position.distance_to(p.global_position))
		item.interact(p)
		g.sync()
		check(count("venison") == 5 and not where("venison").is_empty(), "E takes it back into the pack")
	var ms := hb.slot_of(Hotbar.WEAPON, "musket")
	hb.clear(ms)
	await frames(4)
	g.sync()
	var m: Array = where("musket")
	r = bw.drop_on_world(bw.payload(m[0][0], m[0][1]))
	check(not bool(r.ok) and not bw.ask.visible and String(r.reason).contains("put down with E"), "the musket: refused (\"%s\")" % r.reason)
	hb.assign(ms, Hotbar.make(Hotbar.WEAPON, "musket"))
	await frames(4)


# --- loose ---------------------------------------------------------------------------------------------------------

func _loose_checks() -> void:
	bw.close_all()
	bw.toggle_all()
	add("log", g.free_for("log") + 2)
	await pframes(1)
	var lw := bw.loose_window()
	check(g.loose_slots() == 2 and lw != null and lw.visible and lw.slots.size() == 2, "logs past every free slot: the Loose strip, 2")
	if lw != null:
		var lr := lw.get_global_rect()
		var hr := bw.window(0).get_global_rect()
		check(lr.position.y >= hr.end.y - 0.5 and lw.foot.contains("8 % slower"), "under the bags, the slow-down at its foot (\"%s\")" % lw.foot)
		check(lw.slots[0].kind == "log" and lw.slots[0].bag == BagSlot.LOOSE, "a loose log in it")
	set_count("log", 0)
	await pframes(1)
	check(g.loose_slots() == 0 and not lw.visible, "room again: the strip goes")


# --- the tooltip ---------------------------------------------------------------------------------------------------

func _tooltip_checks() -> void:
	var v: Array = where("venison")
	bw.show_tip(bw.slot_ctrl(v[0][0], v[0][1]))
	var rows := ""
	for r: Array in bw.tip.info.get("rows", []):
		rows += "%s %s | " % [r[0], r[1]]
	check(bw.tip.visible and String(bw.tip.info.name) == "Venison" and rows.contains("Stack 5") and bw.tip.size.y > 60.0,
			"venison's tooltip: its name, its rows (%s)" % rows)
	add("blanket_roll", 1)
	var pm: Array = where("blanket_roll")
	bw.show_tip(bw.slot_ctrl(pm[0][0], pm[0][1]))
	rows = ""
	for r: Array in bw.tip.info.get("rows", []):
		rows += "%s %s | " % [r[0], r[1]]
	check(String(bw.tip.info.name) == "Blanket Roll" and rows.contains("10 slots") and rows.contains("Holds anything"),
			"a bag's: its slots and what it holds (%s)" % rows)
	bw._hide_tip()
	set_count("blanket_roll", 0)


# --- the Tab screen ------------------------------------------------------------------------------------------------

func _tab_checks() -> void:
	bw.close_all()
	var ms := hb.slot_of(Hotbar.WEAPON, "musket")
	hb.clear(ms)
	await frames(4)
	add("knapsack", 1)
	var scr := InventoryScreen.open_for(p)
	await pframes(4)
	var hv: BagGrid = scr._grids.get(0)
	var sa: BagGrid = scr._grids.get(1)
	check(hv != null and hv.visible and hv.slots.size() == 16 and sa != null and sa.visible and sa.slots.size() == 8
			and hv.slots[0] is InventoryScreen.PackCell and absf(hv.slots[0].size.x - BagUI.SLOT_TAB) < 0.5,
			"the Tab screen's pack: the haversack's 16 slots and the satchel's 8 (PackCell, %d px)" % int(BagUI.SLOT_TAB))
	var cell: BagSlot = null
	for gr: BagGrid in scr._grids.values():
		for c: BagSlot in gr.slots:
			if c.kind == "musket":
				cell = c
	check(cell != null, "the musket off the bar lies in a slot there")
	if cell != null:
		var d: Variant = scr.slot_drag(cell)
		check(d is Dictionary and scr.figure._can_drop_data(Vector2.ZERO, d), "its drag goes onto the figure (%s)" % scr.fig_hint.text)
		scr.figure._drop_data(Vector2.ZERO, d)
		check(hb.slot_of(Hotbar.WEAPON, "musket") >= 0, "dropped: on the hotbar")
		# a move between slots
		var v: Array = where("venison")
		var to := free_any()
		var tg: BagGrid = scr._grids.get(to[0])
		scr.slot_drop(tg.slots[to[1]], BagUI.slot_payload(g, v[0][0], v[0][1]))
		check(String(g.slot(to[0], to[1]).get("kind", "")) == "venison" and tg.slots[to[1]].kind == "venison", "venison moved between slots there")
	var kn: Array = where("knapsack")
	var kc: BagSlot = (scr._grids.get(kn[0][0]) as BagGrid).slots[kn[0][1]] if not kn.is_empty() else null
	if kc != null:
		var free_socket := g.sockets.find("")
		scr.slot_double_click(kc)
		check(free_socket < 0 or (g.sockets[free_socket] == "knapsack" and scr.inv.pack_count("knapsack") == count("knapsack")),
				"a knapsack double-clicked there: on (%s), the screen's pack following" % str(g.sockets))
	scr.close()
	await frames(4)
	paused = false
	await frames(4)
	check(count("venison") == 5 and hb.slot_of(Hotbar.WEAPON, "musket") >= 0, "closed: the pack as it was left")


# --- the minimal HUD -----------------------------------------------------------------------------------------------

func _minimal_checks() -> void:
	hud.apply_style(ClassicSkin.MINIMAL)
	await pframes(2)
	var w := BagWindows.of(hud)
	check(hud.classic == null and w == bw, "minimal: the bag windows stay on the HUD")
	bw.toggle_all()
	await pframes(2)
	var hv := bw.window(0)
	var vp := hv.get_viewport_rect().size
	check(bw.is_open(0) and hv.visible and vp.x - hv.get_global_rect().end.x < 30.0 and Rect2(Vector2.ZERO, vp).encloses(hv.get_global_rect()),
			"minimal: M opens them at the bottom right too")
	bw.close_all()
	hud.apply_style(ClassicSkin.CLASSIC)
	await pframes(2)
