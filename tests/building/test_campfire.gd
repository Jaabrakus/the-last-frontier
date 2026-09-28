extends SceneTree
## The campfire and the brush lean-to (scripts/building: Campfire, BuildGeometry, BuildSnap), placed through build mode
## in the real level, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/building/test_campfire.gd
##
## The player starts with flint and steel; both pieces place for their cost; the fire lights, takes firewood, warms,
## counts as a fire for the wolves, drowns in heavy rain, smothers, burns out; the lean-to's slope keeps rain off what
## is under it. Ends with "CAMPFIRE TEST PASSED <n>" or "CAMPFIRE TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var mode: BuildMode


class FakeRain:
	extends Node
	var rain := 1.0

	func rain_intensity(_pos: Vector3) -> float:
		return rain


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func seconds(t: float) -> void:
	for i in int(t * Engine.physics_ticks_per_second):
		await physics_frame


func count(kind: String) -> int:
	return Campfire._pack_count(player, kind)


func give(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	player.inventory_pack = inv.pack.duplicate(true)


func place(type: String, at: Vector3) -> BuiltPiece:
	mode.set_active(true)
	mode.select_type(type)
	mode.aim_at = at
	for i in 6:
		await physics_frame
	mode.refresh_placement()
	var p := mode.place()
	if p == null:
		print("    place %s: aim=%s cand=%s verdict=%s" % [type, mode.aim.get("position", "-"), mode.cand.get("kind", "-"), mode.verdict.get("reason", "-")])
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	return p


func _run() -> void:
	for i in 10:
		await process_frame
	player = current_scene.get_node("Player")
	mode = player.get_node_or_null("BuildMode") as BuildMode
	check(mode != null, "the player has build mode")
	if mode == null:
		_end()
		return
	await seconds(0.5)
	check(count(Campfire.FIRE_STEEL) == 1, "the player starts with flint and steel")
	check(BuildData.get_default().order.has("campfire") and BuildData.get_default().order.has("lean_to"), "campfire and lean-to are build pieces")
	give("stone", 6)
	give("firewood", 6)
	give("pole", 5)
	give("branches", 10)
	var spot := Vector3(21.0, 0.0, 6.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	player.global_position = spot + Vector3(0, 0.1, 3.0)
	await seconds(0.3)
	var fp := await place("campfire", spot)
	check(fp != null and fp.type == "campfire", "a campfire is placed")
	if fp == null:
		_end()
		return
	check(count("stone") == 0 and count("firewood") == 2, "for 6 stone and 4 firewood (stone %d, firewood %d)" % [count("stone"), count("firewood")])
	var cf := fp.get_node_or_null("Campfire") as Campfire
	check(cf != null and not cf.is_lit() and cf.wood_left() == 4, "built unlit with the wood laid")
	check(cf.interact_prompt(player) == "Light the fire", "prompt: Light the fire ('%s')" % cf.interact_prompt(player))
	cf.interact(player)
	await seconds(1.5)
	check(cf.is_lit(), "E lights it (flint and steel)")
	check(cf.fire.is_in_group(TorchFire.GROUP) and cf.fire.state.lit, "a fire the wolves keep off (TorchFire, lit)")
	check(cf.fire.light.visible and cf.fire.light.omni_range > 10.0, "its light reaches far (%.1f m)" % cf.fire.light.omni_range)
	var near := Campfire.warmth_at(self, cf.global_position + Vector3(1.2, 0.5, 0))
	var far := Campfire.warmth_at(self, cf.global_position + Vector3(10.0, 0.5, 0))
	check(near > 0.7 and far == 0.0, "warm beside it, not 10 m off (%.2f, %.2f)" % [near, far])
	check(cf.interact_prompt(player).begins_with("Add firewood"), "burning: Add firewood ('%s')" % cf.interact_prompt(player))
	cf.interact(player)
	check(cf.wood_left() == 5 and count("firewood") == 1, "a stick onto the fire (%d laid, %d in the pack)" % [cf.wood_left(), count("firewood")])
	# heavy rain drowns an open fire
	var rain := FakeRain.new()
	rain.add_to_group(TorchState.WEATHER_GROUP)
	current_scene.add_child(rain)
	await seconds(14.0)
	check(not cf.is_lit() and cf.state.out_reason == "rain", "heavy rain puts it out (%s)" % cf.state.out_reason)
	rain.queue_free()
	await seconds(0.5)
	# lit again, smothered
	cf.state.wet = 0.0
	cf.interact(player)
	await seconds(1.0)
	check(cf.is_lit(), "lit again")
	var inv := InventoryState.from_player(player)
	inv.take("firewood", 9)
	player.inventory_pack = inv.pack.duplicate(true)
	check(cf.interact_prompt(player) == "Smother the fire", "with no wood to add: Smother the fire ('%s')" % cf.interact_prompt(player))
	cf.interact(player)
	check(not cf.is_lit(), "smothered")
	# burns out: then it wants wood
	cf.interact(player)
	cf.state.burn_left = 1.0
	await seconds(2.0)
	check(not cf.is_lit() and cf.state.out_reason == "burnt", "burns out (%s)" % cf.state.out_reason)
	check(cf.interact_prompt(player).begins_with("Lay firewood"), "then: Lay firewood ('%s')" % cf.interact_prompt(player))
	give("firewood", 1)
	cf.interact(player)
	check(cf.wood_left() == 1, "wood laid in the cold ring")
	# the lean-to, facing the fire
	var ls := spot + Vector3(0.0, 0.0, -3.5)
	ls.y = FrontierTerrain.height_at(ls.x, ls.z)
	var lp := await place("lean_to", ls)
	check(lp != null and lp.type == "lean_to", "a lean-to is placed")
	if lp:
		check(count("pole") == 0 and count("branches") == 0, "for 5 poles and 10 branches")
		check(lp.is_in_group(&"shelters"), "it is a shelter")
		var under := lp.global_transform * Vector3(0.0, 0.3, -1.0)
		check(TorchState.sheltered(lp.get_world_3d(), under), "its slope keeps the rain off under it")
		var front := lp.global_transform * Vector3(0.0, 0.3, 1.5)
		check(not TorchState.sheltered(lp.get_world_3d(), front), "open in front")
	# torches unchanged by the new size setting
	var tf := TorchFire.new()
	current_scene.add_child(tf)
	await process_frame
	check(is_equal_approx(tf.light.omni_range, TorchFire.LIGHT_RANGE * 1.0) or tf.light.omni_range <= TorchFire.LIGHT_RANGE + 0.01, "a torch's fire is as before")
	_end()


func _end() -> void:
	if fails.is_empty():
		print("CAMPFIRE TEST PASSED %d" % checks)
	else:
		print("CAMPFIRE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
