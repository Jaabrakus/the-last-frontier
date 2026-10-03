extends SceneTree
## Taken captive in the level (Captivity; docs/research/codebase_story_audit.md item 6), survival and saves on:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_captivity.gd -- survival=on save=on
##   taken    begin() takes the weapons and the tool off the body, the pack, the torches, the coin and the kit into the
##            store; the weapon in the hands is put away and none can be drawn again (a key, H, the wheel), no tool comes
##            out, B does not build, F1 does not lift the camera (not even for a frame), and the walk is all (no sprint)
##   follow   a stand-in captor (a plain Node3D) leads a forced march while the player keeps up: it goes on along the
##            route and the clock and hunger move on with it; fallen behind it waits and looks back, further off it
##            turns back
##   save     a save while captive and a load: the store, the bonds and the march come back; no tool handed out anew;
##            the story is told (a WATCHERS node); with no captor the player walks the rest of the march alone, then
##            nobody holds them and the bonds come off; follow() puts them on again
##   escape   past the far distance: `escaped`, the bonds off
##   end      end() gives it all back: the pack, the weapons on the body and drawable, the torches, the coin, the kit;
##            drop_store() leaves the pack lying in a PackDrop that E takes back, the tool in it not handed out twice;
##            end(true, parts) keeps the rest: a tool the captors keep is not handed out again on an inventory close
##   walk     walking away on foot (no teleport): the captor turns back slower than the walk and the leash breaks
##   horse    a captive who mounts a horse is down again at once
##   gone     the captor freed: still bound a while, then nobody holds them (no escape)
##   death    dying captive is no escape: `captive_died`; on_death "keep" wakes still bound beside the captor, "end" (the
##            default) the captors keep it all; no weapon in the hands either way
## Ends with "CAPTIVITY TEST PASSED (<n> checks)" or "CAPTIVITY TEST FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var sg: SaveGame
var player: FrontierPlayer
var cap: Captivity
var escaped_at := Vector3.INF
var rts_seen := false
var march_done_seen := false
var died_seen := false
var watcher: Watcher
## Where the march starts and the way it goes.
var start := Vector3(70.0, 0.0, 70.0)
var dir := Vector3(0.0, 0.0, -1.0)


## A story's node told after a load (Captivity.WATCHERS).
class Watcher extends Node:
	var got: Node = null

	func captivity_restored(c: Node) -> void:
		got = c


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


func _put_player(p: Vector3) -> void:
	player.global_position = _ground(p) + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO


func _grab() -> void:
	sg = SaveGame.find(self)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	cap = Captivity.find(self)
	if player:
		player.ignore_mouse_capture = true
		if player.rts and not player.rts.changed.is_connected(_on_rts):
			player.rts.changed.connect(_on_rts)


## The things in a pack (not the torches, nor the weapons' own entries).
func _pack_n(pack: Array) -> int:
	var n := 0
	for e: Dictionary in pack:
		var k := String(e.get("kind", ""))
		if k != InventoryState.TORCH and not InventoryState._derived(k):
			n += int(e.get("count", 1))
	return n


## How many of `kind` are in the player's pack.
func _kind_n(kind: String) -> int:
	var n := 0
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) == kind:
			n += int(e.get("count", 1))
	return n


func _derived_n(pack: Array) -> int:
	var n := 0
	for e: Dictionary in pack:
		if InventoryState._derived(String(e.get("kind", ""))):
			n += 1
	return n


func _carried() -> Array:
	var out := []
	for k: String in player.weapons:
		if player.is_carried(k):
			out.append(k)
	out.sort()
	return out


func _kit_n() -> int:
	var n := 0
	for st: Dictionary in b.core.state.inventory:
		if not b.core.state.worn.has(String(st.id)):
			n += 1
	return n


func _on_escaped(at: Vector3) -> void:
	escaped_at = at


func _on_rts(on: bool) -> void:
	if on:
		rts_seen = true


func _on_march_done() -> void:
	march_done_seen = true


func _on_captive_died() -> void:
	died_seen = true


func _captor(at: Vector3) -> Node3D:
	var c := Node3D.new()
	c.name = "Captor"
	current_scene.add_child(c)
	c.global_position = _ground(at)
	return c


## F1 pressed and let go (through the viewport, as a key would come).
func _press_f1() -> void:
	for on in [true, false]:
		var ev := InputEventAction.new()
		ev.action = RtsMode.ACTION
		ev.pressed = on
		root.push_input(ev)
		await _frames(2)


## The inventory screen closed (a new Loadout: GatherTools hands out every tool that is neither worn, packed nor lost).
func _tab_close() -> void:
	player.apply_loadout(player.loadout.copy(), player.inventory_pack)
	await _frames(4)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await _frames(60)
	_grab()
	_expect(b != null and sg != null and player != null, "the level has the bridge, the saves and the player (survival=on save=on)")
	if b == null or sg == null or player == null:
		_end()
		return
	_expect("captivity" in SaveGame.PARTS and SaveGame.PARTS.find("captivity") > SaveGame.PARTS.find("player"),
			"the save has a captivity part, applied after the player's")
	_expect(Captivity._notice_for(["weapons", "pack", "coin"]) == "You are taken. Your weapons, your pack and your coin are gone."
			and Captivity._notice_for(["coin"]) == "You are taken. Your coin is gone.", "the notice names the parts taken")
	# ---- something in every part: a pack, a spare torch, coin
	player.gather.give("stone", 3)
	player.torch.add_torches(1)
	SurvivalEconomy._add_money(b.core, 120.0)
	_put_player(start + Vector3(0, 0, 2.0))
	await _frames(20)
	var pack0 := _pack_n(player.inventory_pack)
	var keys0 := _carried()
	var items0 := player.loadout.items.size()
	var torches0 := player.torch.count()
	var coin0 := SurvivalEconomy.money(b.core)
	var kit0 := _kit_n()
	print("  (before: pack %d, weapons %s, on the body %d, torches %d, coin %d, kit stacks %d, in the hands %s%s)" % [pack0,
			str(keys0), items0, torches0, coin0, kit0, player.weapon_key, " (slung)" if player.hands_free else ""])
	_expect(pack0 > 0 and not keys0.is_empty() and items0 > 0 and torches0 > 0 and coin0 > 0, "the player has a pack, weapons, torches and coin")
	if not player.hands_free:
		player.toggle_hands_free()
		await _frames(40)
	player.switch_weapon(String(keys0[0]))
	await _frames(70)
	_expect(player.weapon.active and not player.hands_free, "a weapon is drawn before (%s)" % player.weapon_key)
	# the sprint, free
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(20)
	var sprint_free := player.is_sprinting
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await _frames(10)
	_expect(sprint_free, "free, the player can sprint")
	# F1, free: the command mode comes up (and goes again)
	rts_seen = false
	await _press_f1()
	var f1_free := rts_seen
	if player.rts and player.rts.active:
		await _press_f1()
	if player.rts and player.rts.active:
		player.rts.set_active(false)
	rts_seen = false
	_expect(f1_free, "free, F1 lifts the camera into command mode")
	# ---- taken
	_put_player(start + Vector3(0, 0, 2.0))
	await _frames(5)
	var captor := _captor(start)
	var route := [start + dir * 25.0, start + dir * 50.0]
	cap = Captivity.install(current_scene)
	cap.escaped.connect(_on_escaped)
	var min0 := b.core.state.minutes
	var ok := cap.begin(player, captor, {"route": route, "march_hours": 8.0, "hunger_mult": 1.5})
	await _frames(3)
	_expect(ok and cap.is_active() and cap.bound, "begin(): taken and bound")
	_expect(_pack_n(player.inventory_pack) == 0 and _pack_n(cap.store.get("pack", [])) == pack0, "the pack is emptied into the store (%d)" % _pack_n(cap.store.get("pack", [])))
	_expect(_derived_n(player.inventory_pack) == 0 and _derived_n(cap.store.weapons.get("pack", [])) > 0,
			"the weapons' own pack entries went with the weapons (%d)" % _derived_n(cap.store.weapons.get("pack", [])))
	_expect(_carried().is_empty() and (cap.store.weapons["keys"] as Array).size() == keys0.size(), "every weapon taken (%s)" % str(cap.store.weapons["keys"]))
	_expect(player.loadout.items.is_empty(), "nothing left on the body: the slings and the tool loop empty (%d held)"
			% ((cap.store.weapons.items as Array).size() + (cap.store.tools.items as Array).size()))
	_expect(player.torch.count() == 0 and (cap.store.torches as Array).size() == torches0, "the torches taken")
	_expect(SurvivalEconomy.money(b.core) == 0 and int(cap.store.coin) == coin0, "the coin taken (%d)" % int(cap.store.coin))
	var kit_held := (cap.store.kit as Array).size()
	var worn_ok := not b.core.state.worn.is_empty()
	for id in b.core.state.worn:
		if absf(SurvivalInventory.count(b.core, String(id)) - float(b.core.state.worn.count(id))) > 0.001:
			worn_ok = false
	_expect(_kit_n() == 0 and kit_held >= kit0 and worn_ok, "the kit taken (%d stacks, %d of them spares of what is worn), the clothes worn kept, no more"
			% [kit_held, kit_held - kit0])
	await _frames(40)
	_expect(player.hands_free and not player.weapon.active, "the weapon in the hands put away")
	# ---- nothing can be drawn
	for k: String in keys0:
		player.switch_weapon(k)
		await _frames(2)
	player.toggle_hands_free()
	player._wheel_step(1)
	player.gather.toggle(GatherTools.AXE)
	await _frames(60)
	_expect(player.hands_free and not player.weapon.active and player.gather.in_hand() == "", "no weapon (a key, H, the wheel) and no tool comes into the hands")
	_expect(not player.is_usable(String(keys0[0])), "is_usable() is false for a held weapon")
	Input.action_press(BuildMode.ACTION)
	await _frames(4)
	Input.action_release(BuildMode.ACTION)
	await _frames(2)
	_expect(not player.building.active, "B does not open build mode")
	rts_seen = false
	await _press_f1()
	_expect(not rts_seen and not (player.rts and player.rts.active), "F1 does not open command mode, not even for a frame")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(20)
	_expect(not player.is_sprinting and player.target_speed <= cap.speed_cap + 0.01, "the walk only: no sprint, %.2f m/s at most" % player.target_speed)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await _frames(5)
	# ---- the forced march: kept up with
	var c0 := captor.global_position
	var hunger0 := float(b.core.state.needs.stomach) + float(b.core.state.needs.reserve)
	min0 = b.core.state.minutes
	for i in int(2.5 * Engine.physics_ticks_per_second):
		_put_player(captor.global_position - dir * 2.5)
		await physics_frame
	var moved := Vector2(captor.global_position.x - c0.x, captor.global_position.z - c0.z).dot(Vector2(dir.x, dir.z))
	var dm := b.core.state.minutes - min0
	var hunger1 := float(b.core.state.needs.stomach) + float(b.core.state.needs.reserve)
	_expect(cap.leash == "close" and moved > 2.0 and cap.march_m > 2.0, "kept up with, the captor leads along the route (%.1f m, %.1f m of the march)" % [moved, cap.march_m])
	_expect(dm > 15.0, "the march moves the clock on (%.0f game min in 2.5 s)" % dm)
	_expect(hunger1 < hunger0, "and hunger with it (%.0f kcal)" % (hunger0 - hunger1))
	# ---- fallen behind: it waits and looks back
	_put_player(captor.global_position - dir * 9.0)
	await _frames(3)
	var c1 := captor.global_position
	await _frames(30)
	var to_p := (player.global_position - captor.global_position)
	to_p.y = 0.0
	var facing := -captor.global_basis.z
	_expect(cap.leash == "waiting" and c1.distance_to(captor.global_position) < 0.02, "9 m behind: the captor waits (%s)" % cap.leash)
	_expect(facing.dot(to_p.normalized()) > 0.95, "and looks back at the player")
	# ---- further: it turns back, slower than the captive's walk
	_put_player(captor.global_position - dir * 20.0)
	await _frames(3)
	var d0 := Captivity._flat(player.global_position, captor.global_position)
	var cb0 := captor.global_position
	var pb0 := player.global_position
	await _frames(40)
	var d1 := Captivity._flat(player.global_position, captor.global_position)
	var to_pl := Vector2(pb0.x - cb0.x, pb0.z - cb0.z).normalized()
	var came_back := Vector2(captor.global_position.x - cb0.x, captor.global_position.z - cb0.z).dot(to_pl)
	var want_back := cap.turn_back_speed * 40.0 / Engine.physics_ticks_per_second
	_expect(cap.leash == "turning_back" and came_back > want_back * 0.9 and d1 < d0 - want_back * 0.9,
			"20 m behind: the captor turns back (%.2f m toward the player in 40 ticks, %.2f at its pace; %.1f -> %.1f m)" % [came_back, want_back, d0, d1])
	_expect(cap.turn_back_speed < cap.speed_cap - 0.1, "at %.2f m/s, under the captive's walk (%.2f)" % [cap.turn_back_speed, cap.speed_cap])
	_expect(escaped_at == Vector3.INF, "no escape yet")
	# ---- a save while captive, and a load
	var march_m := cap.march_m
	var route_i := cap.route_i
	_expect(sg.save_game("quick") == OK, "saved (quick)")
	var part: Dictionary = (SaveGame.read_slot("quick").get("parts", {}) as Dictionary).get("captivity", {})
	_expect(bool(part.get("active", false)) and (part.get("store", {}) as Dictionary).has("pack"), "the save holds the captivity and its store")
	await _load()
	_expect(cap != null and cap.is_active() and cap.bound and cap.holding("pack") and cap.holding("weapons") and cap.holding("coin"),
			"after the load: still captive and bound, the store held")
	if cap == null or player == null:
		_end()
		return
	cap.escaped.connect(_on_escaped)
	cap.march_done.connect(_on_march_done)
	_expect(watcher != null and watcher.got == cap, "the story is told after the load (captivity_restored on a WATCHERS node)")
	_expect(_pack_n(cap.store.get("pack", [])) == pack0 and (cap.store.weapons["keys"] as Array).size() == keys0.size() and int(cap.store.coin) == coin0
			and (cap.store.torches as Array).size() == torches0 and (cap.store.kit as Array).size() == kit_held, "the store's parts all came back")
	await _frames(30)
	var tools_back := false
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) in [GatherTools.AXE, "mattock"]:
			tools_back = true
	_expect(_pack_n(player.inventory_pack) == 0 and _carried().is_empty() and not tools_back and player.torch.count() == 0,
			"the player still has nothing (no tool handed out by the new level)")
	_expect(player.building.process_mode == Node.PROCESS_MODE_DISABLED and is_equal_approx(player.drag_speed_cap, cap.speed_cap),
			"the bonds are back: no building, the walk")
	player.switch_weapon(String(keys0[0]))
	await _frames(40)
	_expect(player.hands_free or not player.weapon.active, "still no weapon drawn")
	_expect(cap.marching and cap.route_i == route_i and is_equal_approx(cap.march_m, march_m), "the march is where it was (%.1f m)" % cap.march_m)
	_expect(cap.leash == "no_captor", "the stand-in captor was not in the save: no captor until follow()")
	# ---- no captor: the player walks the rest of the march, then nobody holds them
	for i in range(cap.route_i, cap.route.size()):
		_put_player(cap.route[i])
		await _frames(3)
	_expect(march_done_seen and not cap.marching and cap.bound, "no captor: the player walks the rest of the march alone (march_done), still bound")
	await _frames(int((Captivity.NO_CAPTOR_GRACE_S + 0.5) * Engine.physics_ticks_per_second))
	_expect(cap.is_active() and not cap.bound and player.building.process_mode != Node.PROCESS_MODE_DISABLED and player.drag_speed_cap == INF
			and cap.holding("pack"), "and with nobody holding them the bonds come off after %.0f s (the store still held)" % Captivity.NO_CAPTOR_GRACE_S)
	# ---- a captor again, and the escape
	var captor2 := _captor(player.global_position + dir * 3.0)
	cap.follow(captor2)
	await _frames(5)
	_expect(cap.leash == "close" and cap.bound and player.building.process_mode == Node.PROCESS_MODE_DISABLED
			and is_equal_approx(player.drag_speed_cap, cap.speed_cap), "follow(): led again, and bound again")
	_put_player(captor2.global_position - dir * 50.0)
	await _frames(5)
	_expect(escaped_at != Vector3.INF and cap.has_escaped and cap.leash == "escaped", "50 m off: escaped")
	_expect(not cap.bound and player.drag_speed_cap == INF and player.building.process_mode != Node.PROCESS_MODE_DISABLED,
			"the bonds are off after the escape; the store is still held (%s)" % str(cap.store.keys()))
	# ---- the end: everything back
	var left := cap.end()
	await _frames(5)
	_expect(left.is_empty() and not cap.is_active(), "end(): over, nothing left held")
	_expect(_pack_n(player.inventory_pack) == pack0, "the pack back (%d)" % _pack_n(player.inventory_pack))
	_expect(_carried() == keys0 and player.loadout.items.size() == items0, "the weapons back on the body (%s, %d items)" % [str(_carried()), player.loadout.items.size()])
	_expect(player.torch.count() == torches0 and SurvivalEconomy.money(b.core) == coin0 and _kit_n() == kit0, "the torches, the coin and the kit back")
	_expect(player.gather.lost.is_empty() and player.gather.owns(GatherTools.AXE), "the felling axe is the player's again")
	player.switch_weapon(String(keys0[0]))
	await _frames(70)
	_expect(player.weapon.active and not player.hands_free, "a weapon can be drawn again (%s)" % player.weapon_key)
	# ---- part of it: the pack left in the captors' camp
	var mattock0 := _kind_n("mattock")
	var ok2 := cap.begin(player, null, {"take": ["pack", "torches"], "notice": ""})
	await _frames(3)
	var pd := cap.drop_store(player.global_position + Vector3(2, 0, 0))
	_expect(ok2 and pd != null and pd.count() == pack0 + torches0 and not cap.holding("pack"), "drop_store(): the pack and torches left in a PackDrop (%d things)" % (pd.count() if pd else -1))
	left = cap.end()
	await _tab_close()
	_expect(_kind_n("mattock") == 0, "the mattock lying in it is not handed out again meanwhile (an inventory close)")
	if pd:
		pd.interact(player)
	await _frames(3)
	_expect(left.is_empty() and _pack_n(player.inventory_pack) == pack0 and player.torch.count() == torches0,
			"E on it takes the pack back (%d things, %d torches)" % [_pack_n(player.inventory_pack), player.torch.count()])
	_expect(mattock0 == 1 and _kind_n("mattock") == 1 and not player.gather.lost.has("mattock"), "one mattock, the player's again (%d)" % _kind_n("mattock"))
	# ---- end(true, parts): the tools kept by the captors stay gone
	var ok3 := cap.begin(player, null, {"notice": ""})
	await _frames(3)
	var left3 := cap.end(true, ["weapons", "pack", "torches", "coin", "kit"])
	await _tab_close()
	_expect(ok3 and left3.size() == 1 and left3.has("tools"), "end(true, all but the tools): the tools still held (%s)" % str(left3.keys()))
	_expect(player.gather.on_loop == "" and _kind_n(GatherTools.AXE) == 0 and player.gather.lost.has(GatherTools.AXE),
			"the felling axe the captors kept is not handed out again on an inventory close")
	_expect(_kind_n("mattock") == 1 and not player.gather.lost.has("mattock") and _carried() == keys0, "the rest is the player's again")
	# ---- walking away on foot (no teleport): the captor turns back slower than the walk
	var wdir := Vector3(0.0, 0.0, 1.0)
	_put_player(start + Vector3(0, 0, 6.0))
	player.yaw = atan2(-wdir.x, -wdir.z)
	await _frames(10)
	if not player.hands_free:
		player.toggle_hands_free()
		await _frames(40)
	var captor3 := _captor(player.global_position - wdir * 2.0)
	escaped_at = Vector3.INF
	var ok4 := cap.begin(player, captor3, {"take": [], "leash_m": 3.0, "turn_back_m": 5.0, "escape_m": 12.0, "notice": ""})
	var c3 := captor3.global_position
	var p3 := player.global_position
	var saw_back := false
	var top := 0.0
	var n := 0
	Input.action_press(&"move_forward")
	while escaped_at == Vector3.INF and n < 40 * Engine.physics_ticks_per_second:
		player.yaw = atan2(-wdir.x, -wdir.z)
		await physics_frame
		n += 1
		saw_back = saw_back or cap.leash == "turning_back"
		top = maxf(top, Vector2(player.velocity.x, player.velocity.z).length())
	Input.action_release(&"move_forward")
	var secs := float(n) / Engine.physics_ticks_per_second
	var walked := Captivity._flat(player.global_position, p3)
	var came := Captivity._flat(captor3.global_position, c3)
	_expect(ok4 and escaped_at != Vector3.INF and saw_back and came > 2.0,
			"walked away (no teleport): it turned back (%.1f m) but the leash broke at 12 m (%.1f s, %.1f m walked)" % [came, secs, walked])
	_expect(top <= cap.speed_cap + 0.05, "at the walk the whole way (%.2f m/s at most)" % top)
	cap.end()
	await _frames(5)
	# ---- a horse: down again at once
	var horse: Horse = null
	for h in current_scene.find_children("*", "Horse", true, false):
		if h is Horse and (h as Horse).get_node_or_null("Mount") != null:
			horse = h as Horse
			break
	_expect(horse != null, "the level has a horse to try")
	if horse:
		cap.begin(player, null, {"take": [], "notice": ""})
		await _frames(3)
		var mounted := player.mount(horse)
		await _frames(3)
		_expect(mounted and player.riding == null and horse.get_node("Mount").get("rider") == null, "a captive who mounts a horse is down again at once")
		cap.end()
		await _frames(5)
	# ---- the captor gone (freed): nobody holds them after the grace, and it is no escape
	_put_player(start + Vector3(0, 0, 4.0))
	await _frames(5)
	var captor5 := _captor(player.global_position + Vector3(2, 0, 0))
	escaped_at = Vector3.INF
	cap.begin(player, captor5, {"take": [], "notice": ""})
	await _frames(5)
	captor5.queue_free()
	await _frames(int(Captivity.NO_CAPTOR_GRACE_S * 0.5 * Engine.physics_ticks_per_second))
	var still := cap.bound and cap.leash == "no_captor"
	await _frames(int((Captivity.NO_CAPTOR_GRACE_S * 0.5 + 0.3) * Engine.physics_ticks_per_second))
	_expect(still and cap.is_active() and not cap.bound and escaped_at == Vector3.INF,
			"the captor freed: still bound a while, then nobody holds them (the bonds off, no escape)")
	cap.end()
	await _frames(5)
	# ---- a debt is not coin
	var m0 := SurvivalEconomy.money(b.core)
	SurvivalEconomy._add_money(b.core, -float(m0) - 30.0)
	cap.begin(player, null, {"take": ["coin"], "notice": ""})
	var debt_held := int(cap.store.get("coin", -1))
	var debt_now := SurvivalEconomy.money(b.core)
	cap.end()
	_expect(debt_held == 0 and debt_now == -30 and SurvivalEconomy.money(b.core) == -30, "a debt is not coin: nothing taken, nothing given back")
	SurvivalEconomy._add_money(b.core, float(m0) + 30.0)
	# ---- death with on_death "keep": still captive where they wake, the captor beside them
	var dr := DeathRule.find(self)
	_put_player(start + Vector3(0, 0, 4.0))
	await _frames(5)
	var captor6 := _captor(player.global_position + Vector3(2, 0, 0))
	escaped_at = Vector3.INF
	died_seen = false
	cap.captive_died.connect(_on_captive_died)
	cap.begin(player, captor6, {"take": [], "on_death": "keep", "notice": ""})
	await _frames(5)
	player.health = 0.0
	player._die(Vector2.ZERO)
	await _frames(10)
	if dr:
		dr.respawn()
	else:
		player.respawn()
	await _frames(10)
	_expect(died_seen and escaped_at == Vector3.INF and cap.is_active() and cap.bound and cap.leash == "close"
			and Captivity._flat(player.global_position, captor6.global_position) < cap.leash_m and not player.weapon.active,
			"on_death \"keep\": woken still captive and bound, the captor beside them, no weapon in the hands")
	cap.end()
	await _frames(5)
	# ---- death: no escape, the captors keep it all
	_put_player(start + Vector3(0, 0, 4.0))
	await _frames(5)
	var captor4 := _captor(player.global_position + Vector3(2, 0, 0))
	escaped_at = Vector3.INF
	died_seen = false
	var ok5 := cap.begin(player, captor4, {"notice": ""})
	await _frames(5)
	player.health = 0.0
	player._die(Vector2.ZERO)
	await _frames(10)
	if dr:
		dr.respawn()
	else:
		player.respawn()
	await _frames(10)
	var far := Captivity._flat(player.global_position, captor4.global_position)
	_expect(ok5 and died_seen and escaped_at == Vector3.INF and not cap.is_active(),
			"died captive, woken %.0f m off: captive_died, no escape, the captivity over" % far)
	_expect(not player.weapon.active and _carried().is_empty() and _pack_n(player.inventory_pack) == 0, "no weapon in the hands; the captors kept the weapons and the pack")
	await _tab_close()
	_expect(_kind_n("mattock") == 0 and _kind_n(GatherTools.AXE) == 0 and player.gather.on_loop == "", "nor is a tool handed out again (an inventory close)")
	_end()


func _load() -> void:
	var old := sg
	var old_id := current_scene.get_instance_id()
	watcher = null
	_expect(sg.load_slot("quick"), "load_slot starts the load")
	for i in 60 * 10:
		await process_frame
		# (a story's node in the new level before the save is applied to it)
		if watcher == null and current_scene != null and current_scene.get_instance_id() != old_id:
			watcher = Watcher.new()
			watcher.name = "CaptivityWatcher"
			watcher.add_to_group(Captivity.WATCHERS)
			current_scene.add_child(watcher)
		var s2 := SaveGame.find(self)
		if s2 != null and s2 != old and not s2.loading and s2.level != null and s2.level.is_inside_tree():
			await _frames(12)
			break
	_grab()
	await _frames(5)


func _end() -> void:
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	# (the navigation tiles baking on the server's threads for the walkers round a player taken far and back are let
	# finish first: quitting under them aborts the engine on its way out)
	var nw := NavWorld.of(self) if current_scene else null
	var guard := 0
	while nw != null and is_instance_valid(nw) and nw.baking() > 0 and guard < 600:
		await process_frame
		guard += 1
	await _frames(10)
	# the test's saves (SaveGame.TEST_DIR, never the player's) go with it
	for s in SaveGame.SLOTS:
		DirAccess.remove_absolute(SaveGame.dir() + String(s) + ".json")
	if fails.is_empty():
		print("CAPTIVITY TEST PASSED (%d checks)" % checks)
	else:
		print("CAPTIVITY TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
