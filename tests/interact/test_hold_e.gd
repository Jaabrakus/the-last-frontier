extends SceneTree
## Look to pick and the hold-E list (scripts/interact/player_interactor.gd), in the real level with the real keys,
## headless:
##
##   Godot --headless --path . -s tests/interact/test_hold_e.gd
##
##   look     of two things in reach, the one the crosshair is on is highlighted, though the other is nearer and
##            straighter ahead; looking away, the nearer one again
##   item     a torch on the ground in reach is highlighted before the nearer thing, looking at neither
##   tap      a tap of E does the highlighted thing at once; "Hold E: 2 more" under the prompt
##   list     held, the list: the highlighted thing first, then the rest; the mouse wheel moves along it (round the
##            ends, the weapon not switched), the chosen one glows, letting go of E does it; the right mouse button
##            puts it away and letting go then does nothing
##   weapon   a musket in the hands: the first row puts it down, chosen at first, the placement showing; a hold and let
##            go puts it down as before; with nothing in reach a hold is the placement, no list
##   fire     a lit campfire with wood in the pack lists "Add firewood" and "Smother the fire"; the second smothers it

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var it: PlayerInteractor
var mode: BuildMode


## A thing to interact with: a box with a name, and extra actions for the list.
class Stub:
	extends StaticBody3D
	var label := ""
	var extra: Array = []
	var did: Array = []
	var interact_reach := 2.4

	func _init(l: String, x: Array = []) -> void:
		label = l
		extra = x
		name = l
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.5, 1.4, 0.5)
		cs.shape = bs
		cs.position = Vector3(0, 0.7, 0)
		add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		mi.position = cs.position
		add_child(mi)
		add_to_group(PlacedWeapon.GROUP)

	func interact_point() -> Vector3:
		return global_position + Vector3.UP * 0.5

	func interact_prompt(_p: Node) -> String:
		return label

	func highlight_targets() -> Array:
		return find_children("*", "MeshInstance3D", true, false)

	func interact(_p: Node) -> void:
		did.append("tap")

	func interact_actions(_p: Node) -> Array:
		var out: Array = [{"id": "", "text": label}]
		for x: String in extra:
			out.append({"id": x, "text": "%s %s" % [label, x]})
		return out

	func interact_action(_p: Node, id: String) -> void:
		did.append(id)

	func glows(mat: Material) -> bool:
		var m := find_children("*", "MeshInstance3D", true, false)
		return not m.is_empty() and (m[0] as MeshInstance3D).material_overlay == mat


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(t: float) -> void:
	await frames(int(t * Engine.physics_ticks_per_second))


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


func _tap_e() -> void:
	Input.action_press(&"interact")
	await frames(4)
	Input.action_release(&"interact")
	await frames(3)


## E down past the hold (the list up); let go with _let_go().
func _hold_e() -> void:
	Input.action_press(&"interact")
	await frames(int(ceil(PlayerInteractor.HOLD_S * Engine.physics_ticks_per_second)) + 6)


func _let_go() -> void:
	Input.action_release(&"interact")
	await frames(4)


## A key's action as an input event (the wheel and the right mouse button are read in _unhandled_input).
func _key(action: StringName) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)


func _rows() -> Array:
	return it.menu.map(func(r: Dictionary) -> String: return String(r.text))


func _run() -> void:
	for i in 10:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	check(player != null and player.interactor != null, "the player has the interactor")
	if player == null or player.interactor == null:
		_end()
		return
	player.ignore_mouse_capture = true
	it = player.interactor
	mode = player.get_node_or_null("BuildMode") as BuildMode
	await seconds(1.0)
	await _test_look_and_list()
	await _test_weapon()
	await _test_fire()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("HOLD E TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("HOLD E TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


var spot := Vector3(21.0, 0.0, 6.0)
var a: Stub
var b: Stub


func _stand() -> Vector3:
	var at := _ground(spot + Vector3(0, 0, 3.0)) + Vector3(0, 0.1, 0)
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = 0.0                 # facing -Z, toward the spot
	player.rotation.y = 0.0
	return at


func _test_look_and_list() -> void:
	if not player.hands_free:
		player.toggle_hands_free()
	await seconds(1.2)
	check(player.hands_free, "hands free for the list without the weapon's row")
	var at := _stand()
	b = Stub.new("Bravo")
	a = Stub.new("Alpha", ["again"])
	current_scene.add_child(b)
	current_scene.add_child(a)
	b.global_position = _ground(at + Vector3(0, 0, -2.0))    # farther, straight ahead
	a.global_position = _ground(at + Vector3(0.25, 0, -0.9))  # nearer, a little to the right
	# pitch the view down till the crosshair is on the far one (the camera stands high behind the player)
	var on := false
	for i in 20:
		player.pitch = deg_to_rad(-10.0 - 2.0 * i)
		await frames(4)
		var lk := it._look_hit()
		if it._look_at(b, b.interact_point(), lk) > 0.0 and it._look_at(a, a.interact_point(), lk) == 0.0:
			on = true
			break
	check(on, "the crosshair can be put on the far one alone (pitch %.0f)" % rad_to_deg(player.pitch))
	if not on:
		return
	# look: the crosshair on the far one picks it
	var chest := it._chest()
	var fwd := it._view_dir()
	var fh := Vector3(fwd.x, 0, fwd.z).normalized()
	var sa := it._score(a.interact_point(), chest, fh, chest.distance_to(a.interact_point()), a.interact_reach)
	var sb := it._score(b.interact_point(), chest, fh, chest.distance_to(b.interact_point()), b.interact_reach)
	var look := it._look_hit()
	check(sa < sb, "the near one is the better pick by place alone (%.2f against %.2f)" % [sa, sb])
	check(it._look_at(b, b.interact_point(), look) > 0.0 and it._look_at(a, a.interact_point(), look) == 0.0,
			"the crosshair is on the far one only (%s)" % [look.get("collider")])
	check(it.target == b and b.glows(it._hl_mat), "looked at, the far one glows (%s)" % [it.target])
	check(it._label.text.ends_with("Bravo"), "the prompt names it: '%s'" % it._label.text)
	check(it._more.text == "Hold E: 2 more", "under it: '%s'" % it._more.text)
	# tap
	await _tap_e()
	check(b.did == ["tap"] and a.did.is_empty(), "a tap does the highlighted one (%s, %s)" % [b.did, a.did])
	# the list
	var key := player.weapon_key
	await _hold_e()
	check(_rows() == ["Bravo", "Alpha", "Alpha again"], "held: the list, the highlighted first (%s)" % [_rows()])
	check(it._menu_box.visible and it._label.text == "" and it._more.text == "", "the list in the prompt's place")
	check(it.menu_i == 0 and it.target == b, "the first row chosen, its thing glowing")
	await _key(&"weapon_next")
	check(it.menu_i == 1 and it.target == a and a.glows(it._hl_mat) and not b.glows(it._hl_mat),
			"the wheel moves down: the other one glows (%d, %s)" % [it.menu_i, it.target])
	await _key(&"weapon_next")
	check(it.menu_i == 2 and it.target == a, "and down again (%d)" % it.menu_i)
	check(player.weapon_key == key, "the weapon is not switched under the list (%s)" % player.weapon_key)
	await _let_go()
	check(a.did == ["again"] and b.did == ["tap"], "letting go does the chosen one (%s, %s)" % [a.did, b.did])
	check(not it._menu_box.visible and it.menu.is_empty(), "and the list goes")
	await frames(4)
	# round the top, then put away
	await _hold_e()
	await _key(&"weapon_prev")
	check(it.menu_i == 2, "the wheel up from the top comes round to the bottom (%d)" % it.menu_i)
	await _key(&"aim")
	check(it.menu.is_empty() and not it._menu_box.visible, "the right mouse button puts the list away")
	await _let_go()
	check(a.did == ["again"] and b.did == ["tap"], "letting go then does nothing (%s, %s)" % [a.did, b.did])
	# looking up and away, the near one again
	player.pitch = deg_to_rad(25.0)
	await frames(6)
	check(it.target == a, "looking away, the nearer one is picked (%s)" % [it.target])
	# items highlight first: a torch lying a little farther off is highlighted before the nearer thing
	var tp := _ground(player.global_position + Vector3(-0.5, 0, -1.3)) + Vector3(0, 0.05, 0)
	var dt := DroppedTorch.spawn(current_scene, Transform3D(Basis(Vector3.UP, 0.4), tp), Vector3.ZERO, Vector3.ZERO,
			TorchState.new())
	dt.freeze = true
	await frames(6)
	check(it.target == dt, "an item to pick up is highlighted first (%s)" % [it.target])
	dt.queue_free()
	await frames(4)


func _test_weapon() -> void:
	if a == null or b == null:
		return
	player.toggle_hands_free()
	await seconds(1.5)
	var key := player.weapon_key
	check(not player.hands_free and key != "" and player.is_carried(key), "a weapon in the hands (%s)" % key)
	player.pitch = deg_to_rad(-20.0)
	await frames(6)
	await _hold_e()
	check(not it.menu.is_empty() and String(it.menu[0].id) == "place" and it.menu_i == 0,
			"held with a weapon: the first row puts it down, chosen (%s)" % [_rows()])
	check(it._placing and it._ghost != null and it._ghost.visible, "the placement shows while it is chosen")
	check(_rows().size() == 4, "the things in reach under it (%s)" % [_rows()])
	if _rows().size() < 2:
		await _let_go()
		return
	var row0 := ((it._menu_rows.get_child(0) as HBoxContainer).get_child(1) as Label).text
	check(row0 == String(it.place.get("what", "?")), "the row says where it goes: '%s'" % row0)
	await _key(&"weapon_next")
	check(not it._placing and not it._ghost.visible and it.target == it.menu[1].node and (it.menu[1].node as Stub).glows(it._hl_mat),
			"another row: no placement, that thing glows (%s)" % [it.target])
	await _key(&"weapon_prev")
	await frames(2)
	check(it._placing and it._ghost.visible, "back on the first: the placement again")
	await _let_go()
	var pw := _placed(key)
	check(pw != null and not player.is_carried(key), "letting go puts the weapon down (%s)" % [pw])
	check(a.did == ["again"] and b.did == ["tap"], "and nothing else is done")
	if pw:
		pw.interact(player)
		await seconds(1.5)
	# nothing in reach: the placement, no list
	a.queue_free()
	b.queue_free()
	await frames(4)
	check(player.is_carried(key) and player.weapon_key == key, "taken back up (%s)" % player.weapon_key)
	await _hold_e()
	check(it.menu.is_empty() and it._placing and it._label.text.begins_with("Release"),
			"nothing in reach: a hold is the placement, no list ('%s')" % it._label.text)
	await _let_go()
	pw = _placed(key)
	check(pw != null and not player.is_carried(key), "and letting go puts it down")
	if pw:
		pw.interact(player)
		await seconds(1.5)


func _placed(key: String) -> PlacedWeapon:
	for n in get_nodes_in_group(PlacedWeapon.GROUP):
		var pw := n as PlacedWeapon
		if pw and pw.key == key and pw.rack == null and pw.global_position.distance_to(player.global_position) < 4.0:
			return pw
	return null


func _test_fire() -> void:
	if mode == null:
		check(false, "the player has build mode")
		return
	var inv := InventoryState.from_player(player)
	inv.add("stone", 6)
	inv.add("firewood", 6)
	player.inventory_pack = inv.pack.duplicate(true)
	var fire_at := _ground(spot)
	_stand()
	await seconds(0.3)
	mode.set_active(true)
	mode.select_type("campfire")
	mode.aim_at = fire_at
	await frames(6)
	mode.refresh_placement()
	var fp := mode.place()
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	var cf := fp.get_node_or_null("Campfire") as Campfire if fp else null
	check(cf != null, "a campfire is built")
	if cf == null:
		return
	cf.interact(player)
	await seconds(1.5)
	check(cf.is_lit(), "lit")
	if not player.hands_free:
		player.toggle_hands_free()
	await seconds(1.2)
	player.global_position = _ground(fire_at + Vector3(0, 0, 1.6)) + Vector3(0, 0.1, 0)
	player.pitch = deg_to_rad(-25.0)
	await frames(8)
	check(it.target == cf, "the fire is highlighted (%s)" % [it.target])
	check(it._more.text == "Hold E: 1 more", "under the prompt: '%s' (cands %s, actions %s)" % [it._more.text, it._cands, cf.interact_actions(player)])
	await _hold_e()
	var rows := _rows()
	check(rows.size() == 2 and (rows[0] as String).begins_with("Add firewood") and rows[1] == "Smother the fire",
			"the fire's two: %s" % [rows])
	check(not (rows[0] as String).contains("Cook"), "without the prompt's cooking hint")
	await _key(&"weapon_next")
	await _let_go()
	check(not cf.is_lit(), "the second chosen: smothered")
