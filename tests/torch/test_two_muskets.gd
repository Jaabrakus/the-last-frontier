extends AnimTestSuite
## The musket is drawn once (user 2026-09-28: "we have a two musket bug": a musket in the hand and the same
## musket still on the back with the torch up). On the real level, in each way into the torch carry, every
## frame: the drawn musket's model plus the musket's stowed copies on the body (SlingRig units shown) is at
## most the loadout's count of it.
##   Godot --headless --fixed-fps 120 --path . -s tests/anim/run_all.gd -- --no-capture --dir=res://tests/torch --prefix=test_two


var _p: FrontierPlayer
var _worst := {}


func describe() -> String:
	return "the musket drawn once: never in the hand and on the body at the same time (torch carry, draw with the torch up, quick throwables)"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	_p = await ctx.level()
	if _p == null:
		return
	ctx.allow_error("loops in the graph")
	var item: String = _p.gear.item_for_key("musket") if _p.gear else ""
	ctx.check(item != "", "the player carries a musket (%s)" % item)
	if item == "":
		return
	var it: Dictionary = _p.gear.loadout.item(item)
	var count := int(it.get("count", 1))
	print("  loadout: ", _p.gear.loadout.items.map(func(i: Dictionary) -> String: return "%s(%s x%d)" % [i.get("id"), i.get("kind"), int(i.get("count", 1))]))
	# 1. the musket out, then T: the torch in the right hand, the musket to the left (the middle grip)
	await _equip(ctx, "musket")
	await _watch(ctx, "drawn", item, count, 30)
	await _tap(ctx, PlayerTorch.ACTION)
	await _watch(ctx, "torch up with the musket out", item, count, 240)
	# 2. with the torch up: to the tomahawk and back (the quick throwables keep the gun in the left hand)
	_p.switch_weapon("tomahawk")
	await _watch(ctx, "torch up, musket -> tomahawk", item, count, 240)
	_p.switch_weapon("musket")
	await _watch(ctx, "torch up, tomahawk -> musket", item, count, 240)
	# 3. the torch put away (a hold of T), the musket still out
	Input.action_press(PlayerTorch.ACTION)
	await _watch(ctx, "holding T (torch away)", item, count, 90)
	Input.action_release(PlayerTorch.ACTION)
	await _watch(ctx, "torch away, musket out", item, count, 120)
	# 4. moving with the torch up: walk, run, crouch-walk (the one-hand middle grip), aim, a jump
	await _tap(ctx, PlayerTorch.ACTION)
	await _watch(ctx, "torch up again", item, count, 240)
	await _hold(ctx, "move_forward", "torch up, walking", item, count, 180)
	Input.action_press("sprint")
	await _hold(ctx, "move_forward", "torch up, running", item, count, 180)
	Input.action_release("sprint")
	await _tap(ctx, "crouch")
	await _hold(ctx, "move_forward", "torch up, crouch-walk", item, count, 180)
	await _tap(ctx, "crouch")
	Input.action_press("aim")
	await _watch(ctx, "torch up, aiming", item, count, 150)
	Input.action_release("aim")
	await _watch(ctx, "torch up, aim released", item, count, 90)
	await _tap(ctx, "jump")
	await _watch(ctx, "torch up, jump", item, count, 120)
	# 5. H: everything on the body, then the musket drawn again with the torch up
	await _tap(ctx, "holster") if InputMap.has_action("holster") else await ctx.frames(1)
	await _watch(ctx, "holster (H)", item, count, 240)
	_p.switch_weapon("musket")
	await _watch(ctx, "torch up, musket drawn again", item, count, 300)
	# 6. no torch: crouch-walk with the musket (the middle grip without the torch)
	Input.action_press(PlayerTorch.ACTION)
	await _watch(ctx, "holding T again", item, count, 90)
	Input.action_release(PlayerTorch.ACTION)
	await _tap(ctx, "crouch")
	await _hold(ctx, "move_forward", "crouch-walk, no torch", item, count, 180)
	await _tap(ctx, "crouch")
	# 7. another weapon put down and taken back while the musket is out (PlayerInteractor place / PlacedWeapon take:
	# set_carried reinstalls the rig; before the fix the musket showed in the hand twice: its model and the rig's
	# stand-in copy)
	await _equip(ctx, "musket")
	for torch in [false, true]:
		if torch != _p.torch.holding():
			await _tap(ctx, PlayerTorch.ACTION)
			await _watch(ctx, "torch %s" % torch, item, count, 240)
		var tag := " (torch up)" if torch else ""
		# (another weapon: putting down the one in the hand leaves FrontierPlayer.weapon null until the next is
		# drawn, a separate player.gd error)
		_p.set_carried("bow", false)
		await _watch(ctx, "bow put down, musket out" + tag, item, count, 120)
		_p.set_carried("bow", true)
		await _watch(ctx, "bow taken back, musket out" + tag, item, count, 300)
	for k: String in _worst:
		ctx.check(int(_worst[k][0]) <= count, "%s: the musket shown %d time(s) (%s)" % [k, int(_worst[k][0]), _worst[k][1]])


## Every visible copy of the musket on the player (the level's racks and pickups aside): the model's largest mesh
## (the stock and barrel) is in each copy once (the drawn model, the stowed copies, a handoff flyer).
var _marker: Mesh


func _shown(item: String) -> Array:
	var musket: Weapon = _p.weapons.get("musket")
	if _marker == null and musket and musket.model:
		var big := 0.0
		for mi in musket.model.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			if m and m.get_aabb().get_longest_axis_size() > big:
				big = m.get_aabb().get_longest_axis_size()
				_marker = m
	var n := 0
	var where := []
	for mi in _p.get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == _marker and m.is_visible_in_tree() and _p.is_ancestor_of(m):
			n += 1
			where.append(String(m.get_parent().name) + "/" + String(m.name))
	return [n, ", ".join(where)]


func _watch(ctx: AnimTestContext, label: String, item: String, count: int, frames: int) -> void:
	for i in frames:
		await ctx.frames(1)
		var s := _shown(item)
		if not _worst.has(label) or int(s[0]) > int(_worst[label][0]):
			_worst[label] = s
	print("  %-34s shown %d  (%s)  torch %s mid %.2f" % [label, int(_worst[label][0]), _worst[label][1], _p.torch.holding(), _p.anim.mid_ik.progress])


func _hold(ctx: AnimTestContext, action: String, label: String, item: String, count: int, frames: int) -> void:
	Input.action_press(action)
	await _watch(ctx, label, item, count, frames)
	Input.action_release(action)


func _equip(ctx: AnimTestContext, key: String) -> void:
	_p.switch_weapon(key)
	for i in 720:
		await ctx.frames(1)
		if not _p.is_switching() and not (_p.weapon and _p.weapon.is_equipping()):
			break
	await ctx.seconds(0.3)


func _tap(ctx: AnimTestContext, action: String, frames := 4) -> void:
	Input.action_press(action)
	await ctx.frames(frames)
	Input.action_release(action)
	await ctx.frames(1)
